import '../../core/config/api_config.dart';
import '../../models/hazard_report.dart';
import '../../models/evacuation_center.dart';

/// Legacy mock service for MDRRMO.
///
/// Reports, evacuation centers, users, and dashboard stats now use real APIs
/// (HazardService, EvacuationCenterService, UserManagementService, MdrrmoDashboardService).
/// The following methods are still mock until backend implements endpoints:
/// getAnalytics, triggerModelRetraining, syncBaselineData, clearCache.
class AdminMockService {
  /// Get all hazard reports with filters.
  /// 
  /// MOCK: Returns mock reports with AI scores (excludes auto-rejected).
  /// REAL: GET /api/mdrrmo/reports/?status={status}&barangay={barangay}
  Future<List<HazardReport>> getReports({
    String? status,
    String? barangay,
    String? sortBy,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Mock reports with different statuses and AI scores
    // NOTE: Auto-rejected reports are NOT included in this list
    final reports = [
      HazardReport(
        id: 1,
        userId: 3,
        reporterFullName: 'Ana Reyes',
        reporterDisplayId: 712301,
        displayReportId: 584921,
        hazardType: 'flooded_road',
        latitude: 12.6700,
        longitude: 123.8755,
        userLatitude: 12.6698, // User was 220m away (within 1km radius)
        userLongitude: 123.8753,
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
        reporterFullName: 'Juan Dela Cruz',
        reporterDisplayId: 839210,
        displayReportId: 482903,
        hazardType: 'landslide',
        latitude: 12.6710,
        longitude: 123.8770,
        userLatitude: 12.6709,
        userLongitude: 123.8769,
        description: 'Visible cracks on hillside along barangay road',
        status: HazardStatus.pending,
        naiveBayesScore: 0.75,
        consensusScore: 0.70,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      HazardReport(
        id: 3,
        userId: 7,
        reporterFullName: 'Pedro Gonzales',
        reporterDisplayId: 651442,
        displayReportId: 910284,
        hazardType: 'bridge_damage',
        latitude: 12.6685,
        longitude: 123.8745,
        userLatitude: 12.6684,
        userLongitude: 123.8744,
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
        reporterFullName: 'Rosa Martinez',
        reporterDisplayId: 447892,
        displayReportId: 302156,
        hazardType: 'road_damage',
        latitude: 12.6695,
        longitude: 123.8760,
        userLatitude: 12.6694,
        userLongitude: 123.8759,
        description: 'Major pothole causing traffic issues',
        status: HazardStatus.approved,
        naiveBayesScore: 0.68,
        consensusScore: 0.65,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      HazardReport(
        id: 5,
        userId: 6,
        reporterFullName: 'Luis Fernandez',
        reporterDisplayId: 928301,
        displayReportId: 775004,
        hazardType: 'fallen_electric_post',
        latitude: 12.6720,
        longitude: 123.8765,
        userLatitude: 12.6719,
        userLongitude: 123.8764,
        description: 'Electric post fell down, live wires on the road',
        status: HazardStatus.rejected,
        naiveBayesScore: 0.45,
        consensusScore: 0.40,
        adminComment: 'Duplicate report, already documented',
        rejectedAt: DateTime.now().subtract(const Duration(days: 2)),
        deletionScheduledAt: DateTime.now().add(const Duration(days: 13)), // 13 days remaining
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      HazardReport(
        id: 6,
        userId: 8,
        reporterFullName: 'Carmen Villanueva',
        reporterDisplayId: 563891,
        displayReportId: 128447,
        hazardType: 'fallen_tree',
        latitude: 12.6675,
        longitude: 123.8750,
        userLatitude: 12.6674,
        userLongitude: 123.8749,
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
        reporterFullName: 'Miguel Torres',
        reporterDisplayId: 384920,
        displayReportId: 661239,
        hazardType: 'road_blocked',
        latitude: 12.6690,
        longitude: 123.8760,
        userLatitude: 12.6689,
        userLongitude: 123.8759,
        description: 'Road completely blocked by debris and fallen structures',
        status: HazardStatus.pending,
        naiveBayesScore: 0.80,
        consensusScore: 0.76,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      HazardReport(
        id: 8,
        userId: 10,
        reporterFullName: 'Elena Bautista',
        reporterDisplayId: 290184,
        displayReportId: 493821,
        hazardType: 'storm_surge',
        latitude: 12.6665,
        longitude: 123.8735,
        userLatitude: 12.6664,
        userLongitude: 123.8734,
        description: 'Storm surge reaching coastal road, high waves observed',
        videoUrl: 'https://example.com/video2.mp4',
        status: HazardStatus.approved,
        naiveBayesScore: 0.90,
        consensusScore: 0.85,
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
    ];

    // Apply status filter
    var filtered = reports;
    
    if (status != null && status != 'all') {
      filtered = filtered.where((r) {
        switch (status) {
          case 'pending':
            return r.status == HazardStatus.pending;
          case 'approved':
            return r.status == HazardStatus.approved;
          case 'rejected':
            return r.status == HazardStatus.rejected && !r.autoRejected; // Exclude auto-rejected
          default:
            return true;
        }
      }).toList();
    }
    
    // Apply sort (barangay sorting would require barangay field in model)
    if (sortBy == 'barangay') {
      // For now, sort by hazard type alphabetically as placeholder
      // In production, sort by actual barangay field
      filtered.sort((a, b) => a.hazardType.compareTo(b.hazardType));
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
      'total_evacuation_centers': 5,
      'non_operational_centers': 1, // Number of deactivated centers
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
          'message': 'New hazard report submitted',
          'location': 'Barangay Zone 3',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 15)),
        },
        {
          'type': 'report_approved',
          'message': 'Hazard report approved',
          'location': 'Barangay Zone 1',
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        },
        {
          'type': 'center_deactivated',
          'message': 'Evacuation center deactivated',
          'location': 'Barangay Hall Zone 1',
          'timestamp': DateTime.now().subtract(const Duration(hours: 5)),
        },
        {
          'type': 'report_submitted',
          'message': 'Road damage reported',
          'location': 'Barangay Zone 2',
          'timestamp': DateTime.now().subtract(const Duration(hours: 8)),
        },
        {
          'type': 'report_rejected',
          'message': 'Report rejected - duplicate',
          'location': 'Barangay Zone 4',
          'timestamp': DateTime.now().subtract(const Duration(days: 1)),
        },
        {
          'type': 'report_restored',
          'message': 'Rejected report restored',
          'location': 'Barangay Zone 5',
          'timestamp': DateTime.now().subtract(const Duration(days: 2)),
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
      reporterFullName: 'Ana Reyes',
      reporterDisplayId: 712301,
      displayReportId: 584921,
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
  /// MOCK: Returns updated report with rejection timestamp.
  /// REAL: POST /api/mdrrmo/reject-report/
  Future<HazardReport> rejectReport(int reportId, {String? comment}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final now = DateTime.now();
    
    return HazardReport(
      id: reportId,
      userId: 3,
      reporterFullName: 'Ana Reyes',
      reporterDisplayId: 712301,
      displayReportId: 584921,
      hazardType: 'flood',
      latitude: 12.6700,
      longitude: 123.8755,
      description: 'Severe flooding on main highway',
      status: HazardStatus.rejected,
      naiveBayesScore: 0.92,
      consensusScore: 0.88,
      adminComment: comment ?? 'Report does not meet verification criteria',
      rejectedAt: now,
      deletionScheduledAt: now.add(const Duration(days: 15)), // Schedule deletion 15 days from now
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    );
  }
  
  /// Restore a rejected hazard report.
  /// 
  /// MOCK: Returns restored report with pending status.
  /// REAL: POST /api/mdrrmo/restore-report/
  Future<HazardReport> restoreReport(int reportId, {required String reason}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    return HazardReport(
      id: reportId,
      userId: 3,
      reporterFullName: 'Ana Reyes',
      reporterDisplayId: 712301,
      displayReportId: 584921,
      hazardType: 'flood',
      latitude: 12.6700,
      longitude: 123.8755,
      description: 'Severe flooding on main highway',
      status: HazardStatus.pending, // Back to pending after restoration
      naiveBayesScore: 0.92,
      consensusScore: 0.88,
      restorationReason: reason,
      restoredAt: DateTime.now(),
      // Clear deletion schedule and rejection timestamp
      deletionScheduledAt: null,
      rejectedAt: null,
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
        isOperational: true,
        province: 'Sorsogon',
        municipality: 'Bulan',
        barangay: 'Zone 1 (Pob.)',
        street: 'Main Street',
        contactNumber: '0917-123-4517',
      ),
      EvacuationCenter(
        id: 2,
        name: 'Bulan National High School',
        latitude: 12.6720,
        longitude: 123.8770,
        description: 'School buildings converted to shelter',
        isOperational: true,
        province: 'Sorsogon',
        municipality: 'Bulan',
        barangay: 'Zone 2 (Pob.)',
        street: 'N. Roque Street',
        contactNumber: '0917-123-4527',
      ),
      EvacuationCenter(
        id: 3,
        name: 'Barangay Hall Zone 1',
        latitude: 12.6680,
        longitude: 123.8740,
        description: 'Community center for evacuation',
        isOperational: false, // Deactivated for testing
        deactivatedAt: DateTime.now().subtract(const Duration(days: 5)),
        province: 'Sorsogon',
        municipality: 'Bulan',
        barangay: 'Zone 1 (Pob.)',
        street: 'Barangay Road',
        contactNumber: '0917-123-4537',
      ),
      EvacuationCenter(
        id: 4,
        name: 'Central Elementary School',
        latitude: 12.6690,
        longitude: 123.8765,
        description: 'Elementary school with large capacity',
        isOperational: true,
        province: 'Sorsogon',
        municipality: 'Bulan',
        barangay: 'Zone 3 (Pob.)',
        street: 'Education Avenue',
        contactNumber: '0917-123-4547',
      ),
      EvacuationCenter(
        id: 5,
        name: 'City Sports Complex',
        latitude: 12.6710,
        longitude: 123.8755,
        description: 'Sports facility with covered areas',
        isOperational: true,
        province: 'Sorsogon',
        municipality: 'Bulan',
        barangay: 'Zone 4 (Pob.)',
        street: 'Sports Drive',
        contactNumber: '0917-123-4557',
      ),
    ];
  }
  
  /// Toggle evacuation center operational status
  /// 
  /// MOCK: Simulates status change
  /// REAL: PATCH /api/evacuation-centers/{id}/toggle-status/
  Future<EvacuationCenter> toggleCenterStatus(
    int centerId, 
    bool setOperational,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Mock response - in production, this would return the updated center from backend
    final centers = await getEvacuationCenters();
    final center = centers.firstWhere((c) => c.id == centerId);
    
    return center.copyWith(
      isOperational: setOperational,
      deactivatedAt: setOperational ? null : DateTime.now(),
    );
  }

  /// Add a new evacuation center.
  /// 
  /// MOCK: Returns created center with generated ID.
  /// REAL: POST /api/mdrrmo/evacuation-centers/
  Future<EvacuationCenter> addEvacuationCenter({
    required String name,
    required String province,
    required String municipality,
    required String barangay,
    required String street,
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
      description: '$street, $barangay, $municipality, $province',
      isOperational: true,
      province: province,
      municipality: municipality,
      barangay: barangay,
      street: street,
      contactNumber: contactNumber,
    );
  }

  /// Update an existing evacuation center.
  /// 
  /// MOCK: Returns updated center.
  /// REAL: PUT /api/mdrrmo/evacuation-centers/{id}/
  Future<EvacuationCenter> updateEvacuationCenter({
    required int id,
    required String name,
    required String province,
    required String municipality,
    required String barangay,
    required String street,
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
      description: '$street, $barangay, $municipality, $province',
      isOperational: true,
      province: province,
      municipality: municipality,
      barangay: barangay,
      street: street,
      contactNumber: contactNumber,
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
