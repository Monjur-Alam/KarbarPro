import 'package:workmanager/workmanager.dart';
import '../services/sync_service.dart';
import '../services/google_drive_service.dart';
import '../database/database_helper.dart';
import 'package:google_sign_in/google_sign_in.dart';

const String syncTaskName = 'com.example.amar_dokan.syncTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('Native called background task: $task');
    
    // Note: Background sync with Google Sign-In is complex because
    // the plugin might need a UI to refresh tokens if they expire.
    // For this implementation, we attempt a silent sign-in/restore.
    // In production, you might need a persistent token storage strategy
    // or a backend service.
    
    try {
      final googleSignIn = GoogleSignIn(
        scopes: [
          'email',
          'profile',
          'https://www.googleapis.com/auth/drive.file',
        ],
      );
      
      // Attempt to restore previous session silently
      final account = await googleSignIn.signInSilently();
      
      if (account != null) {
        final driveService = GoogleDriveService(googleSignIn);
        final dbHelper = DatabaseHelper();
        final syncService = SyncService(driveService, dbHelper);
        
        await syncService.syncData();
      } else {
        print('Background Sync: User not signed in silently.');
      }
    } catch (e) {
      print('Background Sync Error: $e');
      return Future.value(false);
    }

    return Future.value(true);
  });
}

class BackgroundSyncHelper {
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
    );
  }

  static Future<void> registerPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      "1", // Unique Name
      syncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  }
}
