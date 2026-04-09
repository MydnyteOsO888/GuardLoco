// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SecurityEvent _$SecurityEventFromJson(Map<String, dynamic> json) =>
    SecurityEvent(
      id: json['id'] as String,
      type: $enumDecode(_$EventTypeEnumMap, json['type']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      clipId: json['clipId'] as String?,
      sensorValue: (json['sensorValue'] as num?)?.toDouble(),
      location: json['location'] as String?,
      isRead: json['isRead'] as bool? ?? false,
    );

Map<String, dynamic> _$SecurityEventToJson(SecurityEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$EventTypeEnumMap[instance.type]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'clipId': instance.clipId,
      'sensorValue': instance.sensorValue,
      'location': instance.location,
      'isRead': instance.isRead,
    };

const _$EventTypeEnumMap = {
  EventType.motion: 'motion',
  EventType.impact: 'impact',
  EventType.sound: 'sound',
  EventType.proximity: 'proximity',
  EventType.scheduled: 'scheduled',
};

VideoClip _$VideoClipFromJson(Map<String, dynamic> json) => VideoClip(
      id: json['id'] as String,
      eventId: json['eventId'] as String?,
      eventType: $enumDecode(_$EventTypeEnumMap, json['eventType']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      fileSizeBytes: (json['fileSizeBytes'] as num).toInt(),
      resolution: json['resolution'] as String,
      localPath: json['localPath'] as String?,
      cloudUrl: json['cloudUrl'] as String?,
      isCloudSynced: json['isCloudSynced'] as bool? ?? false,
    );

Map<String, dynamic> _$VideoClipToJson(VideoClip instance) => <String, dynamic>{
      'id': instance.id,
      'eventId': instance.eventId,
      'eventType': _$EventTypeEnumMap[instance.eventType]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'durationSeconds': instance.durationSeconds,
      'fileSizeBytes': instance.fileSizeBytes,
      'resolution': instance.resolution,
      'localPath': instance.localPath,
      'cloudUrl': instance.cloudUrl,
      'isCloudSynced': instance.isCloudSynced,
    };

SensorReading _$SensorReadingFromJson(Map<String, dynamic> json) =>
    SensorReading(
      vibrationG: (json['vibrationG'] as num).toDouble(),
      motionDetected: json['motionDetected'] as bool,
      ultrasonicMeters: (json['ultrasonicMeters'] as num).toDouble(),
      temperatureC: (json['temperatureC'] as num).toDouble(),
      wifiRssi: (json['wifiRssi'] as num).toInt(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$SensorReadingToJson(SensorReading instance) =>
    <String, dynamic>{
      'vibrationG': instance.vibrationG,
      'motionDetected': instance.motionDetected,
      'ultrasonicMeters': instance.ultrasonicMeters,
      'temperatureC': instance.temperatureC,
      'wifiRssi': instance.wifiRssi,
      'timestamp': instance.timestamp.toIso8601String(),
    };

DeviceStatus _$DeviceStatusFromJson(Map<String, dynamic> json) => DeviceStatus(
      isOnline: json['isOnline'] as bool,
      isArmed: json['isArmed'] as bool,
      ipAddress: json['ipAddress'] as String,
      firmwareVersion: json['firmwareVersion'] as String,
      uptimeSeconds: (json['uptimeSeconds'] as num).toInt(),
      mcuTempC: (json['mcuTempC'] as num).toDouble(),
      wifiRssi: (json['wifiRssi'] as num).toInt(),
      storage: StorageInfo.fromJson(json['storage'] as Map<String, dynamic>),
      latestReading: json['latestReading'] == null
          ? null
          : SensorReading.fromJson(
              json['latestReading'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DeviceStatusToJson(DeviceStatus instance) =>
    <String, dynamic>{
      'isOnline': instance.isOnline,
      'isArmed': instance.isArmed,
      'ipAddress': instance.ipAddress,
      'firmwareVersion': instance.firmwareVersion,
      'uptimeSeconds': instance.uptimeSeconds,
      'mcuTempC': instance.mcuTempC,
      'wifiRssi': instance.wifiRssi,
      'storage': instance.storage,
      'latestReading': instance.latestReading,
    };

StorageInfo _$StorageInfoFromJson(Map<String, dynamic> json) => StorageInfo(
      totalBytes: (json['totalBytes'] as num).toInt(),
      usedBytes: (json['usedBytes'] as num).toInt(),
      videoBytes: (json['videoBytes'] as num).toInt(),
      logsBytes: (json['logsBytes'] as num).toInt(),
    );

Map<String, dynamic> _$StorageInfoToJson(StorageInfo instance) =>
    <String, dynamic>{
      'totalBytes': instance.totalBytes,
      'usedBytes': instance.usedBytes,
      'videoBytes': instance.videoBytes,
      'logsBytes': instance.logsBytes,
    };

AppUser _$AppUserFromJson(Map<String, dynamic> json) => AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      fcmToken: json['fcmToken'] as String?,
    );

Map<String, dynamic> _$AppUserToJson(AppUser instance) => <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'displayName': instance.displayName,
      'fcmToken': instance.fcmToken,
    };
