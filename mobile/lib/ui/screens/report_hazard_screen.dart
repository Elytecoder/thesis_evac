import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../core/auth/session_storage.dart';
import '../../core/config/api_config.dart';
import '../../core/config/hazard_media_config.dart';
import '../../core/services/connectivity_service.dart';
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
      // When offline, skip the similar-reports API call and queue directly.
      final isOnline = await ConnectivityService().isOnline;
      if (!isOnline) {
        await _performSubmission();
        return;
      }

      // STEP 1: Check for similar pending reports
      final similarResult = await _hazardService.checkSimilarReportsWithMeta(
        hazardType: _selectedHazardType,
        latitude: widget.location.latitude,
        longitude: widget.location.longitude,
        radiusMeters: 150.0,
      );
      final similarReports = (similarResult['similar_reports']
              as List<Map<String, dynamic>>?) ??
          <Map<String, dynamic>>[];
      final timeWindowHours = similarResult['time_window_hours'] as int?;

      if (!mounted) return;

      // STEP 2: If similar reports found, show confirmation dialog
      if (similarReports.isNotEmpty) {
        setState(() => _isSubmitting = false);
        
        await _showConfirmationDialog(
          similarReports,
          timeWindowHours: timeWindowHours,
        );
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

  /// Show confirmation dialog when similar reports are detected within 150 m.
  Future<void> _showConfirmationDialog(
    List<Map<String, dynamic>> similarReports, {
    int? timeWindowHours,
  }) async {
    // Sort: approved first, then by most confirmations.
    final sorted = List<Map<String, dynamic>>.from(similarReports)
      ..sort((a, b) {
        final aApproved = a['is_approved'] as bool? ?? false;
        final bApproved = b['is_approved'] as bool? ?? false;
        if (aApproved != bApproved) return aApproved ? -1 : 1;
        final aCount = a['confirmation_count'] as int? ?? 0;
        final bCount = b['confirmation_count'] as int? ?? 0;
        return bCount.compareTo(aCount);
      });

    final best = sorted.first;
    final reportId = (best['id'] as num?)?.toInt() ?? 0;
    final rawType = best['hazard_type'] as String? ?? 'Unknown';
    final hazardLabel = _hazardTypes.firstWhere(
      (h) => h['value'] == rawType,
      orElse: () => {'label': rawType},
    )['label'] as String;
    final description = best['description'] as String? ?? '';
    final distanceM = (best['distance_meters'] as num? ?? 0).round();
    final confirmationCount = best['confirmation_count'] as int? ?? 0;
    final hasUserConfirmed = best['has_user_confirmed'] as bool? ?? false;
    final isApproved = best['is_approved'] as bool? ?? false;

    final String statusLabel;
    final Color statusBg;
    final Color statusFg;
    if (isApproved) {
      statusLabel = '✓ Verified by MDRRMO';
      statusBg = Colors.green.shade100;
      statusFg = Colors.green.shade800;
    } else {
      statusLabel = '⏳ Pending Review';
      statusBg = Colors.amber.shade100;
      statusFg = Colors.amber.shade900;
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Coloured header banner ──────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  decoration: BoxDecoration(
                    color: isApproved
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isApproved
                              ? Icons.verified_rounded
                              : Icons.report_problem_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hazard Already Reported Nearby',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedHazardType == 'other'
                                  ? 'A similar hazard was found $distanceM m from your location. Based on the location, it may refer to the same situation.'
                                  : 'A $hazardLabel was found $distanceM m from your location.',
                              style: TextStyle(
                                color: Colors.white.withAlpha(230),
                                fontSize: 13,
                              ),
                            ),
                            if (timeWindowHours != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Matched reports from the last $timeWindowHours ${timeWindowHours == 1 ? 'hour' : 'hours'}.',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(220),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Body ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Existing report card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Type + status chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _chip(
                                  hazardLabel,
                                  Colors.red.shade100,
                                  Colors.red.shade900,
                                  Icons.warning_amber_rounded,
                                ),
                                _chip(
                                  statusLabel,
                                  statusBg,
                                  statusFg,
                                  null,
                                ),
                              ],
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 10),
                            // Distance + confirmations row
                            Row(
                              children: [
                                Icon(Icons.place_outlined,
                                    size: 15,
                                    color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  '$distanceM m away',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Icon(Icons.people_outline,
                                    size: 15,
                                    color: confirmationCount > 0
                                        ? Colors.blue.shade500
                                        : Colors.grey.shade400),
                                const SizedBox(width: 4),
                                Text(
                                  confirmationCount == 0
                                      ? 'No confirmations yet'
                                      : '$confirmationCount ${confirmationCount == 1 ? 'confirmation' : 'confirmations'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: confirmationCount > 0
                                        ? Colors.blue.shade700
                                        : Colors.grey.shade500,
                                    fontWeight: confirmationCount > 0
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Already-confirmed notice (shown for both pending + approved)
                      if (hasUserConfirmed)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: Colors.blue.shade700, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'You already confirmed this hazard. Thank you for helping validate it.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // Explain why confirming is the right choice
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.tips_and_updates_outlined,
                                  color: Colors.green.shade700, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _selectedHazardType == 'other'
                                      ? 'This nearby report covers an unclassified hazard. '
                                          'Confirming it adds your observation as supporting evidence '
                                          'and strengthens its confidence score — especially important '
                                          'when the hazard category is uncertain.'
                                      : 'Confirming this report tells MDRRMO that you also see this hazard. '
                                          'It improves accuracy and speeds up the response — no duplicate needed.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.green.shade900,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (timeWindowHours != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              size: 15,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Similarity matching currently uses reports from the last '
                                '$timeWindowHours ${timeWindowHours == 1 ? 'hour' : 'hours'}.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ── Action buttons ────────────────────────────────
                      // PRIMARY: Confirm existing
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: hasUserConfirmed
                              ? null
                              : () async {
                                  Navigator.pop(context);
                                  await _confirmExistingReport(
                                      reportId, best);
                                },
                          icon: Icon(
                            hasUserConfirmed
                                ? Icons.check_circle
                                : Icons.thumb_up_alt_rounded,
                          ),
                          label: Text(
                            hasUserConfirmed
                                ? 'Already Confirmed'
                                : 'Confirm Existing Report',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasUserConfirmed
                                ? Colors.grey.shade300
                                : Colors.green.shade600,
                            foregroundColor: hasUserConfirmed
                                ? Colors.grey.shade600
                                : Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: hasUserConfirmed ? 0 : 2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // SECONDARY: Submit new report anyway (with disclaimer)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _performSubmission();
                          },
                          icon: Icon(Icons.add_circle_outline,
                              color: Colors.orange.shade700),
                          label: const Text(
                            'Submit New Report Anyway',
                            style: TextStyle(fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade700,
                            side: BorderSide(color: Colors.orange.shade300),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 5, left: 4),
                        child: Text(
                          'Only use this if this is a different hazard or a new occurrence.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                      // CANCEL
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),

                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Small labelled chip used inside the confirmation dialog card.
  Widget _chip(
      String label, Color bg, Color fg, IconData? icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  /// Confirm an existing hazard report and show a thank-you message.
  Future<void> _confirmExistingReport(
      int reportId, Map<String, dynamic> reportData) async {
    setState(() => _isSubmitting = true);

    try {
      await _hazardService.confirmHazardReport(reportId);

      if (mounted) {
        Navigator.pop(context); // Close report screen

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirmation Submitted',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Thank you. Your confirmation was added to the existing report.',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not confirm hazard. Please try again.'),
            backgroundColor: Colors.red.shade600,
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

      final submittedReport = await _hazardService.submitHazardReport(
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
        // Pass the submitted report back to the map screen for optimistic UI
        Navigator.pop(context, submittedReport);

        // Detect offline queue: userId is null but clientSubmissionId is set.
        final bool wasQueued = submittedReport.userId == null &&
            submittedReport.clientSubmissionId != null;
        final bool wasAutoRejected = submittedReport.autoRejected;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  wasQueued
                      ? Icons.cloud_off
                      : (wasAutoRejected ? Icons.info_outline : Icons.check_circle),
                  color: wasQueued
                      ? Colors.deepOrange
                      : (wasAutoRejected ? Colors.orange : Colors.green),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(wasQueued
                    ? 'Saved Offline'
                    : (wasAutoRejected ? 'Report Not Submitted' : 'Report Submitted')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wasQueued
                      ? 'Report saved offline. It will sync when internet is available.'
                      : (wasAutoRejected
                          ? 'Your report could not be submitted'
                          : 'Report submitted successfully'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  wasQueued
                      ? 'Your report has been saved to your device and will be uploaded automatically once you reconnect.'
                      : (wasAutoRejected
                          ? (submittedReport.adminComment?.isNotEmpty == true
                              ? submittedReport.adminComment!
                              : 'You appear to be too far from the reported hazard location. Please move closer and try again.')
                          : 'Your hazard report has been received.'),
                  style: const TextStyle(fontSize: 15),
                ),
                if (!wasQueued && !wasAutoRejected && (_selectedImage != null || _selectedVideo != null)) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_selectedImage != null) ...[
                        const Icon(Icons.photo, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        const Text('Photo attached',
                            style: TextStyle(fontSize: 12)),
                      ],
                      if (_selectedImage != null && _selectedVideo != null)
                        const SizedBox(width: 12),
                      if (_selectedVideo != null) ...[
                        const Icon(Icons.videocam,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        const Text('Video attached',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: wasQueued
                        ? Colors.deepOrange[50]
                        : (wasAutoRejected ? Colors.orange[50] : Colors.blue[50]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        wasQueued
                            ? Icons.sync
                            : (wasAutoRejected
                                ? Icons.warning_amber_outlined
                                : Icons.info_outline),
                        color: wasQueued
                            ? Colors.deepOrange[700]
                            : (wasAutoRejected
                                ? Colors.orange[700]
                                : Colors.blue[700]),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          wasQueued
                              ? 'Your report marker is now visible on the map as pending sync.'
                              : (wasAutoRejected
                                  ? 'Make sure you are physically near the hazard before reporting.'
                                  : 'The MDRRMO will review and verify your report.'),
                          style: TextStyle(
                            fontSize: 13,
                            color: wasQueued
                                ? Colors.deepOrange[900]
                                : (wasAutoRejected
                                    ? Colors.orange[900]
                                    : Colors.blue[900]),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
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

                    // ── Helper tip for "Other" type ──────────────────────────
                    if (_selectedHazardType == 'other')
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: Colors.blue.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Please describe the hazard clearly. Include what you see '
                                '(e.g. blocked road, flooding, debris, accident).',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
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
