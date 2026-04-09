import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/webrtc_service.dart';

// ── Auth ─────────────────────────────────────────────────
final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AppUser?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  static const _storage = FlutterSecureStorage();

  AuthNotifier() : super(const AsyncLoading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final userJson = await _storage.read(key: 'current_user');
        if (userJson != null) {
          state = AsyncData(AppUser.fromJson(jsonDecode(userJson)));
          return;
        }
      }
      state = const AsyncData(null);
    } catch (_) {
      state = const AsyncData(null);
    }
  }

  Future<void> signIn(String email, String password) async {
    final user = await ApiService().login(email, password);
    state = AsyncData(user);
  }

  Future<void> signOut() async {
    await ApiService().logout();
    state = const AsyncData(null);
  }
}

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authProvider).asData?.value;
});

// ── Device Status ─────────────────────────────────────────
final deviceStatusProvider =
    AsyncNotifierProvider<DeviceStatusNotifier, DeviceStatus?>(
  DeviceStatusNotifier.new,
);

class DeviceStatusNotifier extends AsyncNotifier<DeviceStatus?> {
  Timer? _pollTimer;

  @override
  Future<DeviceStatus?> build() async {
    ref.onDispose(() => _pollTimer?.cancel());
    _startPolling();
    return _fetch();
  }

  Future<DeviceStatus?> _fetch() async {
    try {
      return await ApiService().getDeviceStatus();
    } catch (_) {
      return null;
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final status = await _fetch();
      state = AsyncData(status);
    });
  }

  Future<void> setArmed(bool armed) async {
    await ApiService().setArmed(armed);
    final current = state.value;
    if (current != null) {
      // Optimistic update
      state = AsyncData(DeviceStatus(
        isOnline: current.isOnline,
        isArmed: armed,
        ipAddress: current.ipAddress,
        firmwareVersion: current.firmwareVersion,
        uptimeSeconds: current.uptimeSeconds,
        mcuTempC: current.mcuTempC,
        wifiRssi: current.wifiRssi,
        storage: current.storage,
        latestReading: current.latestReading,
      ));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetch());
  }
}

// ── Sensor Stream ─────────────────────────────────────────
final sensorStreamProvider = StreamProvider<SensorReading>((ref) {
  return ApiService().sensorStream();
});

// ── Events ────────────────────────────────────────────────
final eventTypeFilterProvider = StateProvider<EventType?>((ref) => null);

final eventsProvider =
    AsyncNotifierProvider<EventsNotifier, List<SecurityEvent>>(
  EventsNotifier.new,
);

class EventsNotifier extends AsyncNotifier<List<SecurityEvent>> {
  @override
  Future<List<SecurityEvent>> build() async {
    final type = ref.watch(eventTypeFilterProvider);
    return ApiService().getEvents(type: type);
  }

  Future<void> loadMore() async {
    final current = state.value ?? [];
    final type = ref.read(eventTypeFilterProvider);
    final more = await ApiService().getEvents(
      page: (current.length / 20).floor(),
      type: type,
    );
    state = AsyncData([...current, ...more]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }
}

// ── Video Clips ───────────────────────────────────────────
final clipTypeFilterProvider = StateProvider<EventType?>((ref) => null);

final clipsProvider =
    AsyncNotifierProvider<ClipsNotifier, List<VideoClip>>(
  ClipsNotifier.new,
);

class ClipsNotifier extends AsyncNotifier<List<VideoClip>> {
  @override
  Future<List<VideoClip>> build() async {
    final type = ref.watch(clipTypeFilterProvider);
    return ApiService().getClips(type: type);
  }

  Future<void> deleteClip(String clipId) async {
    await ApiService().deleteClip(clipId);
    final current = state.value ?? [];
    state = AsyncData(current.where((c) => c.id != clipId).toList());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }
}

// ── WebRTC ────────────────────────────────────────────────
final webRtcServiceProvider = Provider<WebRtcService>((ref) {
  final service = WebRtcService();
  ref.onDispose(service.dispose);
  return service;
});

final webRtcConnectionProvider =
    StateNotifierProvider<WebRtcConnectionNotifier, WebRtcConnectionState>(
  (ref) => WebRtcConnectionNotifier(ref),
);

enum WebRtcConnectionState { idle, connecting, connected, error }

class WebRtcConnectionNotifier extends StateNotifier<WebRtcConnectionState> {
  final Ref _ref;

  WebRtcConnectionNotifier(this._ref) : super(WebRtcConnectionState.idle);

  Future<void> connect() async {
    state = WebRtcConnectionState.connecting;
    try {
      await _ref.read(webRtcServiceProvider).connect();
      state = WebRtcConnectionState.connected;
    } catch (_) {
      state = WebRtcConnectionState.error;
    }
  }

  Future<void> disconnect() async {
    await _ref.read(webRtcServiceProvider).dispose();
    state = WebRtcConnectionState.idle;
  }
}

// ── Settings ─────────────────────────────────────────────
final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, Map<String, dynamic>>(
  SettingsNotifier.new,
);

class SettingsNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    return ApiService().getSettings();
  }

  Future<void> updateSetting(String key, dynamic value) async {
    final current = Map<String, dynamic>.from(state.value ?? {});
    current[key] = value;
    state = AsyncData(current);
    await ApiService().updateSettings({key: value});
  }
}
