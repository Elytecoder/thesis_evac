import 'package:flutter/material.dart';
import '../../../models/navigation_route.dart';

/// Bottom navigation info panel with slide-up animation.
/// Shows remaining distance and route risk level — no ETA displayed.
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
          child: Opacity(opacity: 1 - value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Distance remaining (prominent)
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.straighten_rounded,
                        size: 20, color: Colors.blue[700]),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Distance remaining',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        route?.getFormattedDistance() ?? '—',
                        style: TextStyle(
                          color: Colors.grey[900],
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Cancel button
            Material(
              color: Colors.red[600],
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onCancel,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
