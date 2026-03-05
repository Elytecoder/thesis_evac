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
  
  // Operational status fields
  final bool isOperational;
  final DateTime? deactivatedAt;
  
  // Structured address fields
  final String? province;
  final String? municipality;
  final String? barangay;
  final String? street;
  final String? contactNumber;

  EvacuationCenter({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.description,
    this.isOperational = true,
    this.deactivatedAt,
    this.province,
    this.municipality,
    this.barangay,
    this.street,
    this.contactNumber,
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
      isOperational: json['is_operational'] as bool? ?? true,
      deactivatedAt: json['deactivated_at'] != null
          ? DateTime.parse(json['deactivated_at'] as String)
          : null,
      province: json['province'] as String?,
      municipality: json['municipality'] as String?,
      barangay: json['barangay'] as String?,
      street: json['street'] as String?,
      contactNumber: json['contact_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'description': description,
    'is_operational': isOperational,
    'deactivated_at': deactivatedAt?.toIso8601String(),
    'province': province,
    'municipality': municipality,
    'barangay': barangay,
    'street': street,
    'contact_number': contactNumber,
  };
  
  /// Helper to get full formatted address
  String get fullAddress {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (barangay != null && barangay!.isNotEmpty) parts.add(barangay!);
    if (municipality != null && municipality!.isNotEmpty) parts.add(municipality!);
    if (province != null && province!.isNotEmpty) parts.add(province!);
    
    return parts.isNotEmpty ? parts.join(', ') : description;
  }
  
  /// Helper to get operational status text
  String get operationalStatus => isOperational ? 'Operational' : 'Not Operational';
  
  /// Create a copy with modified fields
  EvacuationCenter copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    String? description,
    bool? isOperational,
    DateTime? deactivatedAt,
    String? province,
    String? municipality,
    String? barangay,
    String? street,
    String? contactNumber,
  }) {
    return EvacuationCenter(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      isOperational: isOperational ?? this.isOperational,
      deactivatedAt: deactivatedAt ?? this.deactivatedAt,
      province: province ?? this.province,
      municipality: municipality ?? this.municipality,
      barangay: barangay ?? this.barangay,
      street: street ?? this.street,
      contactNumber: contactNumber ?? this.contactNumber,
    );
  }
}
