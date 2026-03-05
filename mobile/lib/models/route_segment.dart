import 'package:latlong2/latlong.dart';

/// Route Segment Model
/// Represents a portion of the route with risk assessment
class RouteSegment {
  final LatLng start;
  final LatLng end;
  final double distance; // in meters
  final double riskScore; // 0.0 to 1.0
  final String riskLevel; // "safe", "moderate", "high"

  RouteSegment({
    required this.start,
    required this.end,
    required this.distance,
    required this.riskScore,
    required this.riskLevel,
  });

  /// Get risk level from score
  static String getRiskLevel(double score) {
    if (score < 0.3) return 'safe';
    if (score < 0.7) return 'moderate';
    return 'high';
  }

  /// Check if segment is high risk
  bool get isHighRisk => riskLevel == 'high';

  /// Check if segment is safe
  bool get isSafe => riskLevel == 'safe';

  RouteSegment copyWith({
    LatLng? start,
    LatLng? end,
    double? distance,
    double? riskScore,
    String? riskLevel,
  }) {
    return RouteSegment(
      start: start ?? this.start,
      end: end ?? this.end,
      distance: distance ?? this.distance,
      riskScore: riskScore ?? this.riskScore,
      riskLevel: riskLevel ?? this.riskLevel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': {'lat': start.latitude, 'lng': start.longitude},
      'end': {'lat': end.latitude, 'lng': end.longitude},
      'distance': distance,
      'riskScore': riskScore,
      'riskLevel': riskLevel,
    };
  }

  factory RouteSegment.fromJson(Map<String, dynamic> json) {
    final start = json['start'];
    final end = json['end'];
    final riskScore = (json['riskScore'] ?? 0.0).toDouble();
    
    return RouteSegment(
      start: LatLng(start['lat'], start['lng']),
      end: LatLng(end['lat'], end['lng']),
      distance: (json['distance'] ?? 0).toDouble(),
      riskScore: riskScore,
      riskLevel: json['riskLevel'] ?? getRiskLevel(riskScore),
    );
  }
}
