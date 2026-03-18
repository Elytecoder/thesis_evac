/// System log entry model.
class SystemLog {
  final int id;
  final int? userId;
  final String userRole;
  final String userName;
  final String action;
  final String module;
  final String status;
  final String description;
  final String? ipAddress;
  final DateTime createdAt;

  SystemLog({
    required this.id,
    this.userId,
    required this.userRole,
    required this.userName,
    required this.action,
    required this.module,
    required this.status,
    required this.description,
    this.ipAddress,
    required this.createdAt,
  });

  factory SystemLog.fromJson(Map<String, dynamic> json) {
    return SystemLog(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      userRole: json['user_role'] as String? ?? '',
      userName: json['user_name'] as String? ?? 'System',
      action: json['action'] as String,
      module: json['module'] as String,
      status: json['status'] as String,
      description: json['description'] as String? ?? '',
      ipAddress: json['ip_address'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_role': userRole,
      'user_name': userName,
      'action': action,
      'module': module,
      'status': status,
      'description': description,
      'ip_address': ipAddress,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Short relative/absolute time for list display.
  String getFormattedTimestamp() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  /// Full datetime for detail display.
  String getFullTimestamp() {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year} '
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}:${createdAt.second.toString().padLeft(2, '0')}';
  }

  /// Display label for module (backend sends e.g. hazard_reports).
  String get moduleDisplay => _moduleDisplayMap[module] ?? module;

  static const _moduleDisplayMap = {
    'authentication': 'Authentication',
    'user_management': 'User Management',
    'hazard_reports': 'Hazard Reports',
    'evacuation_centers': 'Evacuation Centers',
    'navigation': 'Navigation',
    'system': 'System',
  };
}
