/// Route model representing a calculated evacuation route.
class Route {
  final List<RoutePoint> path;
  final double totalDistance; // in meters
  final double totalRisk; // 0.0 - 1.0
  final double weight; // distance + risk penalty
  final RiskLevel riskLevel;

  Route({
    required this.path,
    required this.totalDistance,
    required this.totalRisk,
    required this.weight,
    required this.riskLevel,
  });

  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      path: (json['path'] as List)
          .map((point) => RoutePoint(
                latitude: (point[0] as num).toDouble(),
                longitude: (point[1] as num).toDouble(),
              ))
          .toList(),
      totalDistance: (json['total_distance'] as num).toDouble(),
      totalRisk: (json['total_risk'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      riskLevel: RiskLevel.fromString(json['risk_level'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path.map((p) => [p.latitude, p.longitude]).toList(),
      'total_distance': totalDistance,
      'total_risk': totalRisk,
      'weight': weight,
      'risk_level': riskLevel.value,
    };
  }
}

/// Point in a route
class RoutePoint {
  final double latitude;
  final double longitude;

  RoutePoint({required this.latitude, required this.longitude});
}

/// Risk level classification
enum RiskLevel {
  green('Green'),
  yellow('Yellow'),
  red('Red');

  final String value;
  const RiskLevel(this.value);

  static RiskLevel fromString(String value) {
    return RiskLevel.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RiskLevel.yellow,
    );
  }
}
