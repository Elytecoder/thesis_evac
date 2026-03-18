/// Notification model for user alerts.
class UserNotification {
  final int id;
  final String type;
  final String title;
  final String message;
  final String? relatedObjectType;
  final int? relatedObjectId;
  final bool isRead;
  final DateTime? readAt;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  UserNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.relatedObjectType,
    this.relatedObjectId,
    required this.isRead,
    this.readAt,
    this.metadata,
    required this.createdAt,
  });

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'];
    final createdAtVal = json['created_at'];
    return UserNotification(
      id: idVal is int ? idVal : int.tryParse(idVal?.toString() ?? '0') ?? 0,
      type: json['type'] as String? ?? 'system_alert',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      relatedObjectType: json['related_object_type'] as String?,
      relatedObjectId: json['related_object_id'] is int ? json['related_object_id'] as int : int.tryParse(json['related_object_id']?.toString() ?? ''),
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      metadata: json['metadata'] != null && json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      createdAt: createdAtVal != null ? DateTime.tryParse(createdAtVal.toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'related_object_type': relatedObjectType,
      'related_object_id': relatedObjectId,
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Notification types
class NotificationType {
  static const String reportApproved = 'report_approved';
  static const String reportRejected = 'report_rejected';
  static const String reportRestored = 'report_restored';
  static const String centerDeactivated = 'center_deactivated';
  static const String systemAlert = 'system_alert';
}
