import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../services/google_drive_service.dart';
import '../constants/database_constants.dart';

class SyncService {
  final GoogleDriveService _driveService;

  SyncService(this._driveService, DatabaseHelper dbHelper);

  /// Main entry point for syncing
  /// Checks internet, then uploads unsynced data
  Future<void> syncData() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    if (connectivityResults.contains(ConnectivityResult.none)) {
      print('No internet connection, skipping sync.');
      return;
    }

    try {
      print('Starting sync process...');
      await _backupDatabase();
      // Future: Implement strict delta sync logic here
      // For now, we backup the whole DB as a simple strategy for this phase
      print('Sync process completed.');
    } catch (e) {
      print('Sync failed: $e');
    }
  }

  /// Backs up the entire SQLite database file to Google Drive
  Future<void> _backupDatabase() async {
    try {
      // 1. Get database path
      final dbFolder = await getDatabasesPath();
      final dbPath = '$dbFolder/${DatabaseConstants.databaseName}';
      final dbFile = File(dbPath);

      if (!dbFile.existsSync()) {
        print('Database file not found at $dbPath');
        return;
      }

      // 2. Create/Find 'Amar Dokan Backups' folder
      final folderId = await _driveService.createFolder('Amar Dokan Backups');
      if (folderId == null) throw Exception('Could not create backup folder');

      // 3. Upload file with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'backup_$timestamp.db';

      await _driveService.uploadFile(
        dbFile,
        folderId: folderId,
        fileName: fileName,
      );
      
      print('Database backed up successfully: $fileName');
    } catch (e) {
      print('Database backup failed: $e');
      rethrow;
    }
  }
}
