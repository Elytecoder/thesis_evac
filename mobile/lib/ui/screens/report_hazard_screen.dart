import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../core/auth/session_storage.dart';
import '../../core/config/api_config.dart';
import '../../core/config/hazard_media_config.dart';
import '../../features/hazards/hazard_media_helper.dart';
import '../../features/hazards/hazard_service.dart';

/// Screen for reporting hazards
class ReportHazardScreen extends StatefulWidget {
  final LatLng location;
  /// Optional: user's current GPS location for backend proximity validation (reduces auto-reject).
  final LatLng? userLocation;

  const ReportHazardScreen({
    super.key,
    required this.location,
    this.userLocation,
  });

  @override
  State<ReportHazardScreen> createState() => _ReportHazardScreenState();
}

class _ReportHazardScreenState extends State<ReportHazardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final HazardService _hazardService = HazardService();
  final ImagePicker _picker = ImagePicker();

  String _selectedHazardType = 'flood';
  bool _isSubmitting = false;
  XFile? _selectedImage;
  XFile? _selectedVideo;
  PreparedHazardImage? _preparedPhoto;
  /// In-memory preview bytes (compressed JPEG after validation).
  Uint8List? _imagePreviewBytes;

  /// Maximum distance (km) from your location to the report location. Matches backend rule.
  /// Updated: Changed from 1.0 km to 0.15 km (150 meters) for more accurate reporting.
  static const double _maxAcceptableDistanceKm = 0.15;

  final List<Map<String, dynamic>> _hazardTypes = [
    {'value': 'flooded_road', 'label': 'Flooded Road', 'icon': Icons.water_drop, 'color': Colors.blue},
    {'value': 'landslide', 'label': 'Landslide', 'icon': Icons.landscape, 'color': Colors.brown},
    {'value': 'fallen_tree', 'label': 'Fallen Tree', 'icon': Icons.park, 'color': Colors.green},
    {'value': 'road_damage', 'label': 'Road Damage', 'icon': Icons.broken_image, 'color': Colors.grey},
    {'value': 'fallen_electric_post', 'label': 'Fallen Electric Post / Wires', 'icon': Icons.power_off, 'color': Colors.amber},
    {'value': 'road_blocked', 'label': 'Road Blocked', 'icon': Icons.block, 'color': Colors.red},
    {'value': 'bridge_damage', 'label': 'Bridge Damage', 'icon': Icons.account_balance, 'color': Colors.orange},
    {'value': 'storm_surge', 'label': 'Storm Surge', 'icon': Icons.waves, 'color': Colors.cyan},
    {'value': 'other', 'label': 'Other', 'icon': Icons.more_horiz, 'color': Colors.blueGrey},
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _onImagePicked(XFile image) async {
    try {
      final prepared = await prepareImageForUpload(image);
      if (!mounted) return;
      setState(() {
        _selectedImage = image;
        _preparedPhoto = prepared;
        _imagePreviewBytes = prepared.bytes;
      });
    } on HazardMediaValidationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );
      if (image != null) await _onImagePicked(image);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (image != null) await _onImagePicked(image);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onVideoPicked(XFile video) async {
    try {
      await validateVideoForUpload(video);
      if (!mounted) return;
      setState(() => _selectedVideo = video);
    } on HazardMediaValidationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    if (!HazardMediaConfig.videoUploadEnabled) return;
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: HazardMediaConfig.maxVideoSeconds),
      );
      if (video != null) await _onVideoPicked(video);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickVideoFromGallery() async {
    if (!HazardMediaConfig.videoUploadEnabled) return;
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: HazardMediaConfig.maxVideoSeconds),
      );
      if (video != null) await _onVideoPicked(video);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                // Run after the sheet closes so route/modal stack is stable (web / camera).
                WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage());
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                WidgetsBinding.instance.addPostFrameCallback((_) => _pickImageFromGallery());
              },
            ),
            if (HazardMediaConfig.videoUploadEnabled) ...[
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Record Video'),
                onTap: () {
                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) => _pickVideo());
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Choose Video from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) => _pickVideoFromGallery());
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final token = await SessionStorage.readToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to submit a hazard report.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // STEP 1: Check for similar pending reports
      final similarReports = await _hazardService.checkSimilarReports(
        hazardType: _selectedHazardType,
        latitude: widget.location.latitude,
        longitude: widget.location.longitude,
        radiusMeters: 100.0,
      );

      if (!mounted) return;

      // STEP 2: If similar reports found, show confirmation dialog
      if (similarReports.isNotEmpty) {
        setState(() => _isSubmitting = false);
        
        await _showConfirmationDialog(similarReports);
        return; // Exit - dialog will handle next steps
      }

      // STEP 3: No similar reports - proceed with normal submission
      await _performSubmission();
    } catch (e) {
      print('Error in submit report: $e');
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show confirmation dialog when similar reports are detected
  Future<void> _showConfirmationDialog(List<Map<String, dynamic>> similarReports) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final mostConfirmed = similarReports.reduce((a, b) {
          final aCount = a['confirmation_count'] as int? ?? 0;
          final bCount = b['confirmation_count'] as int? ?? 0;
          return aCount > bCount ? a : b;
        });

        final reportId = (mostConfirmed['id'] as num?)?.toInt() ?? 0;
        final hazardType = mostConfirmed['hazard_type'] as String? ?? 'Unknown';
        final description = mostConfirmed['description'] as String? ?? '';
        final distance = mostConfirmed['distance_meters'] as num? ?? 0;
        final confirmationCount = mostConfirmed['confirmation_count'] as int? ?? 0;
        final hasUserConfirmed = mostConfirmed['has_user_confirmed'] as bool? ?? false;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warning icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_rounded,
                        color: Colors.orange,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Similar Hazard Found',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Explanation
                const Text(
                  'A similar hazard has already been reported nearby. Would you like to confirm it instead?',
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
                
                const SizedBox(height: 20),
                
                // Report preview card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hazard type badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          hazardType,
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      
                      const SizedBox(height: 12),
                      
                      // Distance and confirmations
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${distance.round()}m away',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          
                          if (confirmationCount > 0) ...[
                            const SizedBox(width: 16),
                            Icon(Icons.verified_user, size: 16, color: Colors.green.shade600),
                            const SizedBox(width: 4),
                            Text(
                              '$confirmationCount ${confirmationCount == 1 ? 'confirmation' : 'confirmations'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                if (hasUserConfirmed) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You have already confirmed this hazard',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // Action buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Confirm button (recommended)
                    ElevatedButton.icon(
                      onPressed: hasUserConfirmed
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _confirmExistingReport(reportId, mostConfirmed);
                            },
                      icon: const Icon(Icons.check_circle),
                      label: Text(
                        hasUserConfirmed
                            ? 'Already Confirmed'
                            : 'Confirm Existing Hazard',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasUserConfirmed ? Colors.grey : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Submit new report button
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _performSubmission();
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Submit New Report Anyway'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        side: BorderSide(color: Colors.orange.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Cancel button
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Confirm an existing hazard report
  Future<void> _confirmExistingReport(int reportId, Map<String, dynamic> reportData) async {
    setState(() => _isSubmitting = true);

    try {
      await _hazardService.confirmHazardReport(reportId);

      if (mounted) {
        Navigator.pop(context); // Close report screen

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Hazard confirmed! Your confirmation strengthens this report.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Error confirming hazard: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm hazard: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Perform the actual report submission
  Future<void> _performSubmission() async {
    setState(() => _isSubmitting = true);

    try {
      String? photoUrl;
      String? videoUrl;
      Uint8List? videoBytes;
      String? videoFilename;

      if (ApiConfig.useMockData) {
        if (_selectedImage != null) {
          photoUrl = 'https://example.com/uploads/${_selectedImage!.name}';
        }
        if (_selectedVideo != null) {
          videoUrl = 'https://example.com/uploads/${_selectedVideo!.name}';
        }
      } else {
        if (HazardMediaConfig.videoUploadEnabled && _selectedVideo != null) {
          try {
            await validateVideoForUpload(_selectedVideo!);
          } on HazardMediaValidationException catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.message),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            setState(() => _isSubmitting = false);
            return;
          }
          videoBytes = await _selectedVideo!.readAsBytes();
          videoFilename = _selectedVideo!.name;
        }
      }

      await _hazardService.submitHazardReport(
        hazardType: _selectedHazardType,
        latitude: widget.location.latitude,
        longitude: widget.location.longitude,
        description: _descriptionController.text.trim(),
        userLatitude: widget.userLocation?.latitude,
        userLongitude: widget.userLocation?.longitude,
        photoUrl: photoUrl,
        videoUrl: videoUrl,
        photoBytes: ApiConfig.useMockData ? null : _preparedPhoto?.bytes,
        photoFilename: ApiConfig.useMockData ? null : _preparedPhoto?.filename,
        videoBytes: ApiConfig.useMockData ? null : videoBytes,
        videoFilename: ApiConfig.useMockData ? null : videoFilename,
      );

      if (mounted) {
        Navigator.pop(context);

        // Show simplified success dialog (no validation scores for residents)
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text('Report Submitted'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report submitted successfully',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your hazard report has been received.',
                  style: TextStyle(fontSize: 15),
                ),
                if (_selectedImage != null || _selectedVideo != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_selectedImage != null) ...[
                        const Icon(Icons.photo, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        const Text('Photo attached', style: TextStyle(fontSize: 12)),
                      ],
                      if (_selectedImage != null && _selectedVideo != null)
                        const SizedBox(width: 12),
                      if (_selectedVideo != null) ...[
                        const Icon(Icons.videocam, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        const Text('Video attached', style: TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The MDRRMO will review and verify your report.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final message = e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Failed to submit report. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  double? get _distanceKm {
    final user = widget.userLocation;
    if (user == null) return null;
    const distance = Distance();
    return distance.as(LengthUnit.Kilometer, user, widget.location);
  }

  bool get _isTooFar => _distanceKm != null && _distanceKm! > _maxAcceptableDistanceKm;

  bool get _hasUnsavedChanges =>
      _descriptionController.text.trim().isNotEmpty ||
      _selectedImage != null ||
      _selectedVideo != null;

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard report?'),
        content: const Text(
          'You have unsaved changes. Going back will discard this report.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = _distanceKm;
    final isTooFar = _isTooFar;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (!_hasUnsavedChanges) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
        final discard = await _confirmDiscard();
        if (discard && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Report Hazard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Report Location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${widget.location.latitude.toStringAsFixed(4)}, ${widget.location.longitude.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (isTooFar) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[300]!, width: 1.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Report location is too far from you',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[900],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'You are about ${distanceKm != null ? (distanceKm! * 1000).toStringAsFixed(0) : '?'} meters away from the hazard location. '
                                    'Reports are only accepted when you are within 150 meters of the hazard. '
                                    'This ensures MDRRMO can verify reports from on-site observers.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                      color: Colors.orange[900],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'This report will not be sent for MDRRMO approval and would be auto-rejected. '
                                    'Please move closer to the hazard (within 150 meters) to submit.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Hazard type
                    const Text(
                      'Hazard Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: _hazardTypes.length,
                      itemBuilder: (context, index) {
                        final hazard = _hazardTypes[index];
                        final isSelected = _selectedHazardType == hazard['value'];

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedHazardType = hazard['value'];
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? hazard['color'].withOpacity(0.1) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? hazard['color'] : Colors.grey[200]!,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  hazard['icon'],
                                  color: isSelected ? hazard['color'] : Colors.grey[600],
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hazard['label'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? hazard['color'] : Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Description
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Describe the hazard situation...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please provide a description';
                        }
                        if (value.trim().length < 10) {
                          return 'Description must be at least 10 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Media upload (optional)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attach Media (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            HazardMediaConfig.videoUploadEnabled
                                ? 'JPG/PNG max 2 MB · MP4 max 10 MB / 10 s'
                                : 'JPG or PNG, max 2 MB',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Media preview and upload button
                    if (_selectedImage != null || _selectedVideo != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          children: [
                            if (_selectedImage != null)
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: _imagePreviewBytes != null
                                          ? Image.memory(
                                              _imagePreviewBytes!,
                                              fit: BoxFit.cover,
                                            )
                                          : const ColoredBox(
                                              color: Color(0xFFE0E0E0),
                                              child: Center(
                                                child: Icon(Icons.image, color: Colors.grey),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Photo attached',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _selectedImage!.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      setState(() {
                                        _selectedImage = null;
                                        _preparedPhoto = null;
                                        _imagePreviewBytes = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            if (_selectedImage != null && _selectedVideo != null)
                              const Divider(height: 24),
                            if (_selectedVideo != null)
                              Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.play_circle_filled,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Video attached',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _selectedVideo!.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      setState(() {
                                        _selectedVideo = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    
                    // Upload button
                    OutlinedButton.icon(
                      onPressed: _showMediaOptions,
                      icon: Icon(
                        _selectedImage != null || _selectedVideo != null 
                            ? Icons.edit 
                            : Icons.camera_alt,
                        size: 20,
                      ),
                      label: Text(
                        _selectedImage != null || _selectedVideo != null
                            ? 'Change Media'
                            : HazardMediaConfig.videoUploadEnabled
                                ? 'Add Photo or Video'
                                : 'Add Photo',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Info note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your report will be validated using AI and reviewed by MDRRMO before being added to the system.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Submit button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || _isTooFar) ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Submit Report',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    ), // Scaffold
    ); // PopScope
  }
}
