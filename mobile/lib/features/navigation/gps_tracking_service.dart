import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:latlong2/latlong.dart';

/// GPS Tracking Service for Live Navigation.
///
/// Heading strategy (priority order):
///   1. **Magnetometer (flutter_compass)** — works while stationary; driven by
///      the device's hardware compass.  This is the primary source.
///   2. **GPS course bearing** — blended in when speed > [_gpsBlendThresholdMs]
///      so the arrow follows travel direction while moving.
///
/// The combined heading is smoothed with a low-pass filter before being
/// emitted, giving smooth rotation with no jitter.
class GPSTrackingService {
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassSubscription;

  final StreamController<LatLng> _locationController =
      StreamController<LatLng>.broadcast();
  final StreamController<double> _headingController =
      StreamController<double>.broadcast();

  /// Stream of user locations (throttled).
  Stream<LatLng> get locationStream => _locationController.stream;

  /// Stream of fused heading in degrees [0, 360).
  /// Magnetometer-driven at rest; blends GPS course bearing when moving.
  Stream<double> get headingStream => _headingController.stream;

  LatLng? _lastLocation;
  LatLng? get lastLocation => _lastLocation;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  // ── Heading state ───────────────────────────────────────────────────────────

  /// Latest compass reading from the magnetometer (null until first event).
  double? _compassHeading;

  /// Latest GPS speed in m/s (0.0 until first fix).
  double _gpsSpeed = 0.0;

  /// Latest GPS course bearing (direction of travel), degrees.
  double? _gpsCourseBearing;

  /// Smoothed heading value currently emitted to the UI.
  double? _smoothedHeading;

  /// Speed threshold above which GPS course bearing is blended in.
  /// 1.0 m/s ≈ comfortable walking pace.
  static const double _gpsBlendThresholdMs = 1.0;

  /// Low-pass filter coefficient [0..1].
  /// 0.15 = aggressive smoothing (slow to respond)
  /// 0.35 = moderate (good for walking)
  /// Using 0.25 — responsive but jitter-free.
  static const double _alpha = 0.25;

  /// Minimum change in smoothed heading (°) before emitting a UI update.
  /// Keeps setState calls low without losing perceived responsiveness.
  static const double _emitThresholdDeg = 2.0;

  // ── Location throttle ───────────────────────────────────────────────────────
  static const int _distanceFilterMeters = 5;
  static const int _minUpdateIntervalSeconds = 1;
  DateTime? _lastEmittedAt;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Start tracking location and heading.
  Future<bool> startTracking() async {
    if (_isTracking) return true;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('❌ Location permission denied');
        return false;
      }

      // 1. Subscribe to compass (magnetometer) — primary heading source.
      _startCompass();

      // 2. Subscribe to GPS for location + course bearing when moving.
      _startGps();

      _isTracking = true;
      print('✅ GPS + Compass tracking started');
      return true;
    } catch (e) {
      print('❌ Failed to start GPS tracking: $e');
      return false;
    }
  }

  /// Stop all tracking.
  void stopTracking() {
    if (!_isTracking) return;
    _positionStream?.cancel();
    _positionStream = null;
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _isTracking = false;
    print('🛑 GPS + Compass tracking stopped');
  }

  // ── Internals ───────────────────────────────────────────────────────────────

  void _startCompass() {
    final events = FlutterCompass.events;
    if (events == null) {
      print('⚠️ Compass sensor not available on this device');
      return;
    }
    _compassSubscription = events.listen((CompassEvent event) {
      final heading = event.heading;
      if (heading == null || heading.isNaN) return;
      // Normalise to [0, 360)
      _compassHeading = (heading % 360 + 360) % 360;
      _updateFusedHeading();
    });
  }

  void _startGps() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: _distanceFilterMeters,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        final location = LatLng(position.latitude, position.longitude);
        _lastLocation = location;

        // Capture speed and GPS course bearing for blending.
        _gpsSpeed = position.speed.clamp(0.0, double.infinity);
        if (position.heading >= 0) {
          _gpsCourseBearing = position.heading;
        }

        // Re-compute fused heading whenever GPS fires (catches movement starts).
        _updateFusedHeading();

        // Throttle location events.
        final now = DateTime.now();
        if (_lastEmittedAt != null &&
            now.difference(_lastEmittedAt!).inSeconds <
                _minUpdateIntervalSeconds) {
          return;
        }
        _lastEmittedAt = now;
        _locationController.add(location);

        print(
          '📍 GPS: ${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)} | '
          'Speed: ${_gpsSpeed.toStringAsFixed(1)} m/s | '
          'GPSBearing: ${position.heading.toStringAsFixed(1)}° | '
          'Compass: ${_compassHeading?.toStringAsFixed(1) ?? "n/a"}°',
        );
      },
      onError: (error) => print('❌ GPS Error: $error'),
    );
  }

  /// Compute the fused heading and emit it if it changed enough.
  ///
  /// Fusion logic:
  ///   - At rest (speed < threshold)  →  pure compass heading.
  ///   - While moving (speed ≥ threshold) →  blend compass (70%) + GPS course (30%).
  ///     GPS course is more reliable at higher speeds; compass gives instant
  ///     response to phone rotations.
  void _updateFusedHeading() {
    double? raw;

    if (_compassHeading != null) {
      if (_gpsSpeed >= _gpsBlendThresholdMs && _gpsCourseBearing != null) {
        // Blend: weighted circular average.
        raw = _circularWeightedAverage(
          _compassHeading!,
          _gpsCourseBearing!,
          weightA: 0.7, // compass weight
          weightB: 0.3, // GPS course weight
        );
      } else {
        // Stationary or no GPS course: pure compass.
        raw = _compassHeading!;
      }
    } else if (_gpsCourseBearing != null && _gpsSpeed >= _gpsBlendThresholdMs) {
      // No compass available: fall back to GPS course when moving.
      raw = _gpsCourseBearing!;
    }

    if (raw == null) return;

    // Apply low-pass filter.
    if (_smoothedHeading == null) {
      _smoothedHeading = raw;
    } else {
      _smoothedHeading = _lowPassFilter(_smoothedHeading!, raw);
    }

    // Emit on every compass update — setState coalescing in Flutter keeps this
    // cheap; the UI only redraws when _currentBearing actually changes enough
    // to produce a visible angle difference.
    _headingController.add(_smoothedHeading!);
  }

  // ── Math helpers ────────────────────────────────────────────────────────────

  /// Low-pass filter: blend [prev] toward [next] by factor [_alpha].
  /// Handles wrap-around (e.g. 350° → 10° should interpolate through 0°).
  double _lowPassFilter(double prev, double next) {
    double diff = next - prev;
    // Normalise diff to [-180, 180]
    while (diff > 180) { diff -= 360; }
    while (diff < -180) { diff += 360; }
    final result = prev + _alpha * diff;
    return (result % 360 + 360) % 360;
  }

  /// Circular weighted average of two angles (handles 0°/360° wrap).
  double _circularWeightedAverage(
    double a,
    double b, {
    required double weightA,
    required double weightB,
  }) {
    final aRad = a * math.pi / 180;
    final bRad = b * math.pi / 180;
    final sinAvg = weightA * math.sin(aRad) + weightB * math.sin(bRad);
    final cosAvg = weightA * math.cos(aRad) + weightB * math.cos(bRad);
    final avg = math.atan2(sinAvg, cosAvg) * 180 / math.pi;
    return (avg % 360 + 360) % 360;
  }

  /// Absolute difference between two angles on a circle [0, 180].
  double _circularDiff(double a, double b) {
    double diff = (a - b).abs() % 360;
    return diff > 180 ? 360 - diff : diff;
  }

  // ── Utilities ───────────────────────────────────────────────────────────────

  /// One-shot current location.
  Future<LatLng?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('❌ Failed to get current location: $e');
      return null;
    }
  }

  /// Distance between two points in metres.
  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude, point1.longitude,
      point2.latitude, point2.longitude,
    );
  }

  /// Bearing from [from] to [to] in degrees.
  double calculateBearing(LatLng from, LatLng to) {
    return Geolocator.bearingBetween(
      from.latitude, from.longitude,
      to.latitude, to.longitude,
    );
  }

  void dispose() {
    stopTracking();
    _locationController.close();
    _headingController.close();
  }
}
