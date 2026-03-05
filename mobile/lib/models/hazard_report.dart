/// Hazard report model for crowdsourced reports.
class HazardReport {
  final int? id;
  final int? userId;
  final String hazardType;
  
  // Hazard location (reported location)
  final double latitude;
  final double longitude;
  
  // User location at time of report (for proximity validation)
  final double? userLatitude;
  final double? userLongitude;
  
  final String description;
  final String? photoUrl;
  final String? videoUrl;
  final HazardStatus status;
  
  // Auto-rejection flag
  final bool autoRejected;
  
  // AI validation scores (Naive Bayes only for report validation)
  final double? naiveBayesScore;
  final double? consensusScore;
  /// Naive Bayes technical breakdown for MDRRMO "View Technical Details". No Random Forest data.
  final Map<String, dynamic>? validationBreakdown;

  // Admin actions
  final String? adminComment;
  
  // Restoration feature
  final String? restorationReason;
  final DateTime? restoredAt;
  
  // Timestamps
  final DateTime? createdAt;
  final DateTime? rejectedAt;
  final DateTime? deletionScheduledAt;

  HazardReport({
    this.id,
    this.userId,
    required this.hazardType,
    required this.latitude,
    required this.longitude,
    this.userLatitude,
    this.userLongitude,
    required this.description,
    this.photoUrl,
    this.videoUrl,
    this.status = HazardStatus.pending,
    this.autoRejected = false,
    this.naiveBayesScore,
    this.consensusScore,
    this.validationBreakdown,
    this.adminComment,
    this.restorationReason,
    this.restoredAt,
    this.createdAt,
    this.rejectedAt,
    this.deletionScheduledAt,
  });

  factory HazardReport.fromJson(Map<String, dynamic> json) {
    return HazardReport(
      id: json['id'] as int?,
      userId: json['user'] as int?,
      hazardType: json['hazard_type'] as String,
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      userLatitude: json['user_latitude'] != null ? double.parse(json['user_latitude'].toString()) : null,
      userLongitude: json['user_longitude'] != null ? double.parse(json['user_longitude'].toString()) : null,
      description: json['description'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      videoUrl: json['video_url'] as String?,
      status: HazardStatus.fromString(json['status'] as String? ?? 'pending'),
      autoRejected: json['auto_rejected'] as bool? ?? false,
      naiveBayesScore: (json['naive_bayes_score'] as num?)?.toDouble(),
      consensusScore: (json['consensus_score'] as num?)?.toDouble(),
      validationBreakdown: json['validation_breakdown'] as Map<String, dynamic>?,
      adminComment: json['admin_comment'] as String?,
      restorationReason: json['restoration_reason'] as String?,
      restoredAt: json['restored_at'] != null
          ? DateTime.parse(json['restored_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      rejectedAt: json['rejected_at'] != null
          ? DateTime.parse(json['rejected_at'] as String)
          : null,
      deletionScheduledAt: json['deletion_scheduled_at'] != null
          ? DateTime.parse(json['deletion_scheduled_at'] as String)
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
      if (userLatitude != null) 'user_latitude': userLatitude,
      if (userLongitude != null) 'user_longitude': userLongitude,
      'description': description,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (videoUrl != null) 'video_url': videoUrl,
      'status': status.value,
      'auto_rejected': autoRejected,
      if (naiveBayesScore != null) 'naive_bayes_score': naiveBayesScore,
      if (consensusScore != null) 'consensus_score': consensusScore,
      if (validationBreakdown != null) 'validation_breakdown': validationBreakdown,
      if (adminComment != null) 'admin_comment': adminComment,
      if (restorationReason != null) 'restoration_reason': restorationReason,
      if (restoredAt != null) 'restored_at': restoredAt!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (rejectedAt != null) 'rejected_at': rejectedAt!.toIso8601String(),
      if (deletionScheduledAt != null) 'deletion_scheduled_at': deletionScheduledAt!.toIso8601String(),
    };
  }
  
  /// Check if report can be restored (within 15 days)
  bool get canBeRestored {
    if (status != HazardStatus.rejected || rejectedAt == null) return false;
    final daysSinceRejection = DateTime.now().difference(rejectedAt!).inDays;
    return daysSinceRejection < 15;
  }
  
  /// Get days remaining before auto-deletion
  int get daysUntilDeletion {
    if (deletionScheduledAt == null) return 0;
    final remaining = deletionScheduledAt!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
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
