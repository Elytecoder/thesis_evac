import 'package:flutter/material.dart';
import '../../features/admin/admin_mock_service.dart';
import '../../models/evacuation_center.dart';

/// Edit Evacuation Center Screen - Edit existing evacuation center.
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
  final AdminMockService _adminService = AdminMockService();
  
  late TextEditingController _nameController;
  late TextEditingController _barangayController;
  late TextEditingController _addressController;
  late TextEditingController _contactController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.center.name);
    _barangayController = TextEditingController(text: 'Zone ${widget.center.id}');
    _addressController = TextEditingController(text: widget.center.description);
    _contactController = TextEditingController(text: '0917-123-45${widget.center.id}7');
    _latitudeController = TextEditingController(text: widget.center.latitude.toString());
    _longitudeController = TextEditingController(text: widget.center.longitude.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barangayController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _adminService.updateEvacuationCenter(
        id: widget.center.id,
        name: _nameController.text.trim(),
        barangay: _barangayController.text.trim(),
        address: _addressController.text.trim(),
        contactNumber: _contactController.text.trim(),
        latitude: double.parse(_latitudeController.text.trim()),
        longitude: double.parse(_longitudeController.text.trim()),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evacuation center updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
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
        title: const Text('Edit Evacuation Center'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Center Name',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              validator: (value) => value?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _barangayController,
              decoration: InputDecoration(
                labelText: 'Barangay',
                prefixIcon: const Icon(Icons.map),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              validator: (value) => value?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Address',
                prefixIcon: const Icon(Icons.home),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 2,
              validator: (value) => value?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactController,
              decoration: InputDecoration(
                labelText: 'Contact Number',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) => value?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    decoration: InputDecoration(
                      labelText: 'Latitude',
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
                      labelText: 'Longitude',
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
            const SizedBox(height: 32),
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
