import 'package:flutter/material.dart';

/// Global navigator key — allows navigation from outside the widget tree
/// (e.g. the 401 session-expiry handler, FCM notification tap handler).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global scaffold messenger key — allows SnackBars from outside the widget tree.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
