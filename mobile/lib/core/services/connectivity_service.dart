import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Singleton service that monitors network connectivity.
///
/// Offline = [ConnectivityResult.none] only.
/// Note: having WiFi/mobile data does not guarantee internet reachability,
/// but this is sufficient for showing the offline banner and triggering sync.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  /// Stream that emits `true` when online and `false` when offline.
  /// Deduplicates consecutive identical states so listeners only fire on changes.
  late final Stream<bool> onConnectionChange = _connectivity.onConnectivityChanged
      .map((results) => _isOnlineFromResults(results))
      .distinct()
      .asBroadcastStream();

  /// Returns the current online status (async, single check).
  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return _isOnlineFromResults(results);
  }

  static bool _isOnlineFromResults(List<ConnectivityResult> results) {
    return results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);
  }
}
