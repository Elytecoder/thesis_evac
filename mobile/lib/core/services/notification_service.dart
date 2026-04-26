import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app_keys.dart';
import '../config/api_config.dart';
import '../network/api_client.dart';
import '../../ui/screens/notifications_screen.dart';
import '../../ui/admin/reports_management_screen.dart';

/// Top-level background message handler.
///
/// Must be a top-level function (not a closure or class method) so that the
/// FCM plugin can invoke it in a separate isolate when the app is in the
/// background or fully terminated.
///
/// When the app is in the background or killed, FCM automatically displays the
/// system notification in the Android tray — no additional work is needed here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM handles background/terminated notification display automatically.
  // No DB, UI, or navigation work can be done here — the main isolate is not
  // running. Navigation happens in the tap handler instead.
}

// ────────────────────────────────────────────────────────────────────────────
// Notification channel constants
// ────────────────────────────────────────────────────────────────────────────
const _kChannelId = 'haznav_alerts';
const _kChannelName = 'HazNav Alerts';
const _kChannelDesc = 'Hazard reports and system alerts from HazNav';

// ────────────────────────────────────────────────────────────────────────────
// Navigation target keys (must match the `target` field set by the backend)
// ────────────────────────────────────────────────────────────────────────────
const _kTargetMdrrmoReports = 'mdrrmo_reports';
// 'resident_notifications' is the other backend value; all unknown/null
// targets also fall back to the resident notifications screen.

/// Manages Firebase Cloud Messaging (FCM) push notifications for HazNav.
///
/// Architecture:
/// - FCM is the push transport only; PostgreSQL remains the primary database.
/// - In-app notifications (NotificationsScreen) are kept alongside FCM pushes.
/// - Role-based navigation: admin taps → reports screen, resident taps →
///   notifications screen.  The `target` key in the FCM data payload (set
///   server-side) drives this — residents can never forge an admin target.
///
/// Behaviour per app state:
/// | State       | Source                     | Action                           |
/// |-------------|----------------------------|----------------------------------|
/// | Foreground  | onMessage listener         | show local banner + SnackBar     |
/// | Background  | FCM auto-display in tray   | tap → onMessageOpenedApp         |
/// | Terminated  | FCM auto-display in tray   | tap → getInitialMessage          |
class NotificationService {
  NotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ──────────────────────────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────────────────────────

  /// Call once from main() after [Firebase.initializeApp()].
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Request Android 13+ notification permission
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
      enableVibration: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // 3. Initialise flutter_local_notifications for foreground banners
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // 4. Register FCM token; refresh automatically when it rotates
    await _registerToken();
    _messaging.onTokenRefresh.listen(_sendTokenToServer);

    // 5. Foreground: show a local notification banner
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 6. Background tap (app suspended but alive in memory)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // 7. Terminated-state tap — navigate after a short delay so the widget
    //    tree is fully built before we try to push a new route.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      await Future.delayed(const Duration(milliseconds: 700));
      _navigateByTarget(initial.data['target']);
    }
  }

  /// Clear the FCM token on the backend when the user logs out.
  /// After this call the device will no longer receive push notifications
  /// for the signed-out account until the user logs back in.
  static Future<void> clearToken() async {
    await _sendTokenToServer('');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Token management
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
      // Non-critical — the token is also registered after every login.
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Message handlers
  // ──────────────────────────────────────────────────────────────────────────

  /// Foreground: show a system notification banner via flutter_local_notifications
  /// (FCM does NOT auto-display when the app is in the foreground on Android).
  static void _handleForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;

    final target = message.data['target'] as String?;

    // Show the system notification tray banner
    _localNotifications.show(
      message.messageId.hashCode,
      n.title ?? 'HazNav',
      n.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          channelDescription: _kChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      // Store the target so _onLocalNotificationTap can navigate correctly.
      payload: target,
    );

    // Also surface a SnackBar with a "View" shortcut while the app is open.
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('${n.title ?? 'HazNav'}: ${n.body ?? ''}'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _navigateByTarget(target),
        ),
      ),
    );
  }

  /// Background tap: user tapped the Android notification while app was alive.
  static void _handleTap(RemoteMessage message) {
    _navigateByTarget(message.data['target'] as String?);
  }

  /// Local notification tap (foreground banner tapped).
  static void _onLocalNotificationTap(NotificationResponse response) {
    _navigateByTarget(response.payload);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Role-based navigation
  // ──────────────────────────────────────────────────────────────────────────

  /// Navigate to the correct screen based on the FCM `target` data field.
  ///
  /// The `target` value is set server-side so its authenticity is guaranteed:
  /// - `mdrrmo_reports`         → MDRRMO reports management screen
  /// - `resident_notifications` → Resident notifications screen
  /// - null / unknown           → Resident notifications screen (safe default)
  static void _navigateByTarget(String? target) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    Widget destination;
    if (target == _kTargetMdrrmoReports) {
      destination = const ReportsManagementScreen();
    } else {
      destination = const NotificationsScreen();
    }

    // Push on top of the current stack; avoid duplicate routes.
    nav.push(MaterialPageRoute(builder: (_) => destination));
  }
}
