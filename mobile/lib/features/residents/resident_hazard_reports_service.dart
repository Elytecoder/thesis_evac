/// Mock Hazard Reports Service for Residents
/// Provides mock data for displaying verified and pending hazard reports on map
class ResidentHazardReportsService {
  // Current user ID (mock - will come from auth later)
  static const String currentUserId = 'current_user';

  // Mock hazard reports data
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

  /// Get all reports for map display (verified + current user's pending)
  Future<List<Map<String, dynamic>>> getMapReports() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _hazardReports.where((report) {
      return report['status'] == 'verified' || 
             (report['status'] == 'pending' && report['reported_by'] == currentUserId);
    }).toList();
  }

  /// Delete a pending report (only if status is pending)
  Future<bool> deletePendingReport(String reportId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final index = _hazardReports.indexWhere((r) => r['id'] == reportId);
    if (index != -1) {
      final report = _hazardReports[index];
      
      // Only allow deletion if status is pending and belongs to current user
      if (report['status'] == 'pending' && report['reported_by'] == currentUserId) {
        _hazardReports.removeAt(index);
        return true;
      }
    }
    return false;
  }

  /// Get report by ID
  Future<Map<String, dynamic>?> getReportById(String reportId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _hazardReports.firstWhere((r) => r['id'] == reportId);
    } catch (e) {
      return null;
    }
  }

  /// Add new report (for testing)
  Future<void> addReport(Map<String, dynamic> report) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _hazardReports.add(report);
  }
}
