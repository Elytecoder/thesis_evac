import '../../core/auth/session_storage.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../models/evacuation_center.dart';
import '../../data/mock_evacuation_centers.dart';

/// Service for evacuation center operations.
/// 
/// Features:
/// - Get all operational evacuation centers (residents)
/// - CRUD operations for evacuation centers (MDRRMO)
/// - Activate/deactivate centers (MDRRMO)
class EvacuationCenterService {
  final ApiClient _apiClient = ApiClient();

  Future<void> _ensureAuthToken() async {
    final token = await SessionStorage.readToken();
    if (token != null && token.isNotEmpty) {
      _apiClient.setAuthToken(token);
    }
  }

  /// Get all evacuation centers.
  /// 
  /// By default, returns only operational centers (for routing).
  /// Set includeInactive = true to get all centers (MDRRMO view).
  Future<List<EvacuationCenter>> getEvacuationCenters({
    bool includeInactive = false,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      final centers = getMockEvacuationCenters();
      
      if (includeInactive) {
        return centers;
      }
      
      // Filter to only operational centers
      return centers.where((c) => c.isOperational).toList();
    }

    // REAL API CALL:
    try {
      if (includeInactive) await _ensureAuthToken();
      final endpoint = includeInactive
          ? '${ApiConfig.evacuationCentersEndpoint}?include_inactive=true'
          : ApiConfig.evacuationCentersEndpoint;
      
      final response = await _apiClient.get(endpoint);
      
      final List<dynamic> centersJson = response.data;
      return centersJson
          .map((json) => EvacuationCenter.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch evacuation centers: $e');
    }
  }

  /// Get a specific evacuation center by ID (MDRRMO only).
  /// 
  /// REAL: GET /api/mdrrmo/evacuation-centers/{id}/
  Future<EvacuationCenter> getEvacuationCenter(int centerId) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      final centers = getMockEvacuationCenters();
      return centers.firstWhere(
        (c) => c.id == centerId,
        orElse: () => throw Exception('Center not found'),
      );
    }

    // REAL API CALL:
    await _ensureAuthToken();
    try {
      final response = await _apiClient.get(
        '${ApiConfig.createEvacuationCenterEndpoint}$centerId/',
      );
      
      return EvacuationCenter.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch evacuation center: $e');
    }
  }

  /// Create a new evacuation center (MDRRMO only).
  /// 
  /// REAL: POST /api/mdrrmo/evacuation-centers/
  Future<EvacuationCenter> createEvacuationCenter({
    required String name,
    required double latitude,
    required double longitude,
    required String province,
    required String municipality,
    required String barangay,
    required String street,
    required String address,
    required String contactNumber,
    String? contactPerson,
    String? description,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return EvacuationCenter(
        id: DateTime.now().millisecondsSinceEpoch,
        name: name,
        latitude: latitude,
        longitude: longitude,
        description: description?.isNotEmpty == true ? description! : address,
        province: province,
        municipality: municipality,
        barangay: barangay,
        street: street,
        contactNumber: contactNumber,
        isOperational: true,
      );
    }

    // REAL API CALL:
    await _ensureAuthToken();
    try {
      final response = await _apiClient.post(
        ApiConfig.createEvacuationCenterEndpoint,
        data: {
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
          'province': province,
          'municipality': municipality,
          'barangay': barangay,
          'street': street,
          'address': address,
          'contact_number': contactNumber,
          if (contactPerson != null) 'contact_person': contactPerson,
          if (description != null) 'description': description,
        },
      );
      
      return EvacuationCenter.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create evacuation center: $e');
    }
  }

  /// Update an evacuation center (MDRRMO only).
  /// 
  /// REAL: PUT /api/mdrrmo/evacuation-centers/{id}/update/
  Future<EvacuationCenter> updateEvacuationCenter({
    required int centerId,
    String? name,
    double? latitude,
    double? longitude,
    String? province,
    String? municipality,
    String? barangay,
    String? street,
    String? address,
    String? contactNumber,
    String? contactPerson,
    String? description,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      final centers = getMockEvacuationCenters();
      final center = centers.firstWhere((c) => c.id == centerId);
      
      return EvacuationCenter(
        id: center.id,
        name: name ?? center.name,
        latitude: latitude ?? center.latitude,
        longitude: longitude ?? center.longitude,
        province: province ?? center.province,
        municipality: municipality ?? center.municipality,
        barangay: barangay ?? center.barangay,
        street: street ?? center.street,
        contactNumber: contactNumber ?? center.contactNumber,
        description: description ?? center.description,
        isOperational: center.isOperational,
      );
    }

    // REAL API CALL:
    await _ensureAuthToken();
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (latitude != null) data['latitude'] = latitude;
      if (longitude != null) data['longitude'] = longitude;
      if (province != null) data['province'] = province;
      if (municipality != null) data['municipality'] = municipality;
      if (barangay != null) data['barangay'] = barangay;
      if (street != null) data['street'] = street;
      if (address != null) data['address'] = address;
      if (contactNumber != null) data['contact_number'] = contactNumber;
      if (contactPerson != null) data['contact_person'] = contactPerson;
      if (description != null) data['description'] = description;
      
      final response = await _apiClient.put(
        '${ApiConfig.createEvacuationCenterEndpoint}$centerId/update/',
        data: data,
      );
      
      return EvacuationCenter.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update evacuation center: $e');
    }
  }

  /// Delete an evacuation center (MDRRMO only).
  /// 
  /// REAL: DELETE /api/mdrrmo/evacuation-centers/{id}/delete/
  Future<void> deleteEvacuationCenter(int centerId) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    // REAL API CALL:
    await _ensureAuthToken();
    try {
      await _apiClient.delete(
        '${ApiConfig.createEvacuationCenterEndpoint}$centerId/delete/',
      );
    } catch (e) {
      throw Exception('Failed to delete evacuation center: $e');
    }
  }

  /// Deactivate an evacuation center (MDRRMO only).
  /// 
  /// REAL: POST /api/mdrrmo/evacuation-centers/{id}/deactivate/
  Future<EvacuationCenter> deactivateEvacuationCenter(int centerId) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      final centers = getMockEvacuationCenters();
      final center = centers.firstWhere((c) => c.id == centerId);
      
      return EvacuationCenter(
        id: center.id,
        name: center.name,
        latitude: center.latitude,
        longitude: center.longitude,
        province: center.province,
        municipality: center.municipality,
        barangay: center.barangay,
        street: center.street,
        contactNumber: center.contactNumber,
        description: center.description,
        isOperational: false,
        deactivatedAt: DateTime.now(),
      );
    }

    // REAL API CALL: POST with empty body so server accepts the request
    await _ensureAuthToken();
    try {
      final response = await _apiClient.post(
        '${ApiConfig.createEvacuationCenterEndpoint}$centerId/deactivate/',
        data: <String, dynamic>{},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid response from server when deactivating center.');
      }
      return EvacuationCenter.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      if (e is ApiException && e.statusCode == 403) {
        throw Exception(
          'You don\'t have permission to deactivate centers. Only MDRRMO users can do this. '
          'Please log in with an MDRRMO account.',
        );
      }
      throw Exception('Failed to deactivate evacuation center: $e');
    }
  }

  /// Reactivate an evacuation center (MDRRMO only).
  /// 
  /// REAL: POST /api/mdrrmo/evacuation-centers/{id}/reactivate/
  Future<EvacuationCenter> reactivateEvacuationCenter(int centerId) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      final centers = getMockEvacuationCenters();
      final center = centers.firstWhere((c) => c.id == centerId);
      
      return EvacuationCenter(
        id: center.id,
        name: center.name,
        latitude: center.latitude,
        longitude: center.longitude,
        province: center.province,
        municipality: center.municipality,
        barangay: center.barangay,
        street: center.street,
        contactNumber: center.contactNumber,
        description: center.description,
        isOperational: true,
        deactivatedAt: null,
      );
    }

    // REAL API CALL:
    await _ensureAuthToken();
    try {
      final response = await _apiClient.post(
        '${ApiConfig.createEvacuationCenterEndpoint}$centerId/reactivate/',
        data: <String, dynamic>{},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid response from server when reactivating center.');
      }
      return EvacuationCenter.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      if (e is ApiException && e.statusCode == 403) {
        throw Exception(
          'You don\'t have permission to reactivate centers. Only MDRRMO users can do this.',
        );
      }
      throw Exception('Failed to reactivate evacuation center: $e');
    }
  }
}
