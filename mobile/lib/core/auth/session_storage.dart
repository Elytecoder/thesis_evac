import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_config.dart';

/// Persists auth token (secure when [keepLoggedIn]) and session metadata.
/// Ephemeral sessions keep the token only in memory until the app process ends.
class SessionStorage {
  SessionStorage._();

  static const Duration persistentSessionMaxAge = Duration(days: 7);

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  /// In-memory token when user chose not to stay logged in.
  static String? ephemeralToken;

  static Future<void> writeSession({
    required String token,
    required bool keepLoggedIn,
    int? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    ephemeralToken = null;

    if (keepLoggedIn) {
      if (kIsWeb) {
        await prefs.setString(StorageConfig.authTokenKey, token);
      } else {
        await _secure.write(key: StorageConfig.authTokenSecureKey, value: token);
        await prefs.remove(StorageConfig.authTokenKey);
      }
      await prefs.setBool(StorageConfig.keepLoggedInKey, true);
      await prefs.setInt(
        StorageConfig.loginTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      if (userId != null) {
        await prefs.setInt(StorageConfig.userIdKey, userId);
      }
    } else {
      if (!kIsWeb) {
        await _secure.delete(key: StorageConfig.authTokenSecureKey);
      }
      await prefs.remove(StorageConfig.authTokenKey);
      await prefs.setBool(StorageConfig.keepLoggedInKey, false);
      await prefs.remove(StorageConfig.loginTimestampKey);
      await prefs.remove(StorageConfig.userIdKey);
      ephemeralToken = token;
    }
  }

  static Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    final keep = prefs.getBool(StorageConfig.keepLoggedInKey);

    if (keep == false) {
      return ephemeralToken;
    }

    if (kIsWeb) {
      return prefs.getString(StorageConfig.authTokenKey);
    }

    final secured = await _secure.read(key: StorageConfig.authTokenSecureKey);
    if (secured != null && secured.isNotEmpty) {
      return secured;
    }

    final legacy = prefs.getString(StorageConfig.authTokenKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _migrateLegacyToSecure(legacy, prefs);
      return legacy;
    }

    return null;
  }

  static Future<void> _migrateLegacyToSecure(
    String token,
    SharedPreferences prefs,
  ) async {
    if (kIsWeb) return;
    final existing = await _secure.read(key: StorageConfig.authTokenSecureKey);
    if (existing != null && existing.isNotEmpty) return;

    await _secure.write(key: StorageConfig.authTokenSecureKey, value: token);
    await prefs.remove(StorageConfig.authTokenKey);
    await prefs.setBool(StorageConfig.keepLoggedInKey, true);
    if (prefs.getInt(StorageConfig.loginTimestampKey) == null) {
      await prefs.setInt(
        StorageConfig.loginTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  static Future<void> clearSession() async {
    ephemeralToken = null;
    if (!kIsWeb) {
      await _secure.delete(key: StorageConfig.authTokenSecureKey);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageConfig.authTokenKey);
    await prefs.remove(StorageConfig.keepLoggedInKey);
    await prefs.remove(StorageConfig.loginTimestampKey);
    await prefs.remove(StorageConfig.userIdKey);
  }

  /// True when a persisted session is older than [persistentSessionMaxAge].
  static Future<bool> isPersistentSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(StorageConfig.keepLoggedInKey) != true) {
      return false;
    }
    final ts = prefs.getInt(StorageConfig.loginTimestampKey);
    if (ts == null) {
      return false;
    }
    final started = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateTime.now().difference(started) > persistentSessionMaxAge;
  }
}
