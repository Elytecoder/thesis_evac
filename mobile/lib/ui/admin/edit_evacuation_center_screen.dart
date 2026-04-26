import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../../features/evacuation/evacuation_center_service.dart';
import '../../features/admin/reverse_geocoding_service.dart';
import '../../core/constants/philippine_address_data.dart';
import '../../models/evacuation_center.dart';
import '../../utils/input_validators.dart';
import '../../utils/input_formatters.dart';
import 'map_location_picker_screen.dart';

/// Edit Evacuation Center Screen - Edit existing center with structured address
class EditEvacuationCenterScreen extends StatefulWidget {
  final EvacuationCenter center;

  const EditEvacuationCenterScreen({
    super.key,
    required this.center,
  });

  @override
  State<EditEvacuationCenterScreen> createState() => _EditEvacuationCenterScreenState();
}

class _EditEvacuationCenterScreenState extends State<EditEvacuationCenterScreen> {
  final _formKey = GlobalKey<FormState>();
  final EvacuationCenterService _evacuationCenterService = EvacuationCenterService();
  final ReverseGeocodingService _geocodingService = ReverseGeocodingService();
  
  late TextEditingController _nameController;
  late TextEditingController _streetController;
  late TextEditingController _contactController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  
  // Cascading dropdown values
  String? _selectedProvince;
  String? _selectedMunicipality;
  String? _selectedBarangay;
  
  bool _isSaving = false;
  bool _isReverseGeocoding = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate with existing center data
    _nameController = TextEditingController(text: widget.center.name);
    _streetController = TextEditingController(text: widget.center.street ?? '');
    _contactController = TextEditingController(text: widget.center.contactNumber ?? '0917-123-45${widget.center.id}7');
    _latitudeController = TextEditingController(text: widget.center.latitude.toString());
    _longitudeController = TextEditingController(text: widget.center.longitude.toString());
    
    // Pre-populate dropdowns with values that exist in options (avoid DropdownButton assertion)
    final province = widget.center.province ?? 'Sorsogon';
    _selectedProvince = PhilippineAddressData.provinces.contains(province)
        ? province
        : PhilippineAddressData.provinces.isNotEmpty
            ? PhilippineAddressData.provinces.first
            : null;
    final municipalities = _selectedProvince != null
        ? PhilippineAddressData.getMunicipalities(_selectedProvince!)
        : <String>[];
    final municipality = widget.center.municipality ?? 'Bulan';
    _selectedMunicipality = municipalities.contains(municipality)
        ? municipality
        : municipalities.isNotEmpty
            ? municipalities.first
            : null;
    final barangays = _selectedMunicipality != null
        ? PhilippineAddressData.getBarangays(_selectedMunicipality!)
        : <String>[];
    final barangay = widget.center.barangay ?? 'Zone 1 (Pob.)';
    _selectedBarangay = barangays.contains(barangay)
        ? barangay
        : barangays.isNotEmpty
            ? barangays.first
            : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _contactController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  /// Open map picker and perform reverse geocoding
  Future<void> _openMapPicker() async {
    // Get current coordinates
    LatLng? initialLocation;
    final latText = _latitudeController.text.trim();
    final lngText = _longitudeController.text.trim();
    if (latText.isNotEmpty && lngText.isNotEmpty) {
      final lat = double.tryParse(latText);
      final lng = double.tryParse(lngText);
      if (lat != null && lng != null) {
        initialLocation = LatLng(lat, lng);
      }
    }

    // Open map picker
    final LatLng? selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPickerScreen(
          initialLocation: initialLocation,
        ),
      ),
    );

    // Update coordinates and perform reverse geocoding to auto-fill province, municipality, barangay
    if (selectedLocation != null && mounted) {
      setState(() {
        _latitudeController.text = selectedLocation.latitude.toStringAsFixed(6);
        _longitudeController.text = selectedLocation.longitude.toStringAsFixed(6);
        _isReverseGeocoding = true;
      });

      try {
        final addressComponents = await _geocodingService.reverseGeocode(selectedLocation);

        if (addressComponents != null && addressComponents.isNotEmpty && mounted) {
          // Province always defaults to Sorsogon for this system.
          const String validProvince = 'Sorsogon';

          // Municipality: geocoder already fuzzy-matched; fall back to 'Bulan'.
          final rawMuni =
              (addressComponents['municipality'] ?? '').toString().trim();
          final String validMunicipality = rawMuni.isNotEmpty &&
                  PhilippineAddressData.getMunicipalities(validProvince)
                      .contains(rawMuni)
              ? rawMuni
              : (PhilippineAddressData.fuzzyMatchMunicipality(rawMuni) ??
                  'Bulan');

          // Barangay: keep null when blank so admin is prompted to choose.
          final rawBrgy =
              (addressComponents['barangay'] ?? '').toString().trim();
          final String? validBarangay = rawBrgy.isNotEmpty ? rawBrgy : null;

          final street = addressComponents['street']?.toString().trim() ?? '';

          setState(() {
            _selectedProvince = validProvince;
            _selectedMunicipality = validMunicipality;
            _selectedBarangay = validBarangay;
            if (street.isNotEmpty) _streetController.text = street;
            _isReverseGeocoding = false;
          });

          if (mounted) {
            final message = validBarangay == null
                ? 'Location updated. Province and municipality filled from map; please select Barangay.'
                : 'Location and address (Province, Municipality, Barangay) filled from map.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: validBarangay == null ? Colors.orange : Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          // No address from API: still fill province/municipality defaults so user only picks barangay
          setState(() {
            _selectedProvince = PhilippineAddressData.provinces.contains('Sorsogon')
                ? 'Sorsogon'
                : (PhilippineAddressData.provinces.isNotEmpty ? PhilippineAddressData.provinces.first : null);
            _selectedMunicipality = _selectedProvince != null
                ? (PhilippineAddressData.getMunicipalities(_selectedProvince!).contains('Bulan')
                    ? 'Bulan'
                    : (PhilippineAddressData.getMunicipalities(_selectedProvince!).isNotEmpty
                        ? PhilippineAddressData.getMunicipalities(_selectedProvince!).first
                        : null))
                : null;
            _selectedBarangay = null;
            _isReverseGeocoding = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location updated. Address could not be detected from map—please select Province, Municipality, and Barangay.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      } catch (e) {
        setState(() {
          _selectedProvince = PhilippineAddressData.provinces.isNotEmpty ? PhilippineAddressData.provinces.first : null;
          _selectedMunicipality = _selectedProvince != null && PhilippineAddressData.getMunicipalities(_selectedProvince!).isNotEmpty
              ? PhilippineAddressData.getMunicipalities(_selectedProvince!).first
              : null;
          _selectedBarangay = null;
          _isReverseGeocoding = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location updated. Address could not be fetched—please select Province, Municipality, and Barangay.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  /// Resolve effective dropdown value (selection or first option) to avoid null on save.
  String? _effectiveProvince() {
    if (_selectedProvince != null && PhilippineAddressData.provinces.contains(_selectedProvince)) {
      return _selectedProvince;
    }
    return PhilippineAddressData.provinces.isNotEmpty ? PhilippineAddressData.provinces.first : null;
  }

  String? _effectiveMunicipality() {
    final province = _effectiveProvince();
    if (province == null) return null;
    final list = PhilippineAddressData.getMunicipalities(province);
    if (_selectedMunicipality != null && list.contains(_selectedMunicipality)) return _selectedMunicipality;
    return list.isNotEmpty ? list.first : null;
  }

  String? _effectiveBarangay() {
    final municipality = _effectiveMunicipality();
    if (municipality == null) return null;
    final list = PhilippineAddressData.getBarangays(municipality);
    if (_selectedBarangay != null && list.contains(_selectedBarangay)) return _selectedBarangay;
    return list.isNotEmpty ? list.first : null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final province = _effectiveProvince();
    final municipality = _effectiveMunicipality();
    final barangay = _effectiveBarangay();
    if (province == null || municipality == null || barangay == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select Province, Municipality, and Barangay before saving.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _evacuationCenterService.updateEvacuationCenter(
        centerId: widget.center.id,
        name: _nameController.text.trim(),
        province: province,
        municipality: municipality,
        barangay: barangay,
        street: _streetController.text.trim(),
        contactNumber: _contactController.text.trim(),
        latitude: double.parse(_latitudeController.text.trim()),
        longitude: double.parse(_longitudeController.text.trim()),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evacuation center updated successfully.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        final String message = _userFriendlyUpdateError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _userFriendlyUpdateError(dynamic e) {
    final msg = e?.toString() ?? '';
    if (msg.contains('null') || msg.contains('Null') || msg.contains('Null check')) {
      return 'Couldn\'t save. Please make sure Province, Municipality, and Barangay are selected and try again.';
    }
    if (msg.contains('Network') || msg.contains('Connection') || msg.contains('timeout')) {
      return 'Connection problem. Please check your internet and try again.';
    }
    if (msg.contains('401') || msg.contains('403')) {
      return 'Session expired or access denied. Please log in again.';
    }
    if (msg.contains('404')) {
      return 'Evacuation center not found. It may have been removed.';
    }
    if (msg.isNotEmpty && msg.length < 80 && !msg.contains('Exception')) {
      return msg;
    }
    return 'Couldn\'t update evacuation center. Please check the fields and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Evacuation Center'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Center Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 16),
            
            // Center Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Center Name *',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              validator: (value) => value?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            
            // Contact Number
            TextFormField(
              controller: _contactController,
              inputFormatters: [
                PhoneNumberInputFormatter(), // 11 digits, starts with 09
              ],
              decoration: InputDecoration(
                labelText: 'Contact Number *',
                hintText: '09XXXXXXXXX',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              keyboardType: TextInputType.phone,
              validator: InputValidators.validatePhoneNumber,
            ),
            
            const SizedBox(height: 24),
            
            // Structured Address Section
            const Text(
              'Structured Address',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select location from map to auto-update address',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            
            // Province Dropdown
            DropdownButtonFormField<String>(
              value: PhilippineAddressData.provinces.contains(_selectedProvince)
                  ? _selectedProvince
                  : (PhilippineAddressData.provinces.isNotEmpty ? PhilippineAddressData.provinces.first : null),
              decoration: InputDecoration(
                labelText: 'Province *',
                prefixIcon: const Icon(Icons.map),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: PhilippineAddressData.provinces.map((province) {
                return DropdownMenuItem(value: province, child: Text(province));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProvince = value;
                  _selectedMunicipality = null;
                  _selectedBarangay = null;
                });
              },
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            
            // Municipality Dropdown
            DropdownButtonFormField<String>(
              value: _selectedProvince != null
                  ? () {
                      final list = PhilippineAddressData.getMunicipalities(_selectedProvince!);
                      return list.contains(_selectedMunicipality) ? _selectedMunicipality : (list.isNotEmpty ? list.first : null);
                    }()
                  : null,
              decoration: InputDecoration(
                labelText: 'Municipality *',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: _selectedProvince != null
                  ? PhilippineAddressData.getMunicipalities(_selectedProvince!)
                      .map((municipality) => DropdownMenuItem(value: municipality, child: Text(municipality)))
                      .toList()
                  : [],
              onChanged: _selectedProvince != null
                  ? (value) {
                      setState(() {
                        _selectedMunicipality = value;
                        _selectedBarangay = null;
                      });
                    }
                  : null,
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            
            // Barangay Dropdown
            DropdownButtonFormField<String>(
              value: _selectedMunicipality != null
                  ? () {
                      final list = PhilippineAddressData.getBarangays(_selectedMunicipality!);
                      return list.contains(_selectedBarangay) ? _selectedBarangay : (list.isNotEmpty ? list.first : null);
                    }()
                  : null,
              decoration: InputDecoration(
                labelText: 'Barangay *',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: _selectedMunicipality != null
                  ? PhilippineAddressData.getBarangays(_selectedMunicipality!)
                      .map((barangay) => DropdownMenuItem(value: barangay, child: Text(barangay)))
                      .toList()
                  : [],
              onChanged: _selectedMunicipality != null
                  ? (value) => setState(() => _selectedBarangay = value)
                  : null,
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            
            // Street
            TextFormField(
              controller: _streetController,
              decoration: InputDecoration(
                labelText: 'Street / Landmark *',
                prefixIcon: const Icon(Icons.signpost),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 2,
              validator: (value) => value?.isEmpty == true ? 'Required' : null,
            ),
            
            const SizedBox(height: 24),
            
            // Coordinates
            const Text(
              'GPS Coordinates',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    decoration: InputDecoration(
                      labelText: 'Latitude *',
                      prefixIcon: const Icon(Icons.gps_fixed),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value?.isEmpty == true) return 'Required';
                      if (double.tryParse(value!) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _longitudeController,
                    decoration: InputDecoration(
                      labelText: 'Longitude *',
                      prefixIcon: const Icon(Icons.gps_fixed),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value?.isEmpty == true) return 'Required';
                      if (double.tryParse(value!) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Map Picker Button
            OutlinedButton.icon(
              onPressed: _isReverseGeocoding ? null : _openMapPicker,
              icon: _isReverseGeocoding 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.map),
              label: Text(_isReverseGeocoding ? 'Detecting address...' : 'Pick Location from Map'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFF1E3A8A)),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Update'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
