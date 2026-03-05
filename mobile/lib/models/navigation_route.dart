import 'package:latlong2/latlong.dart';
import 'navigation_step.dart';
import 'route_segment.dart';

/// Navigation Route Model
/// Complete route with segments and turn-by-turn instructions
class NavigationRoute {
  final List<LatLng> polyline; // All points in route
  final List<RouteSegment> segments; // Route broken into segments with risk
  final List<NavigationStep> steps; // Turn-by-turn instructions
  final double totalDistance; // in meters
  final double totalRiskScore; // average risk
  final String overallRiskLevel; // "safe", "moderate", "high"
  final int estimatedTimeSeconds; // ETA in seconds

  NavigationRoute({
    required this.polyline,
    required this.segments,
    required this.steps,
    required this.totalDistance,
    required this.totalRiskScore,
    required this.overallRiskLevel,
    required this.estimatedTimeSeconds,
  });

  /// Get ETA as formatted string
  String getFormattedETA() {
    final hours = estimatedTimeSeconds ~/ 3600;
    final minutes = (estimatedTimeSeconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '$hours hr $minutes min';
    }
    return '$minutes min';
  }

  /// Get distance as formatted string
  String getFormattedDistance() {
    if (totalDistance >= 1000) {
      return '${(totalDistance / 1000).toStringAsFixed(1)} km';
    }
    return '${totalDistance.toStringAsFixed(0)} m';
  }

  /// Check if route contains high-risk segments
  bool get hasHighRiskSegments {
    return segments.any((segment) => segment.isHighRisk);
  }

  /// Get count of high-risk segments
  int get highRiskSegmentCount {
    return segments.where((segment) => segment.isHighRisk).length;
  }

  NavigationRoute copyWith({
    List<LatLng>? polyline,
    List<RouteSegment>? segments,
    List<NavigationStep>? steps,
    double? totalDistance,
    double? totalRiskScore,
    String? overallRiskLevel,
    int? estimatedTimeSeconds,
  }) {
    return NavigationRoute(
      polyline: polyline ?? this.polyline,
      segments: segments ?? this.segments,
      steps: steps ?? this.steps,
      totalDistance: totalDistance ?? this.totalDistance,
      totalRiskScore: totalRiskScore ?? this.totalRiskScore,
      overallRiskLevel: overallRiskLevel ?? this.overallRiskLevel,
      estimatedTimeSeconds: estimatedTimeSeconds ?? this.estimatedTimeSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'polyline': polyline.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      'segments': segments.map((s) => s.toJson()).toList(),
      'steps': steps.map((s) => s.toJson()).toList(),
      'totalDistance': totalDistance,
      'totalRiskScore': totalRiskScore,
      'overallRiskLevel': overallRiskLevel,
      'estimatedTimeSeconds': estimatedTimeSeconds,
    };
  }

  factory NavigationRoute.fromJson(Map<String, dynamic> json) {
    final polylineData = json['polyline'] as List? ?? [];
    final segmentsData = json['segments'] as List? ?? [];
    final stepsData = json['steps'] as List? ?? [];

    return NavigationRoute(
      polyline: polylineData
          .map((p) => LatLng(p['lat'], p['lng']))
          .toList(),
      segments: segmentsData
          .map((s) => RouteSegment.fromJson(s))
          .toList(),
      steps: stepsData
          .map((s) => NavigationStep.fromJson(s))
          .toList(),
      totalDistance: (json['totalDistance'] ?? 0).toDouble(),
      totalRiskScore: (json['totalRiskScore'] ?? 0.0).toDouble(),
      overallRiskLevel: json['overallRiskLevel'] ?? 'safe',
      estimatedTimeSeconds: json['estimatedTimeSeconds'] ?? 0,
    );
  }
}
