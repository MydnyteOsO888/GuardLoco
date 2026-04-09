import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

// ── Event / Alert ─────────────────────────────────────────
enum EventType {
  motion, impact, sound, proximity, scheduled;

  String get typeLabel {
    switch (this) {
      case EventType.motion:    return 'MOTION';
      case EventType.impact:    return 'IMPACT';
      case EventType.sound:     return 'SOUND';
      case EventType.proximity: return 'PROXIMITY';
      case EventType.scheduled: return 'SCHEDULED';
    }
  }
}

@JsonSerializable()
class SecurityEvent {
  final String id;
  final EventType type;
  final DateTime timestamp;
  final String? clipId;
  final double? sensorValue;
  final String? location;
  final bool isRead;

  const SecurityEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    this.clipId,
    this.sensorValue,
    this.location,
    this.isRead = false,
  });

  factory SecurityEvent.fromJson(Map<String, dynamic> json) =>
      _$SecurityEventFromJson(json);
  Map<String, dynamic> toJson() => _$SecurityEventToJson(this);

  String get typeLabel {
    switch (type) {
      case EventType.motion:    return 'MOTION';
      case EventType.impact:    return 'IMPACT';
      case EventType.sound:     return 'SOUND';
      case EventType.proximity: return 'PROXIMITY';
      case EventType.scheduled: return 'SCHEDULED';
    }
  }

  String get typeEmoji {
    switch (type) {
      case EventType.motion:    return '🏃';
      case EventType.impact:    return '💥';
      case EventType.sound:     return '🔊';
      case EventType.proximity: return '📏';
      case EventType.scheduled: return '📅';
    }
  }
}

// ── Video Clip ────────────────────────────────────────────
@JsonSerializable()
class VideoClip {
  final String id;
  final String? eventId;
  final EventType eventType;
  final DateTime timestamp;
  final int durationSeconds;
  final int fileSizeBytes;
  final String resolution;
  final String? localPath;
  final String? cloudUrl;
  final bool isCloudSynced;

  const VideoClip({
    required this.id,
    this.eventId,
    required this.eventType,
    required this.timestamp,
    required this.durationSeconds,
    required this.fileSizeBytes,
    required this.resolution,
    this.localPath,
    this.cloudUrl,
    this.isCloudSynced = false,
  });

  factory VideoClip.fromJson(Map<String, dynamic> json) =>
      _$VideoClipFromJson(json);
  Map<String, dynamic> toJson() => _$VideoClipToJson(this);

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ── Sensor Reading ────────────────────────────────────────
@JsonSerializable()
class SensorReading {
  final double vibrationG;        // MPU-6050
  final bool motionDetected;      // PIR
  final double ultrasonicMeters;  // HC-SR04
  final double temperatureC;
  final int wifiRssi;
  final DateTime timestamp;

  const SensorReading({
    required this.vibrationG,
    required this.motionDetected,
    required this.ultrasonicMeters,
    required this.temperatureC,
    required this.wifiRssi,
    required this.timestamp,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) =>
      _$SensorReadingFromJson(json);
  Map<String, dynamic> toJson() => _$SensorReadingToJson(this);
}

// ── Device Status ─────────────────────────────────────────
@JsonSerializable()
class DeviceStatus {
  final bool isOnline;
  final bool isArmed;
  final String ipAddress;
  final String firmwareVersion;
  final int uptimeSeconds;
  final double mcuTempC;
  final int wifiRssi;
  final StorageInfo storage;
  final SensorReading? latestReading;

  const DeviceStatus({
    required this.isOnline,
    required this.isArmed,
    required this.ipAddress,
    required this.firmwareVersion,
    required this.uptimeSeconds,
    required this.mcuTempC,
    required this.wifiRssi,
    required this.storage,
    this.latestReading,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) =>
      _$DeviceStatusFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceStatusToJson(this);

  String get formattedUptime {
    final h = uptimeSeconds ~/ 3600;
    final m = (uptimeSeconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }
}

// ── Storage Info ──────────────────────────────────────────
@JsonSerializable()
class StorageInfo {
  final int totalBytes;
  final int usedBytes;
  final int videoBytes;
  final int logsBytes;

  const StorageInfo({
    required this.totalBytes,
    required this.usedBytes,
    required this.videoBytes,
    required this.logsBytes,
  });

  factory StorageInfo.fromJson(Map<String, dynamic> json) =>
      _$StorageInfoFromJson(json);
  Map<String, dynamic> toJson() => _$StorageInfoToJson(this);

  double get usedPercent => totalBytes == 0 ? 0.0 : usedBytes / totalBytes;
  int get freeBytes => totalBytes - usedBytes;

  String formatBytes(int bytes) {
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// ── User ─────────────────────────────────────────────────
@JsonSerializable()
class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final String? fcmToken;

  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.fcmToken,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
  Map<String, dynamic> toJson() => _$AppUserToJson(this);
}
