import 'package:flutter/material.dart';

/// Modal dialog shown when a similar hazard report already exists nearby.
///
/// Shows only public, non-identifying information:
/// - Formatted hazard type (e.g. "Fallen Electric Post")
/// - Approximate distance
/// - Status (Pending Verification / Verified)
/// - Confirmation count
///
/// Does NOT expose: description, reporter identity, media, AI scores, timestamps.
class HazardConfirmationDialog extends StatelessWidget {
  final List<Map<String, dynamic>> similarReports;
  final VoidCallback onSubmitNew;
  final Function(int reportId, Map<String, dynamic> reportData) onConfirmExisting;

  const HazardConfirmationDialog({
    Key? key,
    required this.similarReports,
    required this.onSubmitNew,
    required this.onConfirmExisting,
  }) : super(key: key);

  /// Convert raw snake_case hazard type to a human-readable label.
  static String _formatType(String raw) {
    if (raw.trim().isEmpty) return 'Unknown Hazard';
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    // Prioritise already-approved (verified) reports; then most-confirmed pending ones.
    final mostRelevant = similarReports.reduce((a, b) {
      final aApproved = a['is_approved'] as bool? ?? false;
      final bApproved = b['is_approved'] as bool? ?? false;
      if (aApproved && !bApproved) return a;
      if (!aApproved && bApproved) return b;
      final aCount = a['confirmation_count'] as int? ?? 0;
      final bCount = b['confirmation_count'] as int? ?? 0;
      return aCount > bCount ? a : b;
    });

    final reportId = (mostRelevant['id'] as num?)?.toInt() ?? 0;
    final rawType = mostRelevant['hazard_type'] as String? ?? '';
    final displayType = _formatType(rawType);
    final distance = mostRelevant['distance_meters'] as num? ?? 0;
    final confirmationCount = mostRelevant['confirmation_count'] as int? ?? 0;
    final hasUserConfirmed = mostRelevant['has_user_confirmed'] as bool? ?? false;
    final isApproved = mostRelevant['is_approved'] as bool? ?? false;

    final statusLabel = isApproved ? 'Verified' : 'Pending Verification';
    final statusColor = isApproved ? Colors.green : Colors.orange;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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

            // Explanation message
            Text(
              isApproved
                  ? 'This hazard has already been verified nearby. Would you like to confirm it?'
                  : 'A similar hazard has already been reported nearby. Would you like to confirm this hazard instead?',
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),

            const SizedBox(height: 20),

            // Public report summary card — no private details
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
                      displayType,
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Distance + confirmations
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

            // Already confirmed notice
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
                        'You have already confirmed this hazard.',
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
                // Confirm button
                ElevatedButton.icon(
                  onPressed: hasUserConfirmed
                      ? null
                      : () {
                          Navigator.pop(context);
                          onConfirmExisting(reportId, mostRelevant);
                        },
                  icon: const Icon(Icons.check_circle),
                  label: Text(
                    hasUserConfirmed
                        ? 'Already Confirmed'
                        : 'Confirm This Hazard (Recommended)',
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

                // Submit new report anyway
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onSubmitNew();
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

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show the confirmation dialog.
  static Future<void> show({
    required BuildContext context,
    required List<Map<String, dynamic>> similarReports,
    required VoidCallback onSubmitNew,
    required Function(int reportId, Map<String, dynamic> reportData) onConfirmExisting,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => HazardConfirmationDialog(
        similarReports: similarReports,
        onSubmitNew: onSubmitNew,
        onConfirmExisting: onConfirmExisting,
      ),
    );
  }
}
