import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// System Logger Service
/// 
/// Centralized logging service for tracking all system actions.
/// Stores logs in SharedPreferences (temporary solution before database integration).
class SystemLogger {
  static const String _logsKey = 'system_logs';
  static const int _maxLogs = 1000; // Maximum logs to keep in memory

  /// Log an action in the system
  static Future<void> logAction({
    required String userRole,
    required String userName,
    required String action,
    required String module,
    required LogStatus status,
    String? details,
  }) async {
    try {
      final log = SystemLog(
        timestamp: DateTime.now(),
        userRole: userRole,
        userName: userName,
        action: action,
        module: module,
        status: status,
        details: details,
      );

      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getString(_logsKey);
      
      List<Map<String, dynamic>> logs = [];
      if (logsJson != null && logsJson.isNotEmpty) {
        try {
          final decoded = json.decode(logsJson);
          logs = List<Map<String, dynamic>>.from(decoded);
        } catch (e) {
          print('Error parsing logs: $e');
          logs = [];
        }
      }

      // Add new log at the beginning (most recent first)
      logs.insert(0, log.toJson());

      // Keep only the most recent logs
      if (logs.length > _maxLogs) {
        logs = logs.sublist(0, _maxLogs);
      }

      // Save back to SharedPreferences
      await prefs.setString(_logsKey, json.encode(logs));
      
      print('📝 System Log: [$module] $userName ($userRole) - $action [${status.name}]');
    } catch (e) {
      print('Error logging action: $e');
    }
  }

  /// Get all logs
  static Future<List<SystemLog>> getAllLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getString(_logsKey);
      
      if (logsJson == null || logsJson.isEmpty) {
        return [];
      }

      final decoded = json.decode(logsJson);
      final logsList = List<Map<String, dynamic>>.from(decoded);
      
      return logsList.map((json) => SystemLog.fromJson(json)).toList();
    } catch (e) {
      print('Error getting logs: $e');
      return [];
    }
  }

  /// Filter logs by criteria
  static Future<List<SystemLog>> filterLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? userRole,
    String? module,
    LogStatus? status,
    String? searchQuery,
  }) async {
    final allLogs = await getAllLogs();
    
    return allLogs.where((log) {
      // Date range filter
      if (startDate != null && log.timestamp.isBefore(startDate)) {
        return false;
      }
      if (endDate != null && log.timestamp.isAfter(endDate)) {
        return false;
      }

      // User role filter
      if (userRole != null && userRole != 'All' && log.userRole != userRole) {
        return false;
      }

      // Module filter
      if (module != null && module != 'All' && log.module != module) {
        return false;
      }

      // Status filter
      if (status != null && log.status != status) {
        return false;
      }

      // Search query filter
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        return log.userName.toLowerCase().contains(query) ||
               log.action.toLowerCase().contains(query) ||
               log.module.toLowerCase().contains(query) ||
               (log.details?.toLowerCase().contains(query) ?? false);
      }

      return true;
    }).toList();
  }

  /// Clear all logs
  static Future<void> clearAllLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logsKey);
      print('🗑️ All system logs cleared');
    } catch (e) {
      print('Error clearing logs: $e');
    }
  }

  /// Export logs as JSON string
  static Future<String> exportLogsAsJson() async {
    final logs = await getAllLogs();
    final logsJson = logs.map((log) => log.toJson()).toList();
    return json.encode(logsJson);
  }

  /// Get logs count
  static Future<int> getLogsCount() async {
    final logs = await getAllLogs();
    return logs.length;
  }

  /// Get logs by date range
  static Future<List<SystemLog>> getLogsByDateRange(DateTime start, DateTime end) async {
    return filterLogs(startDate: start, endDate: end);
  }

  /// Seed initial sample logs (for demonstration purposes)
  static Future<void> seedSampleLogs() async {
    final count = await getLogsCount();
    if (count > 0) return; // Already have logs

    // Create sample logs
    await logAction(
      userRole: LogUserRole.system,
      userName: 'System',
      action: 'System initialized',
      module: LogModule.system,
      status: LogStatus.success,
    );

    await logAction(
      userRole: LogUserRole.mdrrmo,
      userName: 'MDRRMO Admin',
      action: 'Logged in to admin panel',
      module: LogModule.authentication,
      status: LogStatus.success,
    );

    await logAction(
      userRole: LogUserRole.resident,
      userName: 'Juan Dela Cruz',
      action: 'Submitted hazard report: Flooded Road in Zone 1',
      module: LogModule.reports,
      status: LogStatus.success,
      details: 'Report ID: #001, Type: Flooded Road, Location: Zone 1',
    );

    await logAction(
      userRole: LogUserRole.mdrrmo,
      userName: 'MDRRMO Admin',
      action: 'Approved hazard report #001',
      module: LogModule.reports,
      status: LogStatus.success,
      details: 'Report verified and approved for public visibility',
    );

    await logAction(
      userRole: LogUserRole.resident,
      userName: 'Maria Santos',
      action: 'Generated navigation route to Bulan Gymnasium',
      module: LogModule.navigation,
      status: LogStatus.success,
      details: 'Distance: 2.3 km, ETA: 8 minutes',
    );

    await logAction(
      userRole: LogUserRole.mdrrmo,
      userName: 'MDRRMO Admin',
      action: 'Created new evacuation center: Community Hall',
      module: LogModule.evacuationCenters,
      status: LogStatus.success,
      details: 'Location: Zone 3, Capacity configured',
    );

    await logAction(
      userRole: LogUserRole.resident,
      userName: 'Pedro Reyes',
      action: 'Submitted hazard report: Fallen Tree',
      module: LogModule.reports,
      status: LogStatus.warning,
      details: 'Report pending validation',
    );

    await logAction(
      userRole: LogUserRole.mdrrmo,
      userName: 'MDRRMO Admin',
      action: 'Rejected hazard report #005',
      module: LogModule.reports,
      status: LogStatus.failed,
      details: 'Reason: Duplicate report, already addressed',
    );

    print('✅ Sample logs seeded successfully');
  }
}

/// System Log Model
class SystemLog {
  final DateTime timestamp;
  final String userRole;
  final String userName;
  final String action;
  final String module;
  final LogStatus status;
  final String? details;

  SystemLog({
    required this.timestamp,
    required this.userRole,
    required this.userName,
    required this.action,
    required this.module,
    required this.status,
    this.details,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'userRole': userRole,
      'userName': userName,
      'action': action,
      'module': module,
      'status': status.name,
      'details': details,
    };
  }

  factory SystemLog.fromJson(Map<String, dynamic> json) {
    return SystemLog(
      timestamp: DateTime.parse(json['timestamp']),
      userRole: json['userRole'],
      userName: json['userName'],
      action: json['action'],
      module: json['module'],
      status: LogStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => LogStatus.success,
      ),
      details: json['details'],
    );
  }

  String getFormattedTimestamp() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  String getFullTimestamp() {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }
}

/// Log Status Enum
enum LogStatus {
  success,
  warning,
  failed,
}

/// Module names constants
class LogModule {
  static const String reports = 'Reports';
  static const String evacuationCenters = 'Evacuation Centers';
  static const String users = 'User Management';
  static const String navigation = 'Navigation';
  static const String settings = 'Settings';
  static const String authentication = 'Authentication';
  static const String system = 'System';
}

/// User roles constants
class LogUserRole {
  static const String resident = 'Resident';
  static const String mdrrmo = 'MDRRMO';
  static const String system = 'System';
}
