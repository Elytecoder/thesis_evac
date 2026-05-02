import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/utils/date_time_utils.dart';
import '../../features/hazards/hazard_service.dart';
import '../../models/hazard_report.dart';
import '../widgets/map_marker_style.dart';
import '../widgets/report_media_preview.dart';

/// Report Detail Screen - View full report details and make approval decisions.
/// 
/// Shows map preview, report info, AI analysis, and decision controls.
class ReportDetailScreen extends StatefulWidget {
  final HazardReport report;

  const ReportDetailScreen({
    super.key,
    required this.report,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final HazardService _hazardService = HazardService();
  bool _isProcessing = false;

  /// Show reminder modal before approval
  /// Reminder modal ensures hazard impacts evacuation route before approval.
  Future<bool?> _showApprovalReminderModal() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // Must click button to dismiss
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700], size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Approval Reminder',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber, color: Colors.blue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This system will only consider a hazard if it blocks the way to the evacuation center. '
                      'Please confirm that this reported hazard directly affects evacuation routes before approving.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        height: 1.5,
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_circle),
            label: const Text('Confirm Approval'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove() async {
    // STEP 1: Show reminder modal BEFORE approval
    // Reminder modal ensures hazard impacts evacuation route before approval.
    final reminderConfirmed = await _showApprovalReminderModal();

    if (reminderConfirmed != true) {
      // User cancelled from reminder modal
      return;
    }

    // STEP 2: Show final confirmation dialog
    final confirm = await _showConfirmDialog(
      'Approve Report',
      'Are you sure you want to approve this hazard report?',
      Colors.green,
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);

      try {
        await _hazardService.approveOrRejectReport(
          reportId: widget.report.id ?? 0,
          approve: true,
        );

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context, true); // Return true to indicate update
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Report approved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to approve: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  Future<void> _handleReject() async {
    final confirm = await _showConfirmDialog(
      'Reject Report',
      'Are you sure you want to reject this hazard report?',
      Colors.red,
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);

      try {
        await _hazardService.approveOrRejectReport(
          reportId: widget.report.id ?? 0,
          approve: false,
        );

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context, true); // Return true to indicate update
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Report rejected'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reject: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  Future<bool?> _showConfirmDialog(String title, String message, Color color) {
    final isApprove = color == Colors.green;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isApprove ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    isApprove ? 'Approve' : 'Reject',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final canTakeAction = report.status == HazardStatus.pending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Map Preview Placeholder
            _buildMapPreview(),

            // Section 2: Report Information
            _buildSection(
              title: 'Report Information',
              icon: Icons.info_outline,
              child: _buildReportInfo(),
            ),

            // Section 3: AI Analysis Panel
            _buildSection(
              title: 'AI Analysis',
              icon: Icons.psychology,
              child: _buildAIAnalysis(),
            ),

            // Section 4: Decision Controls (only for pending reports)
            if (canTakeAction)
              _buildSection(
                title: 'Decision Controls',
                icon: Icons.gavel,
                child: _buildDecisionControls(),
              ),

            // Admin Comment (for approved/rejected reports)
            if (report.adminComment != null && report.adminComment!.isNotEmpty)
              _buildSection(
                title: 'Admin Comment',
                icon: Icons.comment,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.adminComment!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Functional map preview showing both hazard and user locations
  /// Auto-fits bounds to display both markers simultaneously
  Widget _buildMapPreview() {
    final report = widget.report;
    final hasUserLocation = report.userLatitude != null && report.userLongitude != null;
    
    // Create list of points for auto-fit bounds
    final List<LatLng> points = [
      LatLng(report.latitude, report.longitude), // Hazard location
    ];
    
    if (hasUserLocation) {
      points.add(LatLng(report.userLatitude!, report.userLongitude!)); // User location
    }
    
    // Calculate center point for initial display
    final centerLat = hasUserLocation 
        ? (report.latitude + report.userLatitude!) / 2
        : report.latitude;
    final centerLng = hasUserLocation
        ? (report.longitude + report.userLongitude!) / 2
        : report.longitude;
    
    return Container(
      height: 250,
      child: Stack(
        children: [
          // Functional flutter_map with markers
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(centerLat, centerLng),
              initialZoom: hasUserLocation ? 15.0 : 16.0,
              minZoom: 12.0,
              maxZoom: 18.0,
            ),
            children: [
              // OpenStreetMap tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.evacroute.mobile',
              ),
              
              // Markers for hazard and user locations
              MarkerLayer(
                markers: [
                  // Hazard location marker (RED)
                  Marker(
                    point: LatLng(report.latitude, report.longitude),
                    width: 80,
                    height: 80,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Hazard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(
                          MapMarkerStyle.verifiedHazardIcon,
                          color: MapMarkerStyle.verifiedHazardColor,
                          size: 40,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // User location marker (BLUE) - only if available
                  if (hasUserLocation)
                    Marker(
                      point: LatLng(report.userLatitude!, report.userLongitude!),
                      width: 80,
                      height: 80,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'User',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.person_pin_circle,
                            color: Colors.blue,
                            size: 40,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          // Legend overlay
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        MapMarkerStyle.verifiedHazardIcon,
                        color: MapMarkerStyle.verifiedHazardColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      const Text('Reported Hazard', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  if (hasUserLocation) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_pin_circle, color: Colors.blue, size: 16),
                        const SizedBox(width: 4),
                        const Text('User Location', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Fallback message if user location unavailable
          if (!hasUserLocation)
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'User location unavailable',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF1E3A8A), size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildReportInfo() {
    final report = widget.report;
    final coordText =
        '${report.latitude.toStringAsFixed(5)}, ${report.longitude.toStringAsFixed(5)}';
    final locationText = (report.locationLabel ?? '').trim();
    final areaText = [
      (report.locationBarangay ?? '').trim(),
      (report.locationMunicipality ?? '').trim(),
    ].where((v) => v.isNotEmpty).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Hazard Type', report.hazardType.toUpperCase().replaceAll('_', ' ')),
        _buildInfoRow('Report ID', report.publicReportLabel),
        _buildReporterBlock(report),
        _buildInfoRow('Submitted', _formatFullDateTime(report.createdAt ?? DateTime.now())),
        _buildInfoRow('Hazard Coordinates', coordText),
        if (areaText.isNotEmpty) _buildInfoRow('Hazard Area', areaText),
        if (locationText.isNotEmpty) _buildInfoRow('Hazard Address', locationText),
        _buildInfoRow('Status', _getStatusText(report.status), statusColor: _getStatusColor(report.status)),
        
        const SizedBox(height: 12),
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          report.description,
          style: const TextStyle(fontSize: 14),
        ),

        if (reportHasMedia(report)) ...[
          const SizedBox(height: 16),
          ReportMediaSection(report: report, isAdmin: true),
        ],
      ],
    );
  }

  Widget _buildReporterBlock(HazardReport report) {
    final name = (report.reporterFullName ?? '').trim();
    final displayUserId = report.reporterDisplayId;
    final fallbackId = report.userId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              'Reporter',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Unknown reporter',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayUserId != null
                      ? 'ID: #$displayUserId'
                      : (fallbackId != null ? 'ID: #$fallbackId' : 'ID: —'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: statusColor != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// AI Analysis panel for MDRRMO report details.
  /// Shows the report's AI confidence level — how likely the submission is valid.
  /// This is NOT a hazard danger rating; it measures report credibility only.
  Widget _buildAIAnalysis() {
    final report = widget.report;
    // Combined weighted score: NB 50% + distance 30% + consensus 20%.
    // Fall back to naiveBayesScore for older records.
    final validationScore =
        report.finalValidationScore ?? report.naiveBayesScore ?? 0.0;

    // Confidence label + colour based on validation score thresholds.
    // Thresholds: 0.00–0.49 = Low, 0.50–0.74 = Medium, 0.75–1.00 = High
    final String confidenceLabel;
    final Color confidenceColor;
    final IconData confidenceIcon;
    final String recommendation;

    if (validationScore >= 0.75) {
      confidenceLabel = 'High Confidence';
      confidenceColor = const Color(0xFF1565C0); // deep blue — report likely valid
      confidenceIcon = Icons.verified_rounded;
      recommendation =
          'The report has strong credibility signals. Consider approving after field verification.';
    } else if (validationScore >= 0.50) {
      confidenceLabel = 'Medium Confidence';
      confidenceColor = Colors.orange;
      confidenceIcon = Icons.help_outline_rounded;
      recommendation =
          'The report has moderate credibility. Review the details carefully before deciding.';
    } else {
      confidenceLabel = 'Low Confidence';
      confidenceColor = Colors.grey[700]!;
      confidenceIcon = Icons.info_outline_rounded;
      recommendation =
          'The report has low credibility indicators. Additional verification is recommended before approval.';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: confidenceColor.withOpacity(0.3), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // SECTION 1: AI Confidence Level Banner
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 24,
                      vertical: isSmallScreen ? 12 : 16,
                    ),
                    decoration: BoxDecoration(
                      color: confidenceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(confidenceIcon, color: Colors.white, size: isSmallScreen ? 20 : 24),
                            const SizedBox(width: 8),
                            Text(
                              'AI Confidence Level',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: isSmallScreen ? 13 : 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          confidenceLabel,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 22 : 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // SECTION 2: Confidence Score percentage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Confidence Score: ',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          color: Colors.black87,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 10 : 12,
                          vertical: isSmallScreen ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: confidenceColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: confidenceColor.withOpacity(0.6)),
                        ),
                        child: Text(
                          '${(validationScore * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 15 : 17,
                            fontWeight: FontWeight.bold,
                            color: confidenceColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // SECTION 3: Score breakdown row
                  _buildScoreBreakdownRow(report, isSmallScreen),

                  const SizedBox(height: 16),

                  // SECTION 4: Recommendation
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline, color: Colors.blue, size: isSmallScreen ? 16 : 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Recommendation',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          recommendation,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // SECTION 5: Helper note
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.policy_outlined, size: 15, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This score estimates how likely the report is valid. MDRRMO still makes the final approval decision.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // SECTION 6: Expandable Technical Details
                  // Random Forest is used only for road segment risk and not for report validation.
                  ExpansionTile(
                    title: Text(
                      'View Technical Details',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    maintainState: true,
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      ..._buildNaiveBayesTechnicalDetails(widget.report, validationScore),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Three mini score bars: Text Credibility, Reporter Proximity, Community Confirmation.
  Widget _buildScoreBreakdownRow(HazardReport report, bool isSmallScreen) {
    final bd = report.validationBreakdown;
    // Prefer breakdown values; fall back to top-level model fields.
    final nbScore = (bd?['naive_bayes_score'] as num?)?.toDouble()
        ?? report.naiveBayesScore
        ?? 0.0;
    final distScore = (bd?['distance_weight'] as num?)?.toDouble() ?? 0.0;
    final consScore = (bd?['consensus_score'] as num?)?.toDouble()
        ?? report.consensusScore
        ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Score Breakdown',
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        _buildMiniScoreBar('Text Credibility', nbScore, const Color(0xFF1565C0), isSmallScreen),
        const SizedBox(height: 6),
        _buildMiniScoreBar('Reporter Proximity', distScore, Colors.teal, isSmallScreen),
        const SizedBox(height: 6),
        _buildMiniScoreBar('Community Confirmation', consScore, Colors.purple, isSmallScreen),
      ],
    );
  }

  Widget _buildMiniScoreBar(String label, double score, Color color, bool isSmallScreen) {
    return Row(
      children: [
        SizedBox(
          width: isSmallScreen ? 130 : 160,
          child: Text(
            label,
            style: TextStyle(fontSize: isSmallScreen ? 11 : 12, color: Colors.grey[700]),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 34,
          child: Text(
            '${(score * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// Naive Bayes validation technical breakdown. Simplified for readability.
  List<Widget> _buildNaiveBayesTechnicalDetails(HazardReport report, double validationScore) {
    final breakdown = report.validationBreakdown;
    final prob = breakdown != null
        ? ((breakdown['final_probability'] as num?)?.toDouble() ?? validationScore)
        : validationScore;
    final decision = breakdown?['system_decision'] as String?;
    final distanceMeters = breakdown?['distance_meters'] != null
        ? (breakdown!['distance_meters'] as num).toInt()
        : null;
    final distanceCategory = _formatDistanceCategory(breakdown?['distance_category'] as String?);
    final descLen = breakdown?['description_length'] as int? ?? report.description.length;
    final descCategory = _formatDescriptionCategory(
      breakdown?['description_category'] as String?,
      report.description.length,
    );
    final nearbyCount = breakdown?['nearby_count'] as int?;
    final nearbyCategory = _formatNearbyCategory(breakdown?['nearby_category'] as String?);
    final systemDecisionLabel = _getSystemDecisionLabel(decision, prob);

    return [
      const SizedBox(height: 8),
      // Single summary card: score, decision, threshold
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A8A).withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Confidence Score', style: TextStyle(fontSize: 13, color: Colors.black54)),
                Text(
                  '${(prob * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Decision', style: TextStyle(fontSize: 13, color: Colors.black54)),
                Text(systemDecisionLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      // Features as a compact list (no per-feature “likelihood” line)
      Text('Features used', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
      const SizedBox(height: 6),
      _buildFeatureRow('Hazard type', _formatHazardType(report.hazardType)),
      _buildFeatureRow('Description', '$descLen chars · $descCategory'),
      _buildFeatureRow('Distance', distanceMeters != null ? '$distanceMeters m · $distanceCategory' : 'Not recorded'),
      _buildFeatureRow('Nearby reports', nearbyCount != null ? '$nearbyCount within 150 m · $nearbyCategory' : nearbyCategory),
      _buildFeatureRow('User confirmations', '${breakdown?['confirmation_count'] ?? 0} ${(breakdown?['confirmation_count'] ?? 0) == 1 ? 'user' : 'users'}'),
      const SizedBox(height: 10),
      Text(
        'Score combines text, proximity and community features to estimate report credibility.',
        style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.3),
      ),
      const SizedBox(height: 12),
    ];
  }

  Widget _buildFeatureRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110, 
            child: Text(
              label, 
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              softWrap: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value, 
              style: const TextStyle(fontSize: 12),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  String _getSystemDecisionLabel(String? decision, double prob) {
    if (decision != null) {
      switch (decision) {
        case 'auto_approved':
          return 'Auto-Approved';
        case 'pending':
          return 'Pending (MDRRMO review)';
        case 'rejected':
          return 'Rejected';
      }
    }
    if (prob >= 0.8) return 'Auto-Approved';
    if (prob >= 0.5) return 'Pending (MDRRMO review)';
    return 'Rejected';
  }

  String _formatDistanceCategory(String? c) {
    if (c == null) return '—';
    switch (c) {
      case 'very_near':
        return 'Very Near';
      case 'near':
        return 'Near';
      case 'moderate':
        return 'Moderate';
      case 'far':
        return 'Far';
      default:
        return c;
    }
  }

  String _formatDescriptionCategory(String? c, int len) {
    if (c != null) {
      if (c == 'long') return 'Detailed';
      if (c == 'medium') return 'Medium';
      if (c == 'short') return 'Short';
      return c;
    }
    if (len >= 60) return 'Detailed';
    if (len >= 20) return 'Medium';
    return 'Short';
  }

  String _formatNearbyCategory(String? c) {
    if (c == null) return '—';
    switch (c) {
      case 'none':
        return 'None';
      case 'few':
        return 'Few';
      case 'moderate':
        return 'Moderate';
      case 'many':
        return 'Many';
      default:
        return c;
    }
  }

  String _formatHazardType(String type) {
    if (type.isEmpty) return '—';
    return type.replaceAll('_', ' ').split(' ').map((e) {
      if (e.isEmpty) return e;
      return e[0].toUpperCase() + e.substring(1).toLowerCase();
    }).join(' ');
  }

  Widget _buildAIScoreCard(String title, double score, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '${(score * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _handleApprove,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _handleReject,
                icon: const Icon(Icons.cancel),
                label: const Text('Reject'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Map<String, dynamic> _getAIRecommendation(double naiveBayes, double consensus) {
    // Validation is single Naive Bayes score; consensus parameter kept for API compatibility.
    final score = naiveBayes;
    if (score >= 0.75) {
      return {
        'text': 'RECOMMEND APPROVAL - High confidence report',
        'color': Colors.green,
        'icon': Icons.check_circle,
      };
    } else if (score >= 0.50) {
      return {
        'text': 'REVIEW CAREFULLY - Moderate confidence',
        'color': Colors.orange,
        'icon': Icons.warning_amber,
      };
    } else {
      return {
        'text': 'RECOMMEND REJECTION - Low confidence',
        'color': Colors.red,
        'icon': Icons.cancel,
      };
    }
  }

  Color _getStatusColor(HazardStatus status) {
    switch (status) {
      case HazardStatus.pending:
        return Colors.orange;
      case HazardStatus.approved:
        return Colors.green;
      case HazardStatus.rejected:
        return Colors.red;
    }
  }

  String _getStatusText(HazardStatus status) {
    switch (status) {
      case HazardStatus.pending:
        return 'PENDING';
      case HazardStatus.approved:
        return 'APPROVED';
      case HazardStatus.rejected:
        return 'REJECTED';
    }
  }

  String _formatFullDateTime(DateTime dateTime) {
    return formatManila(dateTime);
  }
}
