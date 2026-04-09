import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_service.dart';

/// Handles all FCM push notification setup.
/// Covers foreground, background, and terminated app states.
/// Per research doc: FCM for cross-platform Android + iOS delivery.
class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  // Channel IDs
  static const String _alertChannelId = 'carguard_alerts';
  static const String _alertChannelName = 'Security Alerts';

  static Future<void> initialize() async {
    // 1. Request permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true, // iOS only — for security alerts
    );

    // 2. Configure local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // already requested via FCM
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotif.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotifTapped,
    );

    // 3. Create Android notification channel
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _alertChannelId,
            _alertChannelName,
            description: 'CarGuard vehicle security alerts',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

    // 4. Get and register FCM token (non-blocking — emulator may lack Play Services)
    _fcm.getToken().then((token) async {
      if (token != null) {
        try {
          await ApiService().updateFcmToken(token);
        } catch (_) {
          // Backend not reachable yet — token will sync on next login
        }
      }
    }).catchError((_) {});

    // Token refresh
    _fcm.onTokenRefresh.listen((newToken) async {
      try {
        await ApiService().updateFcmToken(newToken);
      } catch (_) {}
    });

    // 5. Foreground messages — show local notification
    // (FCM doesn't auto-display when app is open)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 6. Background tap — app opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // 7. Terminated tap — check initial message
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }

    // 8. Background handler (must be top-level function)
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
  }

  // ── Foreground: show local notification ───────────────────
  static Future<void> _handleForegroundMessage(RemoteMessage msg) async {
    final notification = msg.notification;
    final data = msg.data;

    if (notification == null) return;

    await _localNotif.show(
      notification.hashCode,
      notification.title ?? 'CarGuard Alert',
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _alertChannelId,
          _alertChannelName,
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'Security Alert',
          styleInformation: BigTextStyleInformation(
            notification.body ?? '',
            summaryText: _eventTypeFromData(data),
          ),
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  // ── Tapped notification → navigate to relevant screen ─────
  static void _onNotifTapped(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      notificationNavigationEvent.add(data);
    } catch (_) {}
  }

  static void _handleNotificationOpen(RemoteMessage msg) {
    notificationNavigationEvent.add(msg.data);
  }

  // ── Stream for navigation events ──────────────────────────
  static final notificationNavigationEvent =
      _StreamController<Map<String, dynamic>>();

  // ── Helpers ───────────────────────────────────────────────
  static String _eventTypeFromData(Map<String, dynamic> data) {
    return switch (data['event_type']) {
      'motion'    => 'Motion Detected',
      'impact'    => 'Impact Alert',
      'sound'     => 'Sound Alert',
      'proximity' => 'Proximity Alert',
      _           => 'Security Alert',
    };
  }
}

// Must be top-level for Firebase background handler
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  // Firebase is already initialized; just log
  // Heavy processing should happen server-side
}

// Simple stream controller helper
class _StreamController<T> {
  final _listeners = <void Function(T)>[];

  void add(T value) {
    for (final l in _listeners) {
      l(value);
    }
  }

  void listen(void Function(T) callback) {
    _listeners.add(callback);
  }
}

// Riverpod provider
final notificationServiceProvider = Provider<NotificationService>((_) {
  return NotificationService();
});
