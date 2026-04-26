import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../core/constants/philippine_address_data.dart';

/// Reverse Geocoding Service
///
/// Converts GPS coordinates to structured address components using the
/// Nominatim OpenStreetMap API, then validates / normalises the result
/// against the canonical [PhilippineAddressData] dropdown lists.
///
/// Key behaviours:
/// - Municipality matching uses fuzzy comparison so "Sorsogon City" is never
///   accidentally stripped to "Sorsogon".
/// - Barangay matching strips "Barangay" / "Brgy." prefixes and falls back
///   to partial matching, then null if still not found.
/// - If the API call fails, province defaults to "Sorsogon" and municipality
///   defaults to "Bulan" so the admin can still save with manual selection.
class ReverseGeocodingService {
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

  /// Reverse geocode [location] to structured address components.
  ///
  /// Returns a map with string keys:
  ///   province     — matched to [PhilippineAddressData.provinces] or "Sorsogon"
  ///   municipality — matched to dropdown label, or empty string
  ///   barangay     — matched to dropdown label, or empty string
  ///   street       — raw road/highway string from Nominatim
  ///
  /// Returns null only when the HTTP call itself fails.
  Future<Map<String, String>?> reverseGeocode(LatLng location) async {
    try {
      final url = Uri.parse(
        '$_nominatimBaseUrl/reverse?'
        'lat=${location.latitude}&'
        'lon=${location.longitude}&'
        'format=json&'
        'addressdetails=1&'
        'zoom=18',
      );

      final response = await http
          .get(url, headers: {
            'User-Agent': 'HAZNAV Mobile App',
            'Accept': 'application/json',
          })
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Reverse geocoding timed out'),
          );

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['error'] != null) return null;

      final address = data['address'] as Map<String, dynamic>?;
      if (address == null) return null;

      final result = <String, String>{};
      result['province'] = _extractProvince(address);
      result['municipality'] = _extractMunicipality(address);
      result['barangay'] = _extractBarangay(address, result['municipality']!);
      result['street'] = _extractStreet(address);

      return result;
    } catch (_) {
      return null;
    }
  }

  // ── Private extractors ──────────────────────────────────────────────────

  String _extractProvince(Map<String, dynamic> address) {
    // Nominatim uses "state" for Philippine provinces
    final raw = (address['state'] as String? ??
            address['province'] as String? ??
            'Sorsogon')
        .trim();

    // Accept it if it loosely contains "Sorsogon"
    if (raw.toLowerCase().contains('sorsogon')) return 'Sorsogon';
    return 'Sorsogon'; // default — system is focused on Sorsogon
  }

  String _extractMunicipality(Map<String, dynamic> address) {
    // Nominatim may return city, municipality, town, or village.
    // IMPORTANT: do NOT strip " City" — "Sorsogon City" is the correct
    // dropdown label and stripping it would make matching fail.
    final raw = (address['city'] as String? ??
            address['municipality'] as String? ??
            address['town'] as String? ??
            address['village'] as String? ??
            '')
        .trim();

    if (raw.isEmpty) return '';

    // Remove "Municipality of " prefix that some Nominatim entries carry
    final cleaned = raw.replaceAll('Municipality of ', '').trim();

    // Fuzzy-match against the official dropdown list
    final matched = PhilippineAddressData.fuzzyMatchMunicipality(cleaned);
    return matched ?? cleaned; // return cleaned raw if no canonical match
  }

  /// Extract barangay and immediately validate it against the municipality list.
  String _extractBarangay(Map<String, dynamic> address, String municipality) {
    final raw = (address['suburb'] as String? ??
            address['neighbourhood'] as String? ??
            address['village'] as String? ??
            address['hamlet'] as String? ??
            '')
        .trim();

    if (raw.isEmpty) return '';

    final matched = PhilippineAddressData.fuzzyMatchBarangay(raw, municipality);
    return matched ?? ''; // leave blank if not in the dropdown list
  }

  String _extractStreet(Map<String, dynamic> address) {
    return (address['road'] as String? ??
            address['street'] as String? ??
            address['highway'] as String? ??
            '')
        .trim();
  }

  // ── Utility checks ──────────────────────────────────────────────────────

  bool isInPhilippines(LatLng location) =>
      location.latitude >= 4.0 &&
      location.latitude <= 21.0 &&
      location.longitude >= 116.0 &&
      location.longitude <= 127.0;

  bool isInSorsogon(LatLng location) =>
      location.latitude >= 12.4 &&
      location.latitude <= 13.2 &&
      location.longitude >= 123.4 &&
      location.longitude <= 124.2;
}
