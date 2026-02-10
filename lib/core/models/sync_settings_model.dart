import 'dart:convert';

class SyncSettings {
  final bool autoSyncEnabled;
  final int syncIntervalMinutes;
  final bool syncOnWifiOnly;
  final DateTime? lastSyncTimestamp;
  final int totalSyncedRecords;
  final String? googleDriveEmail;
  final int availableDriveStorage;
  final int keepMaxBackups;

  SyncSettings({
    this.autoSyncEnabled = true,
    this.syncIntervalMinutes = 15,
    this.syncOnWifiOnly = true,
    this.lastSyncTimestamp,
    this.totalSyncedRecords = 0,
    this.googleDriveEmail,
    this.availableDriveStorage = 0,
    this.keepMaxBackups = 10,
  });

  SyncSettings copyWith({
    bool? autoSyncEnabled,
    int? syncIntervalMinutes,
    bool? syncOnWifiOnly,
    DateTime? lastSyncTimestamp,
    int? totalSyncedRecords,
    String? googleDriveEmail,
    int? availableDriveStorage,
    int? keepMaxBackups,
  }) {
    return SyncSettings(
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      syncOnWifiOnly: syncOnWifiOnly ?? this.syncOnWifiOnly,
      lastSyncTimestamp: lastSyncTimestamp ?? this.lastSyncTimestamp,
      totalSyncedRecords: totalSyncedRecords ?? this.totalSyncedRecords,
      googleDriveEmail: googleDriveEmail ?? this.googleDriveEmail,
      availableDriveStorage: availableDriveStorage ?? this.availableDriveStorage,
      keepMaxBackups: keepMaxBackups ?? this.keepMaxBackups,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'autoSyncEnabled': autoSyncEnabled,
      'syncIntervalMinutes': syncIntervalMinutes,
      'syncOnWifiOnly': syncOnWifiOnly,
      'lastSyncTimestamp': lastSyncTimestamp?.toIso8601String(),
      'totalSyncedRecords': totalSyncedRecords,
      'googleDriveEmail': googleDriveEmail,
      'availableDriveStorage': availableDriveStorage,
      'keepMaxBackups': keepMaxBackups,
    };
  }

  factory SyncSettings.fromMap(Map<String, dynamic> map) {
    return SyncSettings(
      autoSyncEnabled: map['autoSyncEnabled'] ?? true,
      syncIntervalMinutes: map['syncIntervalMinutes'] ?? 15,
      syncOnWifiOnly: map['syncOnWifiOnly'] ?? true,
      lastSyncTimestamp: map['lastSyncTimestamp'] != null 
          ? DateTime.tryParse(map['lastSyncTimestamp']) 
          : null,
      totalSyncedRecords: map['totalSyncedRecords'] ?? 0,
      googleDriveEmail: map['googleDriveEmail'],
      availableDriveStorage: map['availableDriveStorage'] ?? 0,
      keepMaxBackups: map['keepMaxBackups'] ?? 10,
    );
  }

  String toJson() => json.encode(toMap());

  factory SyncSettings.fromJson(String source) => SyncSettings.fromMap(json.decode(source));
}
