import 'package:flutter/material.dart';
import '../../../models/navigation_step.dart';

/// Top instruction banner with smooth animations
/// Mimics Waze/Google Maps style
class TopInstructionBanner extends StatelessWidget {
  final NavigationStep? currentStep;
  final double distanceToNext;

  const TopInstructionBanner({
    super.key,
    required this.currentStep,
    required this.distanceToNext,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(currentStep?.stepIndex ?? 0),
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            // Turn icon
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _getManeuverIcon(currentStep?.maneuver ?? 'straight'),
                  color: Colors.blue,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Instruction text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Distance (large)
                  Text(
                    _formatDistance(distanceToNext),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Street name (colored)
                  Text(
                    currentStep?.instruction ?? 'Continue',
                    style: TextStyle(
                      color: Colors.blue[300],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getManeuverIcon(String maneuver) {
    switch (maneuver.toLowerCase()) {
      case 'left':
      case 'turn-left':
      case 'sharp-left':
        return Icons.turn_left;
      case 'right':
      case 'turn-right':
      case 'sharp-right':
        return Icons.turn_right;
      case 'straight':
      case 'continue':
        return Icons.arrow_upward;
      case 'arrive':
      case 'destination':
        return Icons.location_on;
      case 'u-turn':
        return Icons.u_turn_left;
      default:
        return Icons.navigation;
    }
  }

  String _formatDistance(double meters) {
    if (meters < 100) {
      return '${meters.toInt()} m';
    } else if (meters < 1000) {
      return '${(meters / 100).round() * 100} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }
}
