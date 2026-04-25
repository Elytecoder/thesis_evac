import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Reverse Geocoding Service
/// 
/// Converts GPS coordinates to structured address components
/// Uses Nominatim OpenStreetMap API for reverse geocoding
class ReverseGeocodingService {
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  
  /// Reverse geocode coordinates to get address components
  /// 
  /// Returns a map with keys: province, municipality, barangay, street
  /// Returns null if geocoding fails
  Future<Map<String, String>?> reverseGeocode(LatLng location) async {
    try {
      final url = Uri.parse(
        '$_nominatimBaseUrl/reverse?'
        'lat=${location.latitude}&'
        'lon=${location.longitude}&'
        'format=json&'
        'addressdetails=1&'
        'zoom=18'
      );
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'HAZNAV Mobile App',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Reverse geocoding request timed out');
        },
      );
      
      if (response.statusCode != 200) {
        print('❌ Reverse geocoding failed with status ${response.statusCode}');
        return null;
      }
      
      final data = json.decode(response.body);
      
      if (data['error'] != null) {
        print('❌ Reverse geocoding error: ${data['error']}');
        return null;
      }
      
      final address = data['address'] as Map<String, dynamic>?;
      if (address == null) {
        print('❌ No address data returned');
        return null;
      }
      
      // Extract address components
      // Nominatim returns various field names depending on location
      final result = <String, String>{};
      
      // Province (state, province, region)
      result['province'] = _extractProvince(address);
      
      // Municipality (city, municipality, town, village)
      result['municipality'] = _extractMunicipality(address);
      
      // Barangay (suburb, neighbourhood, village, hamlet)
      result['barangay'] = _extractBarangay(address);
      
      // Street (road, street, highway)
      result['street'] = _extractStreet(address);
      
      print('✅ Reverse geocoding successful: $result');
      return result;
      
    } catch (e) {
      print('❌ Reverse geocoding exception: $e');
      return null;
    }
  }
  
  /// Extract province from address data
  String _extractProvince(Map<String, dynamic> address) {
    // Try multiple field names
    return address['state'] as String? ??
           address['province'] as String? ??
           address['region'] as String? ??
           'Sorsogon'; // Default for Bulan area
  }
  
  /// Extract municipality from address data
  String _extractMunicipality(Map<String, dynamic> address) {
    // Prioritize city/municipality fields
    final city = address['city'] as String? ??
                 address['municipality'] as String? ??
                 address['town'] as String? ??
                 address['village'] as String?;
    
    // Clean up common suffixes
    if (city != null) {
      return city.replaceAll(' City', '')
                .replaceAll(' Municipality', '')
                .trim();
    }
    
    return 'Bulan'; // Default
  }
  
  /// Extract barangay from address data
  String _extractBarangay(Map<String, dynamic> address) {
    // Barangays are typically in suburb, neighbourhood, or village fields
    final barangay = address['suburb'] as String? ??
                     address['neighbourhood'] as String? ??
                     address['village'] as String? ??
                     address['hamlet'] as String?;
    
    if (barangay != null) {
      // Clean up "Barangay" prefix if present
      return barangay.replaceAll('Barangay ', '')
                    .replaceAll('Brgy. ', '')
                    .replaceAll('Brgy ', '')
                    .trim();
    }
    
    return ''; // Leave empty if not found
  }
  
  /// Extract street from address data
  String _extractStreet(Map<String, dynamic> address) {
    return address['road'] as String? ??
           address['street'] as String? ??
           address['highway'] as String? ??
           '';
  }
  
  /// Check if coordinates are within Philippines bounds
  bool isInPhilippines(LatLng location) {
    return location.latitude >= 4.0 && 
           location.latitude <= 21.0 &&
           location.longitude >= 116.0 && 
           location.longitude <= 127.0;
  }
  
  /// Check if coordinates are within Sorsogon province bounds
  bool isInSorsogon(LatLng location) {
    return location.latitude >= 12.4 && 
           location.latitude <= 13.2 &&
           location.longitude >= 123.4 && 
           location.longitude <= 124.2;
  }
}
