import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app_keys.dart';
import '../config/api_config.dart';
import '../network/api_client.dart';
import '../../ui/screens/notifications_screen.dart';

/// Top-level background message handler.
///
/// This MUST be a top-level (non-class, non-closure) function so that FCM can
/// invoke it when the app is in the background or fully terminated.
/// FCM automatically displays the notification in the Android tray — no extra
/// work is needed here for background/killed-state delivery.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No additional processing needed; FCM shows the notification automatically.
}

/// Notification channel identifiers for Android.
const _kChannelId = 'haznav_alerts';
const _kChannelName = 'HazNav Alerts';
const _kChannelDesc = 'Hazard reports and system alerts from HazNav';

/// Manages Firebase Cloud Messaging (FCM) push notifications.
///
/// Responsibilities:
/// - Request Android notification permission (Android 13+).
/// - Create the Android notification channel used for all HazNav alerts.
/// - Register/refresh the FCM device token with the Django backend.
/// - Display a local notification banner when a push arrives while the app is
///   in the foreground (FCM does NOT auto-show notifications in foreground).
/// - Navigate to the notifications screen when the user taps a notification.
class NotificationService {
  NotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ──────────────────────────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────────────────────────

  /// Call once after [Firebase.initializeApp()] in main().
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Request permission (Android 13+ shows a system dialog)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 2. Create the Android notification channel (required for Android 8+)
    const androidChannel = AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      description: _kChannelDesc,
      importance: Importance.high,
      playSound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // 3. Initialise flutter_local_notifications (for foreground banners)
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // 4. Register the FCM token with the backend; refresh when it rotates
    await _registerToken();
    _messaging.onTokenRefresh.listen(_sendTokenToServer);

    // 5. Foreground messages → show a local notification banner
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 6. Background tap (app suspended but not killed)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // 7. Terminated-state tap — message is already delivered; just navigate
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      await Future.delayed(const Duration(milliseconds: 600));
      _navigateToNotifications();
    }
  }

  /// Call on logout to clear the FCM token from the backend so the user no
  /// longer receives pushes on this device after signing out.
  static Future<void> clearToken() async {
    await _sendTokenToServer('');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ──────────────────────────────────────────────────────────────────────────

  static Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _sendTokenToServer(token);
      }
    } catch (_) {}
  }

  static Future<void> _sendTokenToServer(String token) async {
    try {
      await ApiClient().post(
        ApiConfig.fcmTokenEndpoint,
        data: {'fcm_token': token},
      );
    } catch (_) {
      // Non-critical; the server will receive the token on the next login.
    }
  }

  /// Show a local notification banner when the app is in the foreground.
  static void _handleForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;

    _localNotifications.show(
      // Use a stable ID derived from the message so duplicate calls collapse.
      message.messageId.hashCode,
      n.title ?? 'HazNav',
      n.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          channelDescription: _kChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data['type'],
    );

    // Also refresh in-app notification badge via SnackBar hint (optional UX)
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('${n.title ?? 'HazNav'}: ${n.body ?? ''}'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          onPressed: _navigateToNotifications,
        ),
      ),
    );
  }

  /// Navigate to notifications screen when a background notification is tapped.
  static void _handleMessageTap(RemoteMessage _) => _navigateToNotifications();

  /// Navigate to notifications screen when a local notification banner is tapped.
  static void _onLocalNotificationTap(NotificationResponse _) =>
      _navigateToNotifications();

  static void _navigateToNotifications() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    // Push the notifications screen on top of whatever is showing; if it's
    // already the top route, do nothing to avoid stacking duplicates.
    if (nav.canPop()) {
      nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    } else {
      nav.pushReplacement(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    }
  }
}
