import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class GoogleDriveService {
  final GoogleSignIn _googleSignIn;
  
  GoogleDriveService(this._googleSignIn);

  Future<Map<String, String>> get _authHeaders async {
    final user = _googleSignIn.currentUser;
    if (user == null) {
      throw Exception('User not signed in');
    }
    final auth = await user.authentication;
    return {
      'Authorization': 'Bearer ${auth.accessToken}',
    };
  }

  Future<drive.DriveApi> _getDriveApi() async {
    final headers = await _authHeaders;
    final client = GoogleAuthClient(headers);
    return drive.DriveApi(client);
  }

  /// Uploads a file to Google Drive
  /// If [folderId] is provided, uploads inside that folder
  Future<String?> uploadFile(File file, {String? folderId, String? fileName}) async {
    try {
      final driveApi = await _getDriveApi();
      final name = fileName ?? path.basename(file.path);
      
      final driveFile = drive.File();
      driveFile.name = name;
      if (folderId != null) {
        driveFile.parents = [folderId];
      }

      final media = drive.Media(file.openRead(), file.lengthSync());
      
      final result = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
      );
      
      return result.id;
    } catch (e) {
      print('Error uploading file: $e');
      rethrow;
    }
  }

  /// Creates a folder if it doesn't exist, otherwise returns existing ID
  Future<String?> createFolder(String folderName) async {
    try {
      final driveApi = await _getDriveApi();
      
      // Check if folder exists
      final query = "mimeType='application/vnd.google-apps.folder' and name='$folderName' and trashed=false";
      final fileList = await driveApi.files.list(q: query);
      
      if (fileList.files?.isNotEmpty ?? false) {
        return fileList.files!.first.id;
      }

      // Create folder
      final driveFile = drive.File();
      driveFile.name = folderName;
      driveFile.mimeType = 'application/vnd.google-apps.folder';
      
      final result = await driveApi.files.create(driveFile);
      return result.id;
    } catch (e) {
      print('Error creating folder: $e');
      rethrow;
    }
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
