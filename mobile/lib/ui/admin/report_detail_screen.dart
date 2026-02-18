import 'package:flutter/material.dart';
import '../../features/admin/admin_mock_service.dart';
import '../../models/hazard_report.dart';

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
  final AdminMockService _adminService = AdminMockService();
  final TextEditingController _commentController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleApprove() async {
    final confirm = await _showConfirmDialog(
      'Approve Report',
      'Are you sure you want to approve this hazard report?',
      Colors.green,
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);

      try {
        await _adminService.approveReport(
          widget.report.id ?? 0,
          comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
        );

        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate update
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report approved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to approve: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleReject() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for rejection'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await _showConfirmDialog(
      'Reject Report',
      'Are you sure you want to reject this hazard report?',
      Colors.red,
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);

      try {
        await _adminService.rejectReport(
          widget.report.id ?? 0,
          comment: _commentController.text.trim(),
        );

        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate update
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report rejected'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reject: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<bool?> _showConfirmDialog(String title, String message, Color color) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: color),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
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

  Widget _buildMapPreview() {
    return Container(
      height: 200,
      color: Colors.grey[300],
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 48, color: Colors.grey[600]),
                const SizedBox(height: 8),
                Text(
                  'Map Preview',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.report.latitude.toStringAsFixed(6)}, ${widget.report.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Full map view coming soon'),
                  ),
                );
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.open_in_full, color: Color(0xFF1E3A8A)),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Hazard Type', report.hazardType.toUpperCase().replaceAll('_', ' ')),
        _buildInfoRow('Report ID', '#${report.id ?? 0}'),
        _buildInfoRow('Reporter ID', 'User #${report.userId ?? 0}'),
        _buildInfoRow('Submitted', _formatFullDateTime(report.createdAt ?? DateTime.now())),
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

        if (report.photoUrl != null || report.videoUrl != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Uploaded Media',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (report.photoUrl != null)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image, size: 32, color: Colors.white),
                ),
              if (report.videoUrl != null) ...[
                const SizedBox(width: 8),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.videocam, size: 32, color: Colors.white),
                ),
              ],
            ],
          ),
        ],
      ],
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

  Widget _buildAIAnalysis() {
    final report = widget.report;
    final aiRecommendation = _getAIRecommendation(report.naiveBayesScore ?? 0.0, report.consensusScore ?? 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAIScoreCard(
          'Naive Bayes Confidence',
          report.naiveBayesScore ?? 0.0,
          'Validates report authenticity based on text patterns',
          Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildAIScoreCard(
          'Consensus Score',
          report.consensusScore ?? 0.0,
          'Agreement level from multiple validation sources',
          Colors.purple,
        ),
        const SizedBox(height: 12),
        _buildAIScoreCard(
          'Random Forest Risk',
          0.75, // Mock risk level
          'Predicted hazard severity and impact assessment',
          Colors.orange,
        ),
        
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: aiRecommendation['color'].withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: aiRecommendation['color'],
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                aiRecommendation['icon'],
                color: aiRecommendation['color'],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Recommendation',
                      style: TextStyle(
                        fontSize: 12,
                        color: aiRecommendation['color'],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      aiRecommendation['text'],
                      style: TextStyle(
                        fontSize: 14,
                        color: aiRecommendation['color'],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
        TextField(
          controller: _commentController,
          decoration: InputDecoration(
            labelText: 'Comment (Optional for approval, Required for rejection)',
            hintText: 'Add any notes or reasons for your decision...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          maxLines: 3,
          enabled: !_isProcessing,
        ),
        
        const SizedBox(height: 16),
        
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
    final avgScore = (naiveBayes + consensus) / 2;

    if (avgScore >= 0.75) {
      return {
        'text': 'RECOMMEND APPROVAL - High confidence report',
        'color': Colors.green,
        'icon': Icons.check_circle,
      };
    } else if (avgScore >= 0.50) {
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
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
