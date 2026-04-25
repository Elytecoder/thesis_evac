import 'package:flutter/material.dart';

/// Modal dialog shown when similar hazard reports are found.
/// 
/// Allows user to either:
/// - Confirm an existing report (recommended)
/// - Submit a new report anyway
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

  @override
  Widget build(BuildContext context) {
    // Find the most confirmed report
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
                      : () {
                          Navigator.pop(context);
                          onConfirmExisting(reportId, mostConfirmed);
                        },
                  icon: const Icon(Icons.check_circle),
                  label: Text(
                    hasUserConfirmed
                        ? 'Already Confirmed'
                        : 'Confirm Existing Hazard (Recommended)',
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
