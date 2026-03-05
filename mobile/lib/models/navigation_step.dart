/// Navigation Step Model
/// Represents a single turn-by-turn instruction
class NavigationStep {
  final String instruction; // "Turn left onto Main Street"
  final String maneuver; // "left", "right", "straight", "arrive"
  final double distanceToNext; // Distance to next step in meters
  final double latitude;
  final double longitude;
  final int stepIndex;

  NavigationStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceToNext,
    required this.latitude,
    required this.longitude,
    required this.stepIndex,
  });

  NavigationStep copyWith({
    String? instruction,
    String? maneuver,
    double? distanceToNext,
    double? latitude,
    double? longitude,
    int? stepIndex,
  }) {
    return NavigationStep(
      instruction: instruction ?? this.instruction,
      maneuver: maneuver ?? this.maneuver,
      distanceToNext: distanceToNext ?? this.distanceToNext,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      stepIndex: stepIndex ?? this.stepIndex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'instruction': instruction,
      'maneuver': maneuver,
      'distanceToNext': distanceToNext,
      'latitude': latitude,
      'longitude': longitude,
      'stepIndex': stepIndex,
    };
  }

  factory NavigationStep.fromJson(Map<String, dynamic> json) {
    return NavigationStep(
      instruction: json['instruction'] ?? '',
      maneuver: json['maneuver'] ?? 'straight',
      distanceToNext: (json['distanceToNext'] ?? 0).toDouble(),
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      stepIndex: json['stepIndex'] ?? 0,
    );
  }
}
