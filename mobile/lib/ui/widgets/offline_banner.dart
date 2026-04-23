import 'package:flutter/material.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/services/sync_service.dart';

/// A persistent banner displayed at the top of any screen when the device
/// has no network connectivity.
///
/// Usage — wrap your existing screen body:
/// ```dart
/// body: Stack(
///   children: [
///     // ... your existing content ...
///     const OfflineBanner(),
///   ],
/// )
/// ```
///
/// The banner shows/hides automatically based on connectivity changes.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  final ConnectivityService _connectivity = ConnectivityService();
  final SyncService _syncService = SyncService();

  bool _isOffline = false;
  bool _isSyncing = false;
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _checkInitialState();
    _listenToChanges();
  }

  Future<void> _checkInitialState() async {
    final online = await _connectivity.isOnline;
    if (mounted) {
      setState(() => _isOffline = !online);
      if (_isOffline) _animController.forward();
    }
  }

  void _listenToChanges() {
    _connectivity.onConnectionChange.listen((isOnline) {
      if (!mounted) return;
      setState(() => _isOffline = !isOnline);
      if (_isOffline) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
    // Listen to sync state so the banner shows "Syncing..." when back online.
    _syncService.syncingStream.listen((syncing) {
      if (mounted) setState(() => _isSyncing = syncing);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show banner when offline OR when sync is in progress after reconnect.
    final showBanner = _isOffline || _isSyncing;
    if (!showBanner) return const SizedBox.shrink();

    final pendingCount = _syncService.pendingReportCount;
    final Color bannerColor = _isOffline
        ? const Color(0xFFB71C1C) // dark red when offline
        : const Color(0xFF1565C0); // dark blue when syncing

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: SafeArea(
          bottom: false,
          child: Material(
            color: Colors.transparent,
            child: Container(
              color: bannerColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _isSyncing && !_isOffline
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isOffline
                              ? 'Offline Mode — Using cached maps and saved data'
                              : 'Back online — Syncing data…',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_isOffline && pendingCount > 0)
                          Text(
                            '$pendingCount report${pendingCount == 1 ? '' : 's'} '
                            'queued — will sync when online',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
