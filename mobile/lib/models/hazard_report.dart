/// Hazard report model for crowdsourced reports.
class HazardReport {
  final int? id;
  final int? userId;
  final String hazardType;
  final double latitude;
  final double longitude;
  final String description;
  final String? photoUrl;
  final String? videoUrl;
  final HazardStatus status;
  final double? naiveBayesScore;
  final double? consensusScore;
  final String? adminComment;
  final DateTime? createdAt;

  HazardReport({
    this.id,
    this.userId,
    required this.hazardType,
    required this.latitude,
    required this.longitude,
    required this.description,
    this.photoUrl,
    this.videoUrl,
    this.status = HazardStatus.pending,
    this.naiveBayesScore,
    this.consensusScore,
    this.adminComment,
    this.createdAt,
  });

  factory HazardReport.fromJson(Map<String, dynamic> json) {
    return HazardReport(
      id: json['id'] as int?,
      userId: json['user'] as int?,
      hazardType: json['hazard_type'] as String,
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      description: json['description'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      videoUrl: json['video_url'] as String?,
      status: HazardStatus.fromString(json['status'] as String? ?? 'pending'),
      naiveBayesScore: (json['naive_bayes_score'] as num?)?.toDouble(),
      consensusScore: (json['consensus_score'] as num?)?.toDouble(),
      adminComment: json['admin_comment'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user': userId,
      'hazard_type': hazardType,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (videoUrl != null) 'video_url': videoUrl,
      'status': status.value,
      if (naiveBayesScore != null) 'naive_bayes_score': naiveBayesScore,
      if (consensusScore != null) 'consensus_score': consensusScore,
      if (adminComment != null) 'admin_comment': adminComment,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

/// Hazard status enum
enum HazardStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  final String value;
  const HazardStatus(this.value);

  static HazardStatus fromString(String value) {
    return HazardStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => HazardStatus.pending,
    );
  }
}
