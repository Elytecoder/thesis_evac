/// Evacuation Center Model
/// 
/// Represents a safe evacuation destination.
/// 
/// Synced from backend via /api/evacuation-centers/
/// Cached offline using Hive
class EvacuationCenter {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String description;

  EvacuationCenter({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.description,
  });

  factory EvacuationCenter.fromJson(Map<String, dynamic> json) {
    return EvacuationCenter(
      id: json['id'] as int,
      name: json['name'] as String,
      latitude: json['latitude'] is String 
          ? double.parse(json['latitude']) 
          : (json['latitude'] as num).toDouble(),
      longitude: json['longitude'] is String 
          ? double.parse(json['longitude']) 
          : (json['longitude'] as num).toDouble(),
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'description': description,
  };
}
