import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../../features/admin/admin_mock_service.dart';
import '../../features/admin/reverse_geocoding_service.dart';
import '../../core/constants/philippine_address_data.dart';
import '../../utils/input_validators.dart';
import '../../utils/input_formatters.dart';
import 'map_location_picker_screen.dart';

/// Add Evacuation Center Screen - Form with structured address and auto-fill
class AddEvacuationCenterScreen extends StatefulWidget {
  const AddEvacuationCenterScreen({super.key});

  @override
  State<AddEvacuationCenterScreen> createState() => _AddEvacuationCenterScreenState();
}

class _AddEvacuationCenterScreenState extends State<AddEvacuationCenterScreen> {
  final _formKey = GlobalKey<FormState>();
  final AdminMockService _adminService = AdminMockService();
  final ReverseGeocodingService _geocodingService = ReverseGeocodingService();
  
  final _nameController = TextEditingController();
  final _streetController = TextEditingController();
  final _contactController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  
  // Cascading dropdown values
  String? _selectedProvince;
  String? _selectedMunicipality;
  String? _selectedBarangay;
  
  bool _isSaving = false;
  bool _isReverseGeocoding = false;

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
    // Get current coordinates if available
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

    // Update coordinates and perform reverse geocoding
    if (selectedLocation != null && mounted) {
      setState(() {
        _latitudeController.text = selectedLocation.latitude.toStringAsFixed(6);
        _longitudeController.text = selectedLocation.longitude.toStringAsFixed(6);
        _isReverseGeocoding = true;
      });
      
      // Perform reverse geocoding
      try {
        final addressComponents = await _geocodingService.reverseGeocode(selectedLocation);
        
        if (addressComponents != null && mounted) {
          // Validate and sanitize geocoded values to match dropdown options
          String? validProvince;
          String? validMunicipality;
          String? validBarangay;
          
          // Validate province (must exist in our list)
          final geocodedProvince = addressComponents['province'];
          if (geocodedProvince != null && PhilippineAddressData.provinces.contains(geocodedProvince)) {
            validProvince = geocodedProvince;
          } else {
            // Default to Sorsogon if not found
            validProvince = 'Sorsogon';
          }
          
          // Validate municipality (must exist under the province)
          final geocodedMunicipality = addressComponents['municipality'];
          final availableMunicipalities = PhilippineAddressData.getMunicipalities(validProvince);
          if (geocodedMunicipality != null && availableMunicipalities.contains(geocodedMunicipality)) {
            validMunicipality = geocodedMunicipality;
          } else {
            // Try case-insensitive match
            validMunicipality = availableMunicipalities.firstWhere(
              (m) => m.toLowerCase() == geocodedMunicipality?.toLowerCase(),
              orElse: () => availableMunicipalities.isNotEmpty ? availableMunicipalities.first : 'Bulan',
            );
          }
          
          // Validate barangay (must exist under the municipality)
          final geocodedBarangay = addressComponents['barangay'];
          final availableBarangays = PhilippineAddressData.getBarangays(validMunicipality);
          if (geocodedBarangay != null && availableBarangays.contains(geocodedBarangay)) {
            validBarangay = geocodedBarangay;
          } else {
            // Try case-insensitive or partial match
            validBarangay = availableBarangays.firstWhere(
              (b) => b.toLowerCase().contains(geocodedBarangay?.toLowerCase() ?? ''),
              orElse: () => '', // Leave empty if no match
            );
            if (validBarangay.isEmpty && availableBarangays.isNotEmpty) {
              validBarangay = null; // Don't auto-select, let user choose
            }
          }
          
          setState(() {
            // Auto-fill address dropdowns with validated values
            _selectedProvince = validProvince;
            _selectedMunicipality = validMunicipality;
            _selectedBarangay = validBarangay;
            _streetController.text = addressComponents['street'] ?? '';
            _isReverseGeocoding = false;
          });
          
          if (mounted) {
            final message = validBarangay == null
                ? '✅ Location set. Please select barangay manually.'
                : '✅ Location and address auto-filled from map';
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: validBarangay == null ? Colors.orange : Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          setState(() => _isReverseGeocoding = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Address could not be determined. Please complete manually.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        setState(() => _isReverseGeocoding = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Geocoding failed: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _adminService.addEvacuationCenter(
        name: _nameController.text.trim(),
        province: _selectedProvince!,
        municipality: _selectedMunicipality!,
        barangay: _selectedBarangay!,
        street: _streetController.text.trim(),
        contactNumber: _contactController.text.trim(),
        latitude: double.parse(_latitudeController.text.trim()),
        longitude: double.parse(_longitudeController.text.trim()),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evacuation center added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add center: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Evacuation Center'),
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
                hintText: 'e.g., Bulan Gymnasium',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter center name';
                }
                return null;
              },
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
              'Select location from map to auto-fill address fields',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            
            // Province Dropdown
            DropdownButtonFormField<String>(
              value: _selectedProvince,
              decoration: InputDecoration(
                labelText: 'Province *',
                prefixIcon: const Icon(Icons.map),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: PhilippineAddressData.provinces.map((province) {
                return DropdownMenuItem(
                  value: province,
                  child: Text(province),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProvince = value;
                  _selectedMunicipality = null; // Reset municipality
                  _selectedBarangay = null; // Reset barangay
                });
              },
              validator: (value) => value == null ? 'Required' : null,
            ),
            
            const SizedBox(height: 16),
            
            // Municipality Dropdown (filtered by province)
            DropdownButtonFormField<String>(
              value: _selectedMunicipality,
              decoration: InputDecoration(
                labelText: 'Municipality *',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: _selectedProvince != null
                  ? PhilippineAddressData.getMunicipalities(_selectedProvince!)
                      .map((municipality) {
                        return DropdownMenuItem(
                          value: municipality,
                          child: Text(municipality),
                        );
                      }).toList()
                  : [],
              onChanged: _selectedProvince != null
                  ? (value) {
                      setState(() {
                        _selectedMunicipality = value;
                        _selectedBarangay = null; // Reset barangay
                      });
                    }
                  : null,
              validator: (value) => value == null ? 'Required' : null,
            ),
            
            const SizedBox(height: 16),
            
            // Barangay Dropdown (filtered by municipality)
            DropdownButtonFormField<String>(
              value: _selectedBarangay,
              decoration: InputDecoration(
                labelText: 'Barangay *',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: _selectedMunicipality != null
                  ? PhilippineAddressData.getBarangays(_selectedMunicipality!)
                      .map((barangay) {
                        return DropdownMenuItem(
                          value: barangay,
                          child: Text(barangay),
                        );
                      }).toList()
                  : [],
              onChanged: _selectedMunicipality != null
                  ? (value) {
                      setState(() {
                        _selectedBarangay = value;
                      });
                    }
                  : null,
              validator: (value) => value == null ? 'Required' : null,
            ),
            
            const SizedBox(height: 16),
            
            // Street (Manual input)
            TextFormField(
              controller: _streetController,
              decoration: InputDecoration(
                labelText: 'Street / Landmark *',
                hintText: 'e.g., Main Street',
                prefixIcon: const Icon(Icons.signpost),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter street or landmark';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Coordinates Section
            const Text(
              'GPS Coordinates',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use map picker to select exact location',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    decoration: InputDecoration(
                      labelText: 'Latitude *',
                      hintText: '12.6699',
                      prefixIcon: const Icon(Icons.gps_fixed),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid';
                      }
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
                      hintText: '123.8758',
                      prefixIcon: const Icon(Icons.gps_fixed),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid';
                      }
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
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.map),
              label: Text(_isReverseGeocoding 
                  ? 'Detecting address...' 
                  : 'Pick Location from Map'),
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
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
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
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
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
