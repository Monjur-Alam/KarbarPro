import 'package:workmanager/workmanager.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../services/sync_service.dart';
import '../services/google_drive_service.dart';
import '../services/connectivity_service.dart';
import '../database/database_helper.dart';

const String syncTaskName = 'com.munjuralam.karbarpro.syncTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('Background sync task triggered: $task');
    
    try {
      final googleSignIn = GoogleSignIn(
        scopes: [
          'email',
          'profile',
          'https://www.googleapis.com/auth/drive.file',
        ],
      );
      
      final account = await googleSignIn.signInSilently();
      
      if (account != null) {
        final driveService = GoogleDriveService(googleSignIn);
        final dbHelper = DatabaseHelper();
        final connectivityService = ConnectivityService();
        final syncService = SyncService(driveService, dbHelper, connectivityService);
        
        await syncService.performSync();
        debugPrint('Background sync completed successfully.');
      } else {
        debugPrint('Background Sync: Not signed in.');
      }
    } catch (e) {
      debugPrint('Background Sync Error: $e');
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
      "sync-task-1",
      syncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}
