import '../../core/config/api_config.dart';
import '../../models/hazard_report.dart';
import '../../models/evacuation_center.dart';

/// Mock service for MDRRMO admin operations.
/// 
/// FUTURE: Connect to real backend APIs with role-based authentication.
class AdminMockService {
  /// Get all hazard reports with filters.
  /// 
  /// MOCK: Returns mock reports with AI scores.
  /// REAL: GET /api/mdrrmo/reports/?status={status}&barangay={barangay}
  Future<List<HazardReport>> getReports({
    String? status,
    String? barangay,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Mock reports with different statuses and AI scores
    final reports = [
      HazardReport(
        id: 1,
        userId: 3,
        hazardType: 'flooded_road',
        latitude: 12.6700,
        longitude: 123.8755,
        description: 'Severe flooding on main highway near market, water level rising',
        photoUrl: 'https://example.com/photo1.jpg',
        status: HazardStatus.pending,
        naiveBayesScore: 0.92,
        consensusScore: 0.88,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      HazardReport(
        id: 2,
        userId: 5,
        hazardType: 'landslide',
        latitude: 12.6710,
        longitude: 123.8770,
        description: 'Visible cracks on hillside along barangay road',
        status: HazardStatus.pending,
        naiveBayesScore: 0.75,
        consensusScore: 0.70,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      HazardReport(
        id: 3,
        userId: 7,
        hazardType: 'bridge_damage',
        latitude: 12.6685,
        longitude: 123.8745,
        description: 'Bridge showing structural damage, cracks on support beams',
        videoUrl: 'https://example.com/video1.mp4',
        status: HazardStatus.approved,
        naiveBayesScore: 0.95,
        consensusScore: 0.91,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      HazardReport(
        id: 4,
        userId: 4,
        hazardType: 'road_damage',
        latitude: 12.6695,
        longitude: 123.8760,
        description: 'Major pothole causing traffic issues',
        status: HazardStatus.approved,
        naiveBayesScore: 0.68,
        consensusScore: 0.65,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      HazardReport(
        id: 5,
        userId: 6,
        hazardType: 'fallen_electric_post',
        latitude: 12.6720,
        longitude: 123.8765,
        description: 'Electric post fell down, live wires on the road',
        status: HazardStatus.rejected,
        naiveBayesScore: 0.45,
        consensusScore: 0.40,
        adminComment: 'Duplicate report, already documented',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      HazardReport(
        id: 6,
        userId: 8,
        hazardType: 'fallen_tree',
        latitude: 12.6675,
        longitude: 123.8750,
        description: 'Large tree blocking road after storm',
        photoUrl: 'https://example.com/photo2.jpg',
        status: HazardStatus.pending,
        naiveBayesScore: 0.88,
        consensusScore: 0.82,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      HazardReport(
        id: 7,
        userId: 9,
        hazardType: 'road_blocked',
        latitude: 12.6690,
        longitude: 123.8760,
        description: 'Road completely blocked by debris and fallen structures',
        status: HazardStatus.pending,
        naiveBayesScore: 0.80,
        consensusScore: 0.76,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      HazardReport(
        id: 8,
        userId: 10,
        hazardType: 'storm_surge',
        latitude: 12.6665,
        longitude: 123.8735,
        description: 'Storm surge reaching coastal road, high waves observed',
        videoUrl: 'https://example.com/video2.mp4',
        status: HazardStatus.approved,
        naiveBayesScore: 0.90,
        consensusScore: 0.85,
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
    ];

    // Apply filters
    var filtered = reports;
    
    if (status != null && status != 'all') {
      filtered = filtered.where((r) {
        switch (status) {
          case 'pending':
            return r.status == HazardStatus.pending;
          case 'approved':
            return r.status == HazardStatus.approved;
          case 'rejected':
            return r.status == HazardStatus.rejected;
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  /// Get dashboard statistics.
  /// 
  /// MOCK: Returns mock stats.
  /// REAL: GET /api/mdrrmo/dashboard-stats/
  Future<Map<String, dynamic>> getDashboardStats() async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    return {
      'total_reports': 127,
      'pending_reports': 15,
      'verified_hazards': 89,
      'high_risk_roads': 12,
      'total_evacuation_centers': 8,
      'reports_by_barangay': {
        'Zone 1': 23,
        'Zone 2': 18,
        'Zone 3': 31,
        'Zone 4': 15,
        'Zone 5': 22,
        'Zone 6': 18,
      },
      'hazard_distribution': {
        'flooded_road': 45,
        'landslide': 23,
        'road_damage': 15,
        'fallen_tree': 18,
        'fallen_electric_post': 12,
        'road_blocked': 8,
        'bridge_damage': 4,
        'storm_surge': 2,
      },
      'recent_activity': [
        {
          'type': 'report_submitted',
          'message': 'New flood report in Zone 3',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
        },
        {
          'type': 'report_approved',
          'message': 'Landslide report approved',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 15)),
        },
        {
          'type': 'center_updated',
          'message': 'Evacuation center data updated',
          'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
        },
      ],
    };
  }

  /// Approve a hazard report.
  /// 
  /// MOCK: Returns updated report.
  /// REAL: POST /api/mdrrmo/approve-report/
  Future<HazardReport> approveReport(int reportId, {String? comment}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    return HazardReport(
      id: reportId,
      userId: 3,
      hazardType: 'flood',
      latitude: 12.6700,
      longitude: 123.8755,
      description: 'Severe flooding on main highway',
      status: HazardStatus.approved,
      naiveBayesScore: 0.92,
      consensusScore: 0.88,
      adminComment: comment,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    );
  }

  /// Reject a hazard report.
  /// 
  /// MOCK: Returns updated report.
  /// REAL: POST /api/mdrrmo/reject-report/
  Future<HazardReport> rejectReport(int reportId, {String? comment}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    return HazardReport(
      id: reportId,
      userId: 3,
      hazardType: 'flood',
      latitude: 12.6700,
      longitude: 123.8755,
      description: 'Severe flooding on main highway',
      status: HazardStatus.rejected,
      naiveBayesScore: 0.92,
      consensusScore: 0.88,
      adminComment: comment ?? 'Report does not meet verification criteria',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    );
  }

  /// Get all evacuation centers for admin management.
  /// 
  /// MOCK: Returns mock centers with additional admin fields.
  /// REAL: GET /api/mdrrmo/evacuation-centers/
  Future<List<EvacuationCenter>> getEvacuationCenters() async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    return [
      EvacuationCenter(
        id: 1,
        name: 'Bulan Gymnasium',
        latitude: 12.6699,
        longitude: 123.8758,
        description: 'Main evacuation center with medical facilities',
      ),
      EvacuationCenter(
        id: 2,
        name: 'Bulan National High School',
        latitude: 12.6720,
        longitude: 123.8770,
        description: 'School buildings converted to shelter',
      ),
      EvacuationCenter(
        id: 3,
        name: 'Barangay Hall Zone 1',
        latitude: 12.6680,
        longitude: 123.8740,
        description: 'Community center for evacuation',
      ),
      EvacuationCenter(
        id: 4,
        name: 'Central Elementary School',
        latitude: 12.6690,
        longitude: 123.8765,
        description: 'Elementary school with large capacity',
      ),
      EvacuationCenter(
        id: 5,
        name: 'City Sports Complex',
        latitude: 12.6710,
        longitude: 123.8755,
        description: 'Sports facility with covered areas',
      ),
    ];
  }

  /// Add a new evacuation center.
  /// 
  /// MOCK: Returns created center with generated ID.
  /// REAL: POST /api/mdrrmo/evacuation-centers/
  Future<EvacuationCenter> addEvacuationCenter({
    required String name,
    required String barangay,
    required String address,
    required String contactNumber,
    required double latitude,
    required double longitude,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    return EvacuationCenter(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name,
      latitude: latitude,
      longitude: longitude,
      description: 'Located in $barangay - $address. Contact: $contactNumber',
    );
  }

  /// Update an existing evacuation center.
  /// 
  /// MOCK: Returns updated center.
  /// REAL: PUT /api/mdrrmo/evacuation-centers/{id}/
  Future<EvacuationCenter> updateEvacuationCenter({
    required int id,
    required String name,
    required String barangay,
    required String address,
    required String contactNumber,
    required double latitude,
    required double longitude,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    return EvacuationCenter(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      description: 'Located in $barangay - $address. Contact: $contactNumber',
    );
  }

  /// Deactivate an evacuation center.
  /// 
  /// MOCK: Returns success message.
  /// REAL: POST /api/mdrrmo/evacuation-centers/{id}/deactivate/
  Future<bool> deactivateEvacuationCenter(int id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  /// Get analytics data.
  /// 
  /// MOCK: Returns mock analytics.
  /// REAL: GET /api/mdrrmo/analytics/
  Future<Map<String, dynamic>> getAnalytics() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    return {
      'most_dangerous_barangays': [
        {'name': 'Zone 3', 'risk_score': 0.85, 'hazard_count': 31},
        {'name': 'Zone 5', 'risk_score': 0.72, 'hazard_count': 22},
        {'name': 'Zone 1', 'risk_score': 0.68, 'hazard_count': 23},
        {'name': 'Zone 2', 'risk_score': 0.55, 'hazard_count': 18},
        {'name': 'Zone 6', 'risk_score': 0.48, 'hazard_count': 18},
      ],
      'hazard_type_distribution': {
        'flooded_road': 45,
        'landslide': 23,
        'road_damage': 15,
        'fallen_tree': 18,
        'fallen_electric_post': 12,
        'road_blocked': 8,
        'bridge_damage': 4,
        'storm_surge': 2,
      },
      'road_risk_distribution': {
        'high_risk': 12,
        'moderate_risk': 28,
        'low_risk': 45,
      },
      'model_statistics': {
        'naive_bayes_accuracy': 0.87,
        'consensus_accuracy': 0.82,
        'random_forest_accuracy': 0.89,
        'model_version': '1.2.3',
        'dataset_version': '2024-02',
        'last_trained': DateTime.now().subtract(const Duration(days: 15)),
      },
      'evacuation_centers_per_barangay': {
        'Zone 1': 2,
        'Zone 2': 1,
        'Zone 3': 2,
        'Zone 4': 1,
        'Zone 5': 1,
        'Zone 6': 1,
      },
    };
  }

  /// Trigger model retraining.
  /// 
  /// MOCK: Simulates retraining process.
  /// REAL: POST /api/mdrrmo/retrain-models/
  Future<bool> triggerModelRetraining() async {
    await Future.delayed(const Duration(seconds: 2));
    return true;
  }

  /// Sync baseline hazard data from MDRRMO database.
  /// 
  /// MOCK: Simulates data sync.
  /// REAL: POST /api/mdrrmo/sync-baseline-data/
  Future<bool> syncBaselineData() async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  /// Clear app cache.
  /// 
  /// MOCK: Returns success.
  /// REAL: POST /api/mdrrmo/clear-cache/
  Future<bool> clearCache() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }
}
