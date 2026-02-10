import 'dart:io';
import 'dart:async';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

class GoogleDriveService {
  final GoogleSignIn _googleSignIn;
  static const String backupFolderName = "AmarDokan_Backup";
  
  GoogleDriveService(this._googleSignIn);

  Future<drive.DriveApi> _getDriveApi() async {
    final user = _googleSignIn.currentUser;
    if (user == null) {
      throw Exception('User not signed in');
    }
    final auth = await user.authentication;
    final client = GoogleAuthClient({'Authorization': 'Bearer ${auth.accessToken}'});
    return drive.DriveApi(client);
  }

  /// Get or Create the backup folder ID
  Future<String> getOrCreateBackupFolder() async {
    try {
      final driveApi = await _getDriveApi();
      final query = "mimeType='application/vnd.google-apps.folder' and name='$backupFolderName' and trashed=false";
      final fileList = await driveApi.files.list(q: query, spaces: 'drive');
      
      if (fileList.files?.isNotEmpty ?? false) {
        return fileList.files!.first.id!;
      }

      final folder = drive.File()
        ..name = backupFolderName
        ..mimeType = 'application/vnd.google-apps.folder';
      
      final createdFolder = await driveApi.files.create(folder);
      return createdFolder.id!;
    } catch (e) {
      debugPrint('Error getting/creating folder: $e');
      rethrow;
    }
  }

  /// List all backups in the backup folder
  Future<List<drive.File>> listBackups(String folderId) async {
    try {
      final driveApi = await _getDriveApi();
      final query = "'$folderId' in parents and trashed=false";
      final fileList = await driveApi.files.list(
        q: query, 
        spaces: 'drive',
        $fields: 'files(id, name, size, modifiedTime, md5Checksum)',
        orderBy: 'modifiedTime desc',
      );
      return fileList.files ?? [];
    } catch (e) {
      debugPrint('Error listing backups: $e');
      return [];
    }
  }

  /// Upload a file with basic progress support via Stream
  Future<String?> uploadBackup(File file, String folderId, {String? fileName}) async {
    try {
      final driveApi = await _getDriveApi();
      final name = fileName ?? path.basename(file.path);
      
      final driveFile = drive.File()
        ..name = name
        ..parents = [folderId];

      final media = drive.Media(file.openRead(), file.lengthSync());
      
      final result = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
      );
      
      return result.id;
    } catch (e) {
      debugPrint('Error uploading backup: $e');
      rethrow;
    }
  }

  /// Download a file to a local destination
  Future<void> downloadBackup(String fileId, File destination) async {
    try {
      final driveApi = await _getDriveApi();
      final drive.Media media = await driveApi.files.get(
        fileId, 
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataStore = [];
      await for (final data in media.stream) {
        dataStore.addAll(data);
      }
      await destination.writeAsBytes(dataStore);
    } catch (e) {
      debugPrint('Error downloading backup: $e');
      rethrow;
    }
  }

  /// Delete a specific file
  Future<void> deleteFile(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      await driveApi.files.delete(fileId);
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  /// Keep only the last N backups and delete others
  Future<void> cleanOldBackups(String folderId, int keepCount) async {
    final backups = await listBackups(folderId);
    if (backups.length > keepCount) {
      final toDelete = backups.sublist(keepCount);
      for (final file in toDelete) {
        if (file.id != null) {
          await deleteFile(file.id!);
        }
      }
    }
  }

  /// Get Drive quota information
  Future<drive.About> getDriveAbout() async {
    final driveApi = await _getDriveApi();
    return await driveApi.about.get($fields: 'storageQuota, user');
  }

  /// Get current user profile
  Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser;
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
