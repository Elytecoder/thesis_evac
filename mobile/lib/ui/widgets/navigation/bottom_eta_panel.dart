import 'package:flutter/material.dart';
import '../../../models/navigation_route.dart';

/// Bottom ETA panel with slide-up animation
/// Shows arrival time, duration, distance, and controls
class BottomETAPanel extends StatelessWidget {
  final NavigationRoute? route;
  final bool voiceEnabled;
  final VoidCallback onVoiceToggle;
  final VoidCallback onCancel;

  const BottomETAPanel({
    super.key,
    required this.route,
    required this.voiceEnabled,
    required this.onVoiceToggle,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 0.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, value * 150),
          child: Opacity(
            opacity: 1 - value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Main info section with clear labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ETA
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ETA',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getArrivalTime(),
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Time left and Distance left in a row
                  Row(
                    children: [
                      // Time left
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Time left',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  route?.getFormattedETA() ?? '--',
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Distance left
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.straighten,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Distance left',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  route?.getFormattedDistance() ?? '--',
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
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
            ),
            
            const SizedBox(width: 12),
            
            // Voice toggle button
            Material(
              color: voiceEnabled ? Colors.blue : Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onVoiceToggle,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  child: Icon(
                    voiceEnabled ? Icons.volume_up : Icons.volume_off,
                    color: voiceEnabled ? Colors.white : Colors.grey[600],
                    size: 24,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Cancel button
            Material(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onCancel,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getArrivalTime() {
    if (route == null) return '--:--';
    
    final now = DateTime.now();
    final arrivalTime = now.add(Duration(seconds: route!.estimatedTimeSeconds));
    
    final hour = arrivalTime.hour;
    final minute = arrivalTime.minute.toString().padLeft(2, '0');
    
    return '$hour:$minute';
  }
}
