import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../../core/auth/session_storage.dart';
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

  Future<void> _ensureAuthToken() async {
    final token = await SessionStorage.readToken();
    if (token != null && token.isNotEmpty) {
      _apiClient.setAuthToken(token);
    }
  }

  /// Extract list from API response (handles raw list or wrapped in 'results'/'data').
  static List<dynamic> _extractList(dynamic raw) {
    if (raw is List) return List<dynamic>.from(raw);
    if (raw is Map) {
      if (raw['results'] is List) return List<dynamic>.from(raw['results'] as List);
      if (raw['data'] is List) return List<dynamic>.from(raw['data'] as List);
    }
    return [];
  }

  /// Parse one JSON map to HazardReport, return null on error.
  static HazardReport? _tryParseReport(dynamic json) {
    try {
      if (json is! Map) return null;
      return HazardReport.fromJson(Map<String, dynamic>.from(json));
    } catch (_) {
      return null;
    }
  }

  /// Submit a hazard report.
  /// 
  /// FEATURES:
  /// - Submits immediately if online
  /// - Queues for later if offline
  /// - Returns optimistic response for offline submissions
  /// - Captures user's location for proximity validation
  Future<HazardReport> submitHazardReport({
    required String hazardType,
    required double latitude,
    required double longitude,
    required String description,
    double? userLatitude,
    double? userLongitude,
    String? photoUrl,
    String? videoUrl,
    Uint8List? photoBytes,
    String? photoFilename,
    Uint8List? videoBytes,
    String? videoFilename,
  }) async {
    final resolvedPhotoUrl = photoUrl ??
        (photoBytes != null
            ? 'data:image/jpeg;base64,${base64Encode(photoBytes)}'
            : null);

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
          photoUrl: resolvedPhotoUrl ??
              (photoBytes != null ? 'https://example.com/uploads/hazard.jpg' : null),
          videoUrl: videoUrl ??
              (videoBytes != null ? 'https://example.com/uploads/hazard.mp4' : null),
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
          photoUrl: resolvedPhotoUrl,
          videoUrl: videoUrl,
        );
      }
    }

    // REAL API CALL:
    await _ensureAuthToken();
    final useMultipart = photoBytes != null || videoBytes != null;

    try {
      final Response response;
      if (useMultipart) {
        final form = FormData.fromMap({
          'hazard_type': hazardType,
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'description': description,
          if (userLatitude != null) 'user_latitude': userLatitude.toString(),
          if (userLongitude != null) 'user_longitude': userLongitude.toString(),
          if (photoBytes != null)
            'photo': MultipartFile.fromBytes(
              photoBytes,
              filename: photoFilename ?? 'hazard.jpg',
            ),
          if (videoBytes != null)
            'video': MultipartFile.fromBytes(
              videoBytes,
              filename: videoFilename ?? 'hazard.mp4',
            ),
        });
        response = await _apiClient.postFormData(
          ApiConfig.reportHazardEndpoint,
          form,
        );
      } else {
        response = await _apiClient.post(
          ApiConfig.reportHazardEndpoint,
          data: {
            'hazard_type': hazardType,
            'latitude': latitude,
            'longitude': longitude,
            'description': description,
            if (userLatitude != null) 'user_latitude': userLatitude,
            if (userLongitude != null) 'user_longitude': userLongitude,
            if (photoUrl != null && photoUrl.isNotEmpty) 'photo_url': photoUrl,
            if (videoUrl != null && videoUrl.isNotEmpty) 'video_url': videoUrl,
          },
        );
      }

      final data = response.data;
      if (data is! Map) throw Exception('Invalid report response');
      return HazardReport.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      // Auth failures: do NOT queue — report never reached the server. User must log in.
      if (e is ApiException) {
        if (e.statusCode == 401) {
          throw Exception('Please log in to submit a report. Your session may have expired.');
        }
        if (e.statusCode == 403) {
          throw Exception('You do not have permission to submit reports. Please log in as a resident.');
        }
        // Show server or client error message; do not queue on 4xx/5xx
        if (e.statusCode != null && e.statusCode! >= 400) {
          throw Exception(e.message);
        }
      }
      // Location/proximity message
      if (e.toString().contains('location does not match') ||
          e.toString().contains('outside') ||
          e.toString().contains('radius')) {
        throw Exception('You must be within 150 meters of the hazard location to submit a report.');
      }
      // Only queue on real network/connection errors
      print('Offline: Queuing hazard report for later submission');
      return await _queueHazardReport(
        hazardType: hazardType,
        latitude: latitude,
        longitude: longitude,
        description: description,
        photoUrl: resolvedPhotoUrl,
        videoUrl: videoUrl,
      );
    }
  }

  /// Check for similar pending reports near a location.
  /// 
  /// Used to prompt user to confirm existing report instead of creating duplicate.
  /// 
  /// Returns: List of similar reports with distance and confirmation count.
  Future<List<Map<String, dynamic>>> checkSimilarReports({
    required String hazardType,
    required double latitude,
    required double longitude,
    double radiusMeters = 100.0,
  }) async {
    if (ApiConfig.useMockData) {
      // Mock: return empty list (no similar reports)
      await Future.delayed(const Duration(milliseconds: 300));
      return [];
    }

    try {
      await _ensureAuthToken();

      final response = await _apiClient.post(
        ApiConfig.checkSimilarReportsEndpoint,
        data: {
          'hazard_type': hazardType,
          'latitude': latitude,
          'longitude': longitude,
          'radius_meters': radiusMeters,
        },
      );

      final responseData = response.data as Map<String, dynamic>;
      final similarReports = responseData['similar_reports'] as List<dynamic>?;
      if (similarReports == null || similarReports.isEmpty) {
        return [];
      }

      return similarReports.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      print('Error checking similar reports: $e');
      // Return empty list on error (proceed with normal submission)
      return [];
    }
  }

  /// Confirm an existing hazard report instead of submitting a duplicate.
  /// 
  /// Adds user to confirmation list and recalculates validation scores.
  /// 
  /// Returns: Updated report with new confirmation count.
  Future<HazardReport> confirmHazardReport(int reportId) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      throw Exception('Mock mode: confirmation not available');
    }

    try {
      await _ensureAuthToken();

      final response = await _apiClient.post(
        ApiConfig.confirmHazardReportEndpoint,
        data: {'report_id': reportId},
      );

      final responseData = response.data as Map<String, dynamic>;
      
      // Parse report from response
      final report = HazardReport.fromJson(responseData);
      
      print('Hazard confirmed: Report #$reportId (${responseData['confirmation_count']} confirmations)');
      return report;
    } catch (e) {
      print('Error confirming hazard report: $e');
      rethrow;
    }
  }

  /// Queue a hazard report for later submission (offline mode).
  /// Saved to the dedicated [StorageConfig.pendingReportsBox] — does NOT
  /// touch the verified-hazards or evacuation-centers caches.
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
      naiveBayesScore: 0.0,
      consensusScore: 0.0,
      createdAt: DateTime.now(),
    );

    final queue = await _storageService.getPendingReports();
    queue.add(report.toJson());
    await _storageService.savePendingReports(queue);

    print('Report queued offline: ${queue.length} report(s) pending sync');
    return report;
  }

  /// Get all offline-queued reports.
  Future<List<Map<String, dynamic>>> _getQueuedReports() async {
    return _storageService.getPendingReports();
  }

  /// Sync queued reports when back online.
  /// Only clears the pending queue — never touches other caches.
  Future<void> syncQueuedReports() async {
    final queuedReports = await _getQueuedReports();

    if (queuedReports.isEmpty) {
      print('No queued reports to sync');
      return;
    }

    print('Syncing ${queuedReports.length} queued report(s)...');
    await _ensureAuthToken();

    final List<Map<String, dynamic>> failed = [];

    for (final reportJson in queuedReports) {
      try {
        await _apiClient.post(
          ApiConfig.reportHazardEndpoint,
          data: reportJson,
        );
        print('Synced queued report id=${reportJson['id']}');
      } catch (e) {
        print('Failed to sync report id=${reportJson['id']}: $e');
        failed.add(reportJson);
      }
    }

    // Persist only the reports that failed (retry on next sync cycle).
    if (failed.isEmpty) {
      await _storageService.clearPendingReports();
      print('All queued reports synced — queue cleared');
    } else {
      await _storageService.savePendingReports(failed);
      print('${failed.length} report(s) remain in queue after partial sync');
    }
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
          reporterFullName: 'Maria Santos',
          reporterDisplayId: 739201,
          displayReportId: 482911,
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
          reporterFullName: 'Juan Dela Cruz',
          reporterDisplayId: 839205,
          displayReportId: 482912,
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
    await _ensureAuthToken();
    try {
      final response = await _apiClient.get(ApiConfig.pendingReportsEndpoint);
      final list = _extractList(response.data);
      return list.map((json) => _tryParseReport(json)).whereType<HazardReport>().toList();
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
        reporterFullName: 'Maria Santos',
        reporterDisplayId: 739201,
        displayReportId: 482911,
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
    await _ensureAuthToken();
    try {
      final response = await _apiClient.post(
        ApiConfig.approveReportEndpoint,
        data: {
          'report_id': reportId,
          'action': approve ? 'approve' : 'reject',
          if (comment != null) 'admin_comment': comment,
        },
      );

      return HazardReport.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update report: $e');
    }
  }

  /// Get user's own reports.
  /// Falls back to an empty list (not a crash) when offline.
  ///
  /// REAL: GET from /api/my-reports/
  Future<List<HazardReport>> getMyReports() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return [];
    }

    await _ensureAuthToken();
    try {
      final response = await _apiClient.get(ApiConfig.myReportsEndpoint);
      final list = _extractList(response.data);
      return list.map((json) => _tryParseReport(json)).whereType<HazardReport>().toList();
    } catch (e) {
      // Return empty list when offline instead of throwing.
      return [];
    }
  }

  /// Delete user's own pending report.
  /// 
  /// REAL: DELETE /api/my-reports/{id}/
  Future<void> deleteMyReport(int reportId) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      print('Mock: Deleted report $reportId');
      return;
    }

    // REAL API CALL:
    await _ensureAuthToken();
    try {
      await _apiClient.delete(
        ApiConfig.getUrlWithId(ApiConfig.myReportsEndpoint, reportId),
      );
    } catch (e) {
      throw Exception('Failed to delete report: $e');
    }
  }

  /// Get all verified (approved) hazards for map display.
  /// Caches result to Hive on success; falls back to Hive cache when offline.
  ///
  /// REAL: GET from /api/verified-hazards/
  Future<List<HazardReport>> getVerifiedHazards() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return [];
    }

    try {
      final response = await _apiClient.get(ApiConfig.verifiedHazardsEndpoint);
      final list = _extractList(response.data);
      final hazards = list
          .map((json) => _tryParseReport(json))
          .whereType<HazardReport>()
          .toList();

      // Cache for offline use
      await _storageService.saveVerifiedHazards(
        hazards.map((h) => h.toJson()).toList(),
      );
      return hazards;
    } catch (e) {
      // Fallback to Hive cache when offline or server error
      final cached = await _storageService.getCachedVerifiedHazards();
      if (cached != null && cached.isNotEmpty) {
        print('Offline: returning ${cached.length} cached verified hazard(s)');
        return cached
            .map((json) => _tryParseReport(json))
            .whereType<HazardReport>()
            .toList();
      }
      // Empty list — do not crash the app when no data is available
      return [];
    }
  }

  /// Get rejected reports (MDRRMO only).
  /// 
  /// REAL: GET from /api/mdrrmo/rejected-reports/
  Future<List<HazardReport>> getRejectedReports() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return [];
    }

    // REAL API CALL:
    await _ensureAuthToken();
    try {
      final response = await _apiClient.get(ApiConfig.rejectedReportsEndpoint);
      final list = _extractList(response.data);
      return list.map((json) => _tryParseReport(json)).whereType<HazardReport>().toList();
    } catch (e) {
      throw Exception('Failed to fetch rejected reports: $e');
    }
  }

  /// Delete an approved or rejected report (MDRRMO only). Removes from system.
  /// 
  /// REAL: DELETE /api/mdrrmo/reports/{id}/
  Future<void> deleteReportMdrrmo(int reportId) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }
    await _ensureAuthToken();
    await _apiClient.delete('${ApiConfig.mdrrmoDeleteReportEndpoint}$reportId/');
  }

  /// Restore a rejected report (MDRRMO only).
  /// 
  /// REAL: POST to /api/mdrrmo/restore-report/
  Future<HazardReport> restoreReport({
    required int reportId,
    required String restorationReason,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return HazardReport(
        id: reportId,
        userId: 3,
        reporterFullName: 'Maria Santos',
        reporterDisplayId: 739201,
        displayReportId: 482911,
        hazardType: 'flood',
        latitude: 12.6700,
        longitude: 123.8755,
        description: 'Restored report',
        status: HazardStatus.pending,
        naiveBayesScore: 0.92,
        consensusScore: 0.88,
        createdAt: DateTime.now(),
      );
    }

    // REAL API CALL:
    await _ensureAuthToken();
    try {
      final response = await _apiClient.post(
        ApiConfig.restoreReportEndpoint,
        data: {
          'report_id': reportId,
          'restoration_reason': restorationReason,
        },
      );

      return HazardReport.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to restore report: $e');
    }
  }
}
