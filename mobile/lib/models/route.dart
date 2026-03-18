/// One contributing factor (hazard) affecting route risk (from backend).
class ContributingFactor {
  final String hazardType;
  final String severity;
  final String location;

  ContributingFactor({
    required this.hazardType,
    required this.severity,
    required this.location,
  });

  factory ContributingFactor.fromJson(Map<String, dynamic> json) {
    return ContributingFactor(
      hazardType: (json['hazard_type'] as String?) ?? 'Hazard',
      severity: (json['severity'] as String?) ?? '—',
      location: (json['location'] as String?) ?? '—',
    );
  }
}

/// Alternative evacuation center when no safe route to selected center (from backend).
class AlternativeCenter {
  final int centerId;
  final String centerName;
  final bool hasSafeRoute;
  final double? bestRouteRisk;

  AlternativeCenter({
    required this.centerId,
    required this.centerName,
    required this.hasSafeRoute,
    this.bestRouteRisk,
  });

  factory AlternativeCenter.fromJson(Map<String, dynamic> json) {
    return AlternativeCenter(
      centerId: (json['center_id'] as num?)?.toInt() ?? 0,
      centerName: (json['center_name'] as String?) ?? '',
      hasSafeRoute: (json['has_safe_route'] as bool?) ?? false,
      bestRouteRisk: json['best_route_risk'] != null
          ? (json['best_route_risk'] as num).toDouble()
          : null,
    );
  }
}

/// Result of route calculation including safety layer (no_safe_route, alternatives, etc.).
class RouteCalculationResult {
  final List<Route> routes;
  final bool noSafeRoute;
  final String? message;
  final String? recommendedAction;
  final List<AlternativeCenter> alternativeCenters;

  RouteCalculationResult({
    required this.routes,
    this.noSafeRoute = false,
    this.message,
    this.recommendedAction,
    this.alternativeCenters = const [],
  });
}

/// Hazard along a route (from backend: approved hazards near the path).
class RouteHazard {
  final String hazardType;
  final double latitude;
  final double longitude;
  final double? distanceKmFromStart;

  RouteHazard({
    required this.hazardType,
    required this.latitude,
    required this.longitude,
    this.distanceKmFromStart,
  });

  factory RouteHazard.fromJson(Map<String, dynamic> json) {
    return RouteHazard(
      hazardType: (json['hazard_type'] as String?) ?? 'hazard',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceKmFromStart: json['distance_km_from_start'] != null
          ? (json['distance_km_from_start'] as num).toDouble()
          : null,
    );
  }

  /// Human-readable label for location (e.g. "near Km 2.1" or coordinates).
  String get locationLabel {
    if (distanceKmFromStart != null) {
      return 'Near Km ${distanceKmFromStart!.toStringAsFixed(1)}';
    }
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  String get hazardTypeDisplay {
    return hazardType
        .replaceAll('_', ' ')
        .split(' ')
        .map((e) => e.isEmpty ? '' : '${e[0].toUpperCase()}${e.length > 1 ? e.substring(1).toLowerCase() : ''}')
        .join(' ');
  }
}

/// Route model representing a calculated evacuation route.
class Route {
  final List<RoutePoint> path;
  final double totalDistance; // in meters
  final double totalRisk; // 0.0 - 1.0
  final double weight; // distance + risk penalty
  final RiskLevel riskLevel;
  final List<RouteHazard> hazardsAlongRoute;
  /// "High Risk" or "Safer Route" (from backend risk evaluation layer).
  final String riskLabel;
  /// True when total_risk > 0.9 (possibly blocked).
  final bool possiblyBlocked;
  /// Hazards contributing to this route's risk (for transparency).
  final List<ContributingFactor> contributingFactors;

  Route({
    required this.path,
    required this.totalDistance,
    required this.totalRisk,
    required this.weight,
    required this.riskLevel,
    this.hazardsAlongRoute = const [],
    this.riskLabel = 'Safer Route',
    this.possiblyBlocked = false,
    this.contributingFactors = const [],
  });

  factory Route.fromJson(Map<String, dynamic> json) {
    final hazardsRaw = json['hazards_along_route'];
    final List<RouteHazard> hazards = hazardsRaw is List
        ? (hazardsRaw as List).map((e) => RouteHazard.fromJson(Map<String, dynamic>.from(e as Map))).toList()
        : [];
    final contribRaw = json['contributing_factors'];
    final List<ContributingFactor> contrib = contribRaw is List
        ? (contribRaw as List).map((e) => ContributingFactor.fromJson(Map<String, dynamic>.from(e as Map))).toList()
        : [];
    return Route(
      path: (json['path'] as List)
          .map((point) => RoutePoint(
                latitude: (point[0] as num).toDouble(),
                longitude: (point[1] as num).toDouble(),
              ))
          .toList(),
      totalDistance: (json['total_distance'] as num).toDouble(),
      totalRisk: (json['total_risk'] as num).toDouble(),
      weight: (json['weight'] != null ? (json['weight'] as num).toDouble() : (json['total_distance'] as num).toDouble()),
      riskLevel: RiskLevel.fromString(json['risk_level'] as String? ?? 'Yellow'),
      hazardsAlongRoute: hazards,
      riskLabel: (json['risk_label'] as String?) ?? 'Safer Route',
      possiblyBlocked: (json['possibly_blocked'] as bool?) ?? false,
      contributingFactors: contrib,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path.map((p) => [p.latitude, p.longitude]).toList(),
      'total_distance': totalDistance,
      'total_risk': totalRisk,
      'weight': weight,
      'risk_level': riskLevel.value,
      'risk_label': riskLabel,
      'possibly_blocked': possiblyBlocked,
      'hazards_along_route': hazardsAlongRoute.map((h) => {
            'hazard_type': h.hazardType,
            'latitude': h.latitude,
            'longitude': h.longitude,
            'distance_km_from_start': h.distanceKmFromStart,
          }).toList(),
      'contributing_factors': contributingFactors.map((c) => {
            'hazard_type': c.hazardType,
            'severity': c.severity,
            'location': c.location,
          }).toList(),
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
