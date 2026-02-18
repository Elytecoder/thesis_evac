/// Baseline hazard model (MDRRMO data).
class BaselineHazard {
  final int id;
  final String hazardType;
  final double latitude;
  final double longitude;
  final double severity; // 0.0 - 1.0
  final String source;
  final DateTime? createdAt;

  BaselineHazard({
    required this.id,
    required this.hazardType,
    required this.latitude,
    required this.longitude,
    required this.severity,
    this.source = 'MDRRMO',
    this.createdAt,
  });

  factory BaselineHazard.fromJson(Map<String, dynamic> json) {
    return BaselineHazard(
      id: json['id'] as int,
      hazardType: json['hazard_type'] as String,
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      severity: double.parse(json['severity'].toString()),
      source: json['source'] as String? ?? 'MDRRMO',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hazard_type': hazardType,
      'latitude': latitude,
      'longitude': longitude,
      'severity': severity,
      'source': source,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
