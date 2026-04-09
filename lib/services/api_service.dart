import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';

/// REST API client for the FastAPI backend.
/// Base URL should be set in your environment config or .env file.
class ApiService {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.carguard.io/api/v1',
  );

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // ── Auth interceptor: attach JWT on every request ──
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // 401 → try refresh, then retry
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await _storage.read(key: 'jwt_token');
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final retryResponse = await _dio.fetch(error.requestOptions);
            return handler.resolve(retryResponse);
          }
          await logout();
        }
        handler.next(error);
      },
    ));

    // ── Logging interceptor (dev only) ──
    assert(() {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => debugPrint(o.toString()),
      ));
      return true;
    }());
  }

  // ── Auth ─────────────────────────────────────────────────
  Future<AppUser> login(String email, String password) async {
    final resp = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    await _storage.write(key: 'jwt_token', value: resp.data['access_token']);
    await _storage.write(key: 'refresh_token', value: resp.data['refresh_token']);
    final user = AppUser.fromJson(resp.data['user']);
    await _storage.write(key: 'current_user', value: jsonEncode(resp.data['user']));
    return user;
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<bool> _refreshToken() async {
    try {
      final refresh = await _storage.read(key: 'refresh_token');
      if (refresh == null) return false;
      final resp = await _dio.post('/auth/refresh', data: {'refresh_token': refresh});
      await _storage.write(key: 'jwt_token', value: resp.data['access_token']);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Device ────────────────────────────────────────────────
  Future<DeviceStatus> getDeviceStatus() async {
    final resp = await _dio.get('/device/status');
    return DeviceStatus.fromJson(resp.data);
  }

  Future<void> setArmed(bool armed) async {
    await _dio.post('/device/arm', data: {'armed': armed});
  }

  Future<void> rebootDevice() async {
    await _dio.post('/device/reboot');
  }

  Future<void> updateFcmToken(String token) async {
    await _dio.post('/device/fcm-token', data: {'token': token});
  }

  // ── Sensor readings (SSE stream) ──────────────────────────
  Stream<SensorReading> sensorStream() async* {
    final token = await _storage.read(key: 'jwt_token');
    final client = Dio();
    final resp = await client.get<ResponseBody>(
      '$_baseUrl/sensors/stream',
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Authorization': 'Bearer $token'},
      ),
    );

    await for (final chunk in resp.data!.stream) {
      final raw = String.fromCharCodes(chunk);
      // Server-Sent Events: "data: {...}\n\n"
      for (final line in raw.split('\n')) {
        if (line.startsWith('data: ')) {
          try {
            final json = line.substring(6);
            yield SensorReading.fromJson(_parseJson(json));
          } catch (_) {}
        }
      }
    }
  }

  // ── Events / Alerts ───────────────────────────────────────
  Future<List<SecurityEvent>> getEvents({
    int page = 0,
    int limit = 20,
    EventType? type,
  }) async {
    final resp = await _dio.get('/events', queryParameters: {
      'skip': page * limit,
      'limit': limit,
      if (type != null) 'type': type.name,
    });
    return (resp.data as List)
        .map((e) => SecurityEvent.fromJson(e))
        .toList();
  }

  Future<void> markEventRead(String eventId) async {
    await _dio.patch('/events/$eventId/read');
  }

  // ── Video Clips ───────────────────────────────────────────
  Future<List<VideoClip>> getClips({
    int page = 0,
    int limit = 20,
    EventType? type,
  }) async {
    final resp = await _dio.get('/clips', queryParameters: {
      'skip': page * limit,
      'limit': limit,
      if (type != null) 'type': type.name,
    });
    return (resp.data as List)
        .map((c) => VideoClip.fromJson(c))
        .toList();
  }

  /// Returns a signed streaming URL (AWS S3 presigned or local)
  Future<String> getClipStreamUrl(String clipId) async {
    final resp = await _dio.get('/clips/$clipId/stream-url');
    return resp.data['url'] as String;
  }

  Future<void> deleteClip(String clipId) async {
    await _dio.delete('/clips/$clipId');
  }

  // ── WebRTC Signaling ──────────────────────────────────────
  Future<Map<String, dynamic>> createOffer(
      Map<String, dynamic> offer) async {
    final resp = await _dio.post('/webrtc/offer', data: offer);
    return resp.data as Map<String, dynamic>;
  }

  Future<void> sendIceCandidate(
      Map<String, dynamic> candidate) async {
    await _dio.post('/webrtc/ice-candidate', data: candidate);
  }

  Future<List<Map<String, dynamic>>> getIceCandidates() async {
    final resp = await _dio.get('/webrtc/ice-candidates');
    return List<Map<String, dynamic>>.from(resp.data);
  }

  // ── Settings ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getSettings() async {
    final resp = await _dio.get('/settings');
    return resp.data as Map<String, dynamic>;
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    await _dio.patch('/settings', data: settings);
  }

  // ── Helpers ───────────────────────────────────────────────
  Map<String, dynamic> _parseJson(String raw) {
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

// ignore: avoid_print
void debugPrint(String msg) => print(msg);
