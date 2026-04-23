import 'dart:async';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import 'connectivity_service.dart';
import '../storage/storage_service.dart';
import '../../features/hazards/hazard_service.dart';
import '../../features/routing/routing_service.dart';

/// Orchestrates data sync whenever internet connectivity is restored.
///
/// Responsibilities:
///   1. Flush the offline report queue (pending_reports box → backend).
///   2. Refresh evacuation centers (re-cache to Hive).
///   3. Refresh verified hazards (re-cache to Hive).
///
/// Call [startListening] once at app startup. All operations are fire-and-forget;
/// failures are logged but do not propagate to the UI.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final ConnectivityService _connectivity = ConnectivityService();
  final StorageService _storage = StorageService();
  final HazardService _hazardService = HazardService();
  final RoutingService _routingService = RoutingService();

  StreamSubscription<bool>? _subscription;
  bool _syncing = false;

  // Stream that emits true while a sync cycle is running, false when idle.
  final _syncingController = StreamController<bool>.broadcast();
  Stream<bool> get syncingStream => _syncingController.stream;
  bool get isSyncing => _syncing;

  /// Start listening for connectivity changes.
  /// Safe to call multiple times — subsequent calls are no-ops.
  void startListening() {
    _subscription ??= _connectivity.onConnectionChange.listen((isOnline) {
      if (isOnline) {
        developer.log('Connection restored — starting background sync', name: 'SyncService');
        syncAll();
      }
    });
  }

  /// Stop listening (e.g. on full app dispose).
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Run a full sync cycle: flush queue → refresh data.
  /// Guard against concurrent calls.
  Future<void> syncAll() async {
    if (_syncing) return;
    _syncing = true;
    _syncingController.add(true);
    try {
      await _flushPendingReports();
      await _refreshEvacuationCenters();
      await _refreshVerifiedHazards();
      await _saveLastSyncTime();
      developer.log('Sync completed successfully', name: 'SyncService');
    } catch (e) {
      developer.log('Sync cycle error: $e', name: 'SyncService');
    } finally {
      _syncing = false;
      _syncingController.add(false);
    }
  }

  /// Return number of reports waiting to sync.
  int get pendingReportCount => _storage.getPendingReportsCount();

  // ---------------------------------------------------------------------------

  Future<void> _flushPendingReports() async {
    final count = _storage.getPendingReportsCount();
    if (count == 0) return;
    developer.log('Flushing $count queued report(s)', name: 'SyncService');
    try {
      await _hazardService.syncQueuedReports();
    } catch (e) {
      developer.log('Queue flush error: $e', name: 'SyncService');
    }
  }

  Future<void> _refreshEvacuationCenters() async {
    try {
      await _routingService.getEvacuationCenters();
      developer.log('Evacuation centers refreshed', name: 'SyncService');
    } catch (e) {
      developer.log('Evacuation centers refresh error: $e', name: 'SyncService');
    }
  }

  Future<void> _refreshVerifiedHazards() async {
    try {
      await _hazardService.getVerifiedHazards();
      developer.log('Verified hazards refreshed', name: 'SyncService');
    } catch (e) {
      developer.log('Verified hazards refresh error: $e', name: 'SyncService');
    }
  }

  Future<void> _saveLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
    } catch (_) {}
  }
}
