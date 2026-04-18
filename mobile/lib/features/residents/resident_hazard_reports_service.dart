import '../../core/config/api_config.dart';
import '../../features/hazards/hazard_service.dart';
import '../../models/hazard_report.dart';

/// Service for displaying verified and current user's pending hazard reports on the map.
/// When not in mock mode, fetches from API: verified hazards + my reports (pending only for "my" on map).
class ResidentHazardReportsService {
  // Current user ID (mock key; for API we use is_current_user on each report)
  static const String currentUserId = 'current_user';

  final HazardService _hazardService = HazardService();

  /// Convert HazardReport to map format expected by map UI (lat, lng, type, status, id, reported_by, description, date_submitted, media).
  static Map<String, dynamic> _reportToMap(HazardReport r, {required bool isCurrentUser}) {
    final media = <Map<String, dynamic>>[];
    if (r.photoUrl != null && r.photoUrl!.isNotEmpty) {
      media.add({'type': 'image', 'url': r.photoUrl!});
    }
    if (r.videoUrl != null && r.videoUrl!.isNotEmpty) {
      media.add({'type': 'video', 'url': r.videoUrl!});
    }
    return {
      'id': r.id,
      'lat': r.latitude,
      'lng': r.longitude,
      'type': r.hazardType,
      'status': r.status == HazardStatus.approved ? 'verified' : r.status.value,
      'reported_by': isCurrentUser ? currentUserId : (r.userId?.toString() ?? ''),
      'description': r.description,
      'date_submitted': r.createdAt != null
          ? () {
              final local = r.createdAt!.toLocal();
              final h = local.hour.toString().padLeft(2, '0');
              final m = local.minute.toString().padLeft(2, '0');
              return '${local.month}/${local.day}/${local.year} at $h:$m';
            }()
          : '',
      'media': media,
    };
  }

  // Mock hazard reports data (used only when ApiConfig.useMockData is true)
  static List<Map<String, dynamic>> _hazardReports = [
    // Verified reports (visible to all)
    {
      'id': 'rep001',
      'type': 'Flooded Road',
      'description': 'Flooded road blocking vehicles and pedestrians',
      'lat': 12.6699,
      'lng': 123.8758,
      'status': 'verified',
      'reported_by': 'user_1',
      'date_submitted': '2026-03-01',
      'date_approved': '2026-03-02',
      'media': [], // No media
    },
    {
      'id': 'rep002',
      'type': 'Fallen Tree',
      'description': 'Large tree blocking the main road',
      'lat': 12.6705,
      'lng': 123.8764,
      'status': 'verified',
      'reported_by': 'user_2',
      'date_submitted': '2026-03-02',
      'date_approved': '2026-03-03',
      'media': [],
    },
    {
      'id': 'rep003',
      'type': 'Road Damage',
      'description': 'Deep potholes making road dangerous',
      'lat': 12.6710,
      'lng': 123.8770,
      'status': 'verified',
      'reported_by': 'user_3',
      'date_submitted': '2026-03-03',
      'date_approved': '2026-03-04',
      'media': [],
    },
    {
      'id': 'rep004',
      'type': 'Landslide',
      'description': 'Landslide debris blocking access road',
      'lat': 12.6695,
      'lng': 123.8752,
      'status': 'verified',
      'reported_by': 'user_4',
      'date_submitted': '2026-02-28',
      'date_approved': '2026-03-01',
      'media': [],
    },
    
    // Current user's pending reports (with media attachments)
    {
      'id': 'rep005',
      'type': 'Fallen Electric Post / Wires',
      'description': 'Fallen electric post with exposed wires',
      'lat': 12.6702,
      'lng': 123.8760,
      'status': 'pending',
      'reported_by': currentUserId,
      'date_submitted': '2026-03-05',
      'media': [
        {'type': 'image', 'url': 'https://via.placeholder.com/400x300?text=Fallen+Electric+Post'},
        {'type': 'image', 'url': 'https://via.placeholder.com/400x300?text=Exposed+Wires'},
      ],
    },
    {
      'id': 'rep006',
      'type': 'Bridge Damage',
      'description': 'Cracks on bridge structure, unsafe for heavy vehicles',
      'lat': 12.6708,
      'lng': 123.8768,
      'status': 'pending',
      'reported_by': currentUserId,
      'date_submitted': '2026-03-04',
      'media': [
        {'type': 'image', 'url': 'https://via.placeholder.com/400x300?text=Bridge+Cracks'},
      ],
    },
    
    // Other users' pending reports (should NOT be visible to current user)
    {
      'id': 'rep007',
      'type': 'Road Blocked',
      'description': 'Construction blocking road',
      'lat': 12.6715,
      'lng': 123.8775,
      'status': 'pending',
      'reported_by': 'user_5',
      'date_submitted': '2026-03-05',
      'media': [],
    },
  ];

  /// Get all verified hazard reports (visible to all residents)
  Future<List<Map<String, dynamic>>> getVerifiedReports() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _hazardReports
        .where((report) => report['status'] == 'verified')
        .toList();
  }

  /// Get current user's pending reports
  Future<List<Map<String, dynamic>>> getCurrentUserPendingReports() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _hazardReports
        .where((report) => 
            report['status'] == 'pending' && 
            report['reported_by'] == currentUserId)
        .toList();
  }

  /// Get all reports for map display (verified + current user's own reports: pending, rejected, and approved so they always see their submission).
  /// When not in mock mode: fetches verified hazards and my reports from API, merges and converts to map format.
  Future<List<Map<String, dynamic>>> getMapReports() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _hazardReports.where((report) {
        return report['status'] == 'verified' ||
            (report['status'] == 'pending' && report['reported_by'] == currentUserId);
      }).toList();
    }

    final List<Map<String, dynamic>> out = [];
    List<HazardReport> verified = [];
    List<HazardReport> myReports = [];

    try {
      verified = await _hazardService.getVerifiedHazards();
    } catch (_) {
      verified = [];
    }
    try {
      myReports = await _hazardService.getMyReports();
    } catch (_) {
      myReports = [];
    }

    final verifiedIds = verified.map((r) => r.id).whereType<int>().toSet();
    for (final r in verified) {
      out.add(_reportToMap(r, isCurrentUser: false));
    }
    for (final r in myReports) {
      // Only show own reports that are still pending — rejected / deleted
      // reports must not appear as map markers for the resident.
      if (r.status != HazardStatus.pending) continue;
      if (r.id != null && verifiedIds.contains(r.id)) continue;
      out.add(_reportToMap(r, isCurrentUser: true));
    }
    return out;
  }

  /// Delete a pending report (only if status is pending and belongs to current user).
  /// When not in mock mode: calls API DELETE /api/my-reports/{id}/
  Future<bool> deletePendingReport(dynamic reportId) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      final id = reportId is int ? reportId : int.tryParse(reportId.toString());
      if (id == null) return false;
      final index = _hazardReports.indexWhere((r) => r['id'] == reportId || r['id'] == id);
      if (index != -1) {
        final report = _hazardReports[index];
        if (report['status'] == 'pending' && report['reported_by'] == currentUserId) {
          _hazardReports.removeAt(index);
          return true;
        }
      }
      return false;
    }

    try {
      final id = reportId is int ? reportId : int.tryParse(reportId.toString());
      if (id == null) return false;
      await _hazardService.deleteMyReport(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get report by ID (for notification → map). Returns map with lat, lng, or null.
  Future<Map<String, dynamic>?> getReportById(String reportId) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        return _hazardReports.firstWhere((r) => r['id'] == reportId);
      } catch (_) {
        return null;
      }
    }
    final id = int.tryParse(reportId);
    if (id == null) return null;
    try {
      final myReports = await _hazardService.getMyReports();
      for (final r in myReports) {
        if (r.id == id) {
          return _reportToMap(r, isCurrentUser: true);
        }
      }
      final verified = await _hazardService.getVerifiedHazards();
      for (final r in verified) {
        if (r.id == id) {
          return _reportToMap(r, isCurrentUser: false);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Add new report (for testing)
  Future<void> addReport(Map<String, dynamic> report) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _hazardReports.add(report);
  }
}
