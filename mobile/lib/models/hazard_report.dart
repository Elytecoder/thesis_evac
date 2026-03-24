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
    final lat = json['latitude'];
    final lng = json['longitude'];
    final idVal = json['id'];
    final userIdVal = json['user'];
    return HazardReport(
      id: idVal is int ? idVal : (idVal != null ? int.tryParse(idVal.toString()) : null),
      userId: userIdVal is int ? userIdVal : (userIdVal != null ? int.tryParse(userIdVal.toString()) : null),
      hazardType: (json['hazard_type'] as String?) ?? '',
      latitude: lat == null ? 0.0 : (lat is num ? lat.toDouble() : double.tryParse(lat.toString()) ?? 0.0),
      longitude: lng == null ? 0.0 : (lng is num ? lng.toDouble() : double.tryParse(lng.toString()) ?? 0.0),
      userLatitude: json['user_latitude'] != null ? double.tryParse(json['user_latitude'].toString()) : null,
      userLongitude: json['user_longitude'] != null ? double.tryParse(json['user_longitude'].toString()) : null,
      description: json['description'] as String? ?? '',
      photoUrl: _nonEmptyString(json['photo_url']),
      videoUrl: _nonEmptyString(json['video_url']),
      status: HazardStatus.fromString(json['status'] as String? ?? 'pending'),
      autoRejected: json['auto_rejected'] as bool? ?? false,
      naiveBayesScore: (json['naive_bayes_score'] as num?)?.toDouble(),
      consensusScore: (json['consensus_score'] as num?)?.toDouble(),
      validationBreakdown: json['validation_breakdown'] != null && json['validation_breakdown'] is Map
          ? Map<String, dynamic>.from(json['validation_breakdown'] as Map)
          : null,
      adminComment: json['admin_comment'] as String?,
      restorationReason: json['restoration_reason'] as String?,
      restoredAt: json['restored_at'] != null ? DateTime.tryParse(json['restored_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      rejectedAt: json['rejected_at'] != null ? DateTime.tryParse(json['rejected_at'].toString()) : null,
      deletionScheduledAt: json['deletion_scheduled_at'] != null
          ? DateTime.tryParse(json['deletion_scheduled_at'].toString())
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
  
  static String? _nonEmptyString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
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
