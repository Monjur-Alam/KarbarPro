import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class DriveService {
  static final DriveService _instance = DriveService._internal();
  factory DriveService() => _instance;
  DriveService._internal();

  final AuthService _authService = AuthService();

  // Save data to Google Drive
  Future<String> saveToGoogleDrive(Map<String, dynamic> data, String fileName) async {
    try {
      // Get access token
      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) {
        throw Exception('User not authenticated');
      }

      // Create authenticated HTTP client
      final authClient = _AuthenticatedClient(accessToken);

      // Create Drive API instance
      final driveApi = drive.DriveApi(authClient);

      // Convert data to JSON string
      final jsonData = jsonEncode(data);
      final bytes = utf8.encode(jsonData);

      // Create file metadata
      final driveFile = drive.File();
      driveFile.name = fileName;
      driveFile.mimeType = 'application/json';

      // Upload file
      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
      );

      final uploadedFile = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
      );

      authClient.close();

      return uploadedFile.id ?? 'File uploaded successfully';
    } catch (error) {
      print('Error saving to Google Drive: $error');
      rethrow;
    }
  }

  // List files from Google Drive
  Future<List<drive.File>> listFiles() async {
    try {
      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) {
        throw Exception('User not authenticated');
      }

      final authClient = _AuthenticatedClient(accessToken);
      final driveApi = drive.DriveApi(authClient);

      final fileList = await driveApi.files.list(
        pageSize: 10,
        orderBy: 'createdTime desc',
      );

      authClient.close();

      return fileList.files ?? [];
    } catch (error) {
      print('Error listing files: $error');
      rethrow;
    }
  }
}

// Custom HTTP client for authenticated requests
class _AuthenticatedClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _client = http.Client();

  _AuthenticatedClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}
