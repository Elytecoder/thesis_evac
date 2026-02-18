import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/storage_service.dart';
import '../../models/hazard_report.dart';
import '../../models/baseline_hazard.dart';
import '../../data/mock_hazards.dart';

/// Service for hazard-related operations.
/// 
/// FEATURES:
/// - Submit hazard reports (online)
/// - Queue reports for submission when offline
/// - Cache baseline hazards for offline use
/// - Sync pending reports when back online
class HazardService {
  final ApiClient _apiClient = ApiClient();
  final StorageService _storageService = StorageService();

  /// Submit a hazard report.
  /// 
  /// FEATURES:
  /// - Submits immediately if online
  /// - Queues for later if offline
  /// - Returns optimistic response for offline submissions
  Future<HazardReport> submitHazardReport({
    required String hazardType,
    required double latitude,
    required double longitude,
    required String description,
    String? photoUrl,
    String? videoUrl,
  }) async {
    if (ApiConfig.useMockData) {
      // Try to submit immediately
      try {
        await Future.delayed(const Duration(seconds: 1));
        
        final report = HazardReport(
          id: DateTime.now().millisecondsSinceEpoch,
          userId: 1,
          hazardType: hazardType,
          latitude: latitude,
          longitude: longitude,
          description: description,
          photoUrl: photoUrl,
          videoUrl: videoUrl,
          status: HazardStatus.pending,
          naiveBayesScore: 0.85,
          consensusScore: 0.78,
          createdAt: DateTime.now(),
        );

        print('Hazard report submitted successfully');
        return report;
      } catch (e) {
        // Offline - queue for later
        print('Offline: Queuing hazard report for later submission');
        return await _queueHazardReport(
          hazardType: hazardType,
          latitude: latitude,
          longitude: longitude,
          description: description,
          photoUrl: photoUrl,
          videoUrl: videoUrl,
        );
      }
    }

    // REAL API CALL:
    try {
      final response = await _apiClient.post(
        ApiConfig.reportHazardEndpoint,
        data: {
          'hazard_type': hazardType,
          'latitude': latitude,
          'longitude': longitude,
          'description': description,
          if (photoUrl != null) 'photo_url': photoUrl,
          if (videoUrl != null) 'video_url': videoUrl,
        },
      );

      return HazardReport.fromJson(response.data);
    } catch (e) {
      // Offline - queue for later
      print('Offline: Queuing hazard report for later submission');
      return await _queueHazardReport(
        hazardType: hazardType,
        latitude: latitude,
        longitude: longitude,
        description: description,
        photoUrl: photoUrl,
        videoUrl: videoUrl,
      );
    }
  }

  /// Queue a hazard report for later submission (offline mode)
  Future<HazardReport> _queueHazardReport({
    required String hazardType,
    required double latitude,
    required double longitude,
    required String description,
    String? photoUrl,
    String? videoUrl,
  }) async {
    final report = HazardReport(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: 1,
      hazardType: hazardType,
      latitude: latitude,
      longitude: longitude,
      description: description,
      photoUrl: photoUrl,
      videoUrl: videoUrl,
      status: HazardStatus.pending,
      naiveBayesScore: 0.0, // Will be calculated when synced
      consensusScore: 0.0,
      createdAt: DateTime.now(),
    );

    // Save to queue
    final queuedReports = await _getQueuedReports();
    queuedReports.add(report.toJson());
    
    await _storageService.saveBaselineHazards(queuedReports);
    
    print('Report queued: ${queuedReports.length} reports pending sync');
    return report;
  }

  /// Get queued reports
  Future<List<Map<String, dynamic>>> _getQueuedReports() async {
    try {
      final reports = await _storageService.getBaselineHazards();
      return reports ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Sync queued reports (call when back online)
  Future<void> syncQueuedReports() async {
    final queuedReports = await _getQueuedReports();
    
    if (queuedReports.isEmpty) {
      print('No queued reports to sync');
      return;
    }

    print('Syncing ${queuedReports.length} queued reports...');
    
    for (var reportJson in queuedReports) {
      try {
        await _apiClient.post(
          ApiConfig.reportHazardEndpoint,
          data: reportJson,
        );
        print('Synced report: ${reportJson['id']}');
      } catch (e) {
        print('Failed to sync report ${reportJson['id']}: $e');
      }
    }

    // Clear queue after sync
    await _storageService.clearAllCache();
    print('Queue cleared after sync');
  }

  /// Get baseline hazards (MDRRMO data) for caching.
  /// 
  /// MOCK: Returns mock baseline hazards.
  /// REAL: GET from /api/bootstrap-sync/
  Future<List<BaselineHazard>> getBaselineHazards() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return getMockBaselineHazards();
    }

    // REAL API CALL:
    try {
      final response = await _apiClient.get(ApiConfig.bootstrapSyncEndpoint);
      
      final List<dynamic> hazardsJson = response.data['baseline_hazards'];
      return hazardsJson
          .map((json) => BaselineHazard.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch baseline hazards: $e');
    }
  }

  /// Get pending hazard reports (MDRRMO only).
  /// 
  /// MOCK: Returns empty list (no pending reports in mock).
  /// REAL: GET from /api/mdrrmo/pending-reports/
  Future<List<HazardReport>> getPendingReports() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Return some mock pending reports
      return [
        HazardReport(
          id: 1,
          userId: 3,
          hazardType: 'flood',
          latitude: 12.6700,
          longitude: 123.8755,
          description: 'Heavy flooding reported near main road',
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
          description: 'Visible cracks on hillside',
          status: HazardStatus.pending,
          naiveBayesScore: 0.75,
          consensusScore: 0.70,
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
      ];
    }

    // REAL API CALL:
    try {
      final response = await _apiClient.get(ApiConfig.pendingReportsEndpoint);
      
      final List<dynamic> reportsJson = response.data;
      return reportsJson
          .map((json) => HazardReport.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch pending reports: $e');
    }
  }

  /// Approve or reject a hazard report (MDRRMO only).
  /// 
  /// MOCK: Returns the updated report.
  /// REAL: POST to /api/mdrrmo/approve-report/
  Future<HazardReport> approveOrRejectReport({
    required int reportId,
    required bool approve,
    String? comment,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Return mock updated report
      return HazardReport(
        id: reportId,
        userId: 3,
        hazardType: 'flood',
        latitude: 12.6700,
        longitude: 123.8755,
        description: 'Heavy flooding reported near main road',
        status: approve ? HazardStatus.approved : HazardStatus.rejected,
        naiveBayesScore: 0.92,
        consensusScore: 0.88,
        adminComment: comment,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
    }

    // REAL API CALL:
    try {
      final response = await _apiClient.post(
        ApiConfig.approveReportEndpoint,
        data: {
          'report_id': reportId,
          'action': approve ? 'approve' : 'reject',
          if (comment != null) 'comment': comment,
        },
      );

      return HazardReport.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update report: $e');
    }
  }
}
