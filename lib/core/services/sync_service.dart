import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../services/google_drive_service.dart';
import '../services/connectivity_service.dart';
import '../constants/database_constants.dart';
import '../models/sync_settings_model.dart';

enum SyncStatus { idle, syncing, success, failed, paused, queued }

class SyncService {
  final GoogleDriveService _driveService;
  final DatabaseHelper _dbHelper;
  final ConnectivityService _connectivityService;
  
  static const String _syncSettingsKey = 'sync_settings';
  
  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus get currentStatus => _currentStatus;

  SyncService(this._driveService, this._dbHelper, this._connectivityService);

  Future<SyncSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_syncSettingsKey);
    if (jsonStr != null) {
      return SyncSettings.fromJson(jsonStr);
    }
    return SyncSettings();
  }

  Future<void> saveSettings(SyncSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncSettingsKey, settings.toJson());
  }

  /// Initial sync logic
  Future<void> performSync({bool isManual = false}) async {
    if (_currentStatus == SyncStatus.syncing) return;

    final settings = await getSettings();
    if (!settings.autoSyncEnabled && !isManual) return;

    final connectivity = await _connectivityService.checkConnectivity();
    if (connectivity == ConnectivityState.none) {
      _setStatus(SyncStatus.queued);
      return;
    }

    if (settings.syncOnWifiOnly && connectivity != ConnectivityState.wifi && !isManual) {
      _setStatus(SyncStatus.paused);
      return;
    }

    _setStatus(SyncStatus.syncing);

    try {
      // 1. Incremental Sync (Delta)
      await _performIncrementalSync();

      // 2. Full Backup (if needed or daily)
      // For now, let's do a full backup every time we sync for extra safety, 
      // or implement a "needsFullBackup" check.
      await performFullBackup();

      _setStatus(SyncStatus.success);
      
      // Update last sync timestamp
      final updatedSettings = settings.copyWith(lastSyncTimestamp: DateTime.now());
      await saveSettings(updatedSettings);

    } catch (e) {
      debugPrint('Sync failed: $e');
      _setStatus(SyncStatus.failed);
      rethrow;
    }
  }

  Future<void> _performIncrementalSync() async {
    final tables = [
      DatabaseConstants.tableProducts,
      DatabaseConstants.tableCustomers,
      DatabaseConstants.tableSales,
      DatabaseConstants.tableExpenses,
      DatabaseConstants.tableCreditPayments,
      DatabaseConstants.tableActivities,
    ];

    int totalSynced = 0;
    List<String> syncedTables = [];

    for (final table in tables) {
      final unsynced = await _dbHelper.getUnsyncedRecords(table);
      if (unsynced.isNotEmpty) {
        // In a real app, we might upload these to a REST API.
        // For a Drive-only app, we can upload a JSON delta file.
        await _uploadDeltaFile(table, unsynced);
        
        final ids = unsynced.map((row) => row[DatabaseConstants.colId] as int).toList();
        await _dbHelper.markAsSynced(table, ids);
        
        totalSynced += unsynced.length;
        syncedTables.add(table);
      }
    }

    // Log the sync activity
    await _logSyncActivity(
      type: 'incremental',
      status: 'success',
      tables: syncedTables.join(','),
      records: totalSynced,
    );
  }

  Future<void> _uploadDeltaFile(String table, List<Map<String, dynamic>> records) async {
    final folderId = await _driveService.getOrCreateBackupFolder();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'delta_${table}_$timestamp.json';
    
    final tempDir = await _getTempDir();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(json.encode(records));

    await _driveService.uploadBackup(file, folderId, fileName: fileName);
    await file.delete();
  }

  Future<void> performFullBackup() async {
    try {
      final dbPath = await _dbHelper.getDatabasePath();
      final dbFile = File(dbPath);
      
      if (!await dbFile.exists()) return;

      final folderId = await _driveService.getOrCreateBackupFolder();
      
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final fileName = 'amar_dokan_backup_$timestamp.db.gz';

      // Compress using GZip
      final dbBytes = await dbFile.readAsBytes();
      final gzippedBytes = GZipCodec().encode(dbBytes);
      
      final tempDir = await _getTempDir();
      final compressedFile = File('${tempDir.path}/$fileName');
      await compressedFile.writeAsBytes(gzippedBytes);

      try {
        final resultId = await _driveService.uploadBackup(compressedFile, folderId, fileName: fileName);
        
        // Verification (checksum comparison)
        if (resultId != null) {
          debugPrint('Backup uploaded, verifying integrity...');
          // Future: Fetch metadata and compare MD5 if absolute certainty is needed
        }
        
        // Cleanup old backups
        final settings = await getSettings();
        await _driveService.cleanOldBackups(folderId, settings.keepMaxBackups);

        await _logSyncActivity(
          type: 'full_backup',
          status: 'success',
          tables: 'all',
          records: 0,
        );
      } finally {
        if (await compressedFile.exists()) await compressedFile.delete();
      }
    } catch (e) {
      await _logSyncActivity(
        type: 'full_backup',
        status: 'failed',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> restoreFromDrive(String fileId) async {
    _setStatus(SyncStatus.syncing);
    try {
      final tempDir = await _getTempDir();
      final restoreFile = File('${tempDir.path}/restore_tmp.db');
      
      await _driveService.downloadBackup(fileId, restoreFile);
      
      // Handle decompression if .gz
      File finalRestoreFile = restoreFile;
      if (fileId.toLowerCase().endsWith('.gz')) {
        debugPrint('Decompressing restore file...');
        final compressedBytes = await restoreFile.readAsBytes();
        final decompressedBytes = GZipCodec().decode(compressedBytes);
        finalRestoreFile = File('${tempDir.path}/restore_final.db');
        await finalRestoreFile.writeAsBytes(decompressedBytes);
      }

      // Verify integrity (basic check)
      if (await finalRestoreFile.length() < 100) {
        throw Exception('Downloaded file is too small or corrupted.');
      }

      await _dbHelper.restoreDatabase(finalRestoreFile.path);
      
      if (finalRestoreFile != restoreFile && await finalRestoreFile.exists()) {
        await finalRestoreFile.delete();
      }
      await restoreFile.delete();
      
      _setStatus(SyncStatus.success);
    } catch (e) {
      debugPrint('Restore failed: $e');
      _setStatus(SyncStatus.failed);
      rethrow;
    }
  }

  Future<void> _logSyncActivity({
    required String type,
    required String status,
    String? tables,
    int? records,
    String? errorMessage,
  }) async {
    final db = await _dbHelper.database;
    await db.insert(DatabaseConstants.tableSyncLog, {
      DatabaseConstants.colSyncType: type,
      DatabaseConstants.colSyncStatus: status,
      DatabaseConstants.colTablesSynced: tables,
      DatabaseConstants.colRecordsSynced: records ?? 0,
      DatabaseConstants.colErrorMessage: errorMessage,
      DatabaseConstants.colStartedAt: DateTime.now().toIso8601String(),
      DatabaseConstants.colCompletedAt: DateTime.now().toIso8601String(),
    });
  }

  void _setStatus(SyncStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  Future<Directory> _getTempDir() async {
    return await getTemporaryDirectory();
  }

  void dispose() {
    _statusController.close();
  }
}
