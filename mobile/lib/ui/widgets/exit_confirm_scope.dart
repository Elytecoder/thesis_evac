import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps [child] with a back-press guard that shows an "Exit app?" dialog
/// instead of letting Android's back button silently close the app.
///
/// Usage: wrap the root Scaffold of any home/dashboard screen.
///
/// ```dart
/// return ExitConfirmScope(
///   child: Scaffold(...),
/// );
/// ```
class ExitConfirmScope extends StatelessWidget {
  final Widget child;

  const ExitConfirmScope({super.key, required this.child});

  Future<void> _handlePop(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Exit app?'),
          ],
        ),
        content: const Text('Are you sure you want to exit the application?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (Platform.isAndroid) {
        SystemNavigator.pop();
      } else {
        exit(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handlePop(context);
      },
      child: child,
    );
  }
}
