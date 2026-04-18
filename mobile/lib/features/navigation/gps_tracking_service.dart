import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// GPS Tracking Service for Live Navigation
/// Provides real-time location updates and compass heading during navigation.
class GPSTrackingService {
  StreamSubscription<Position>? _positionStream;
  final StreamController<LatLng> _locationController =
      StreamController<LatLng>.broadcast();
  final StreamController<double> _headingController =
      StreamController<double>.broadcast();

  /// Stream of user locations (throttled to avoid rapid jumps).
  Stream<LatLng> get locationStream => _locationController.stream;

  /// Stream of device heading in degrees [0, 360).
  /// Sourced from GPS/sensor `Position.heading`.
  /// Emitted immediately (no throttle) whenever heading changes by ≥2°.
  /// Negative values from the sensor indicate unavailability and are skipped.
  Stream<double> get headingStream => _headingController.stream;

  LatLng? _lastLocation;
  LatLng? get lastLocation => _lastLocation;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  final List<LatLng> _recentLocations = [];
  static const int SMOOTHING_WINDOW = 3;

  /// Minimum meters moved before emitting a location update.
  static const int _distanceFilterMeters = 5;

  /// Minimum seconds between location updates.
  static const int _minUpdateIntervalSeconds = 1;
  DateTime? _lastEmittedAt;

  double? _lastHeading;

  /// Start tracking user location and heading.
  Future<bool> startTracking() async {
    if (_isTracking) return true;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('❌ Location permission denied');
        return false;
      }

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

          // --- Heading: emit real-time whenever it changes ≥ 2° ---
          final heading = position.heading;
          if (heading >= 0) {
            final diff = _lastHeading == null
                ? 360.0
                : (heading - _lastHeading!).abs();
            // Normalise wrap-around (e.g. 359° vs 1° = 2°, not 358°)
            final circularDiff = diff > 180 ? 360 - diff : diff;
            if (circularDiff >= 2.0) {
              _lastHeading = heading;
              _headingController.add(heading);
            }
          }

          // --- Location: throttle to avoid rapid jumps from GPS drift ---
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
            'Heading: ${position.heading.toStringAsFixed(1)}°',
          );
        },
        onError: (error) {
          print('❌ GPS Error: $error');
        },
      );

      _isTracking = true;
      print('✅ GPS tracking started');
      return true;
    } catch (e) {
      print('❌ Failed to start GPS tracking: $e');
      return false;
    }
  }

  /// Stop tracking.
  void stopTracking() {
    if (!_isTracking) return;
    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    print('🛑 GPS tracking stopped');
  }

  /// Get current location (one-time).
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

  /// Distance between two points in meters.
  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Bearing from [from] to [to] in degrees.
  double calculateBearing(LatLng from, LatLng to) {
    return Geolocator.bearingBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  void dispose() {
    stopTracking();
    _locationController.close();
    _headingController.close();
    _recentLocations.clear();
  }
}
