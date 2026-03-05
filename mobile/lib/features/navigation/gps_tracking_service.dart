import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// GPS Tracking Service for Live Navigation
/// Provides real-time location updates during navigation with smoothing
class GPSTrackingService {
  StreamSubscription<Position>? _positionStream;
  final StreamController<LatLng> _locationController = StreamController<LatLng>.broadcast();

  /// Stream of user locations
  Stream<LatLng> get locationStream => _locationController.stream;

  LatLng? _lastLocation;
  LatLng? get lastLocation => _lastLocation;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  // Location smoothing
  final List<LatLng> _recentLocations = [];
  static const int SMOOTHING_WINDOW = 3; // Average last 3 locations
  static const double MIN_ACCURACY = 50.0; // Ignore locations with >50m accuracy

  /// Minimum meters moved before emitting an update (reduces jitter when stationary)
  static const int _distanceFilterMeters = 15;
  /// Minimum seconds between updates (avoids rapid jumps from GPS drift)
  static const int _minUpdateIntervalSeconds = 2;
  DateTime? _lastEmittedAt;

  /// Start tracking user location
  /// Returns true if started successfully
  Future<bool> startTracking() async {
    if (_isTracking) {
      print('⚠️ GPS tracking already active');
      return true;
    }

    try {
      // Check permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        print('❌ Location permission denied');
        return false;
      }

      // Configure location settings: larger distanceFilter reduces jumping when not moving
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterMeters,
      );

      // Start position stream
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          final location = LatLng(position.latitude, position.longitude);
          _lastLocation = location;

          // Throttle: don't emit more than once per _minUpdateIntervalSeconds
          final now = DateTime.now();
          if (_lastEmittedAt != null &&
              now.difference(_lastEmittedAt!).inSeconds < _minUpdateIntervalSeconds) {
            return;
          }
          _lastEmittedAt = now;
          _locationController.add(location);
          
          print('📍 GPS Update: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)} | Speed: ${position.speed} m/s');
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

  /// Stop tracking user location
  void stopTracking() {
    if (!_isTracking) return;

    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    
    print('🛑 GPS tracking stopped');
  }

  /// Get current location (one-time)
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

  /// Calculate distance between two points in meters
  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Calculate bearing between two points (direction in degrees)
  double calculateBearing(LatLng from, LatLng to) {
    return Geolocator.bearingBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// Smooth location using moving average
  LatLng _smoothLocation(LatLng newLocation) {
    // Add to recent locations
    _recentLocations.add(newLocation);
    
    // Keep only last N locations
    if (_recentLocations.length > SMOOTHING_WINDOW) {
      _recentLocations.removeAt(0);
    }
    
    // If we don't have enough data yet, return as-is
    if (_recentLocations.length < 2) {
      return newLocation;
    }
    
    // Calculate average position
    double avgLat = 0;
    double avgLng = 0;
    
    for (final loc in _recentLocations) {
      avgLat += loc.latitude;
      avgLng += loc.longitude;
    }
    
    avgLat /= _recentLocations.length;
    avgLng /= _recentLocations.length;
    
    return LatLng(avgLat, avgLng);
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    _locationController.close();
    _recentLocations.clear();
  }
}
