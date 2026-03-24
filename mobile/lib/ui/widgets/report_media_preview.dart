import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/hazard_report.dart';

bool reportHasMedia(HazardReport r) {
  final p = r.photoUrl?.trim() ?? '';
  final v = r.videoUrl?.trim() ?? '';
  return p.isNotEmpty || v.isNotEmpty;
}

/// Small square preview for list cards (photo only).
Widget reportMediaListThumb(HazardReport report, {double size = 56}) {
  final url = report.photoUrl?.trim();
  if (url == null || url.isEmpty) {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(Icons.perm_media_outlined, size: size * 0.45, color: Colors.grey[500]),
    );
  }
  final child = _buildImageFromUrl(url, width: size, height: size, fit: BoxFit.cover);
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(width: size, height: size, child: child),
  );
}

Widget _buildImageFromUrl(String url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
  if (url.startsWith('data:image')) {
    try {
      final i = url.indexOf(',');
      if (i < 0) return _brokenImage(width, height);
      final bytes = base64Decode(url.substring(i + 1));
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _brokenImage(width, height),
      );
    } catch (_) {
      return _brokenImage(width, height);
    }
  }
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(
          width: width,
          height: height,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (_, __, ___) => _brokenImage(width, height),
    );
  }
  return _brokenImage(width, height);
}

Widget _brokenImage(double? width, double? height) {
  return Container(
    width: width,
    height: height,
    color: Colors.grey[300],
    child: Icon(Icons.broken_image_outlined, color: Colors.grey[600]),
  );
}

/// Full-width photo + video actions for report detail.
class ReportMediaSection extends StatelessWidget {
  final HazardReport report;

  const ReportMediaSection({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final photo = report.photoUrl?.trim();
    final video = report.videoUrl?.trim();
    if ((photo == null || photo.isEmpty) && (video == null || video.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Uploaded Media',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        if (photo != null && photo.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: double.infinity,
              height: 220,
              child: _buildImageFromUrl(photo, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (video != null && video.isNotEmpty) _VideoRow(url: video),
      ],
    );
  }
}

class _VideoRow extends StatelessWidget {
  final String url;

  const _VideoRow({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return OutlinedButton.icon(
        onPressed: () async {
          final uri = Uri.tryParse(url);
          if (uri == null) return;
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open video link')),
            );
          }
        },
        icon: const Icon(Icons.open_in_new),
        label: const Text('Open video in browser'),
      );
    }
    if (url.startsWith('data:video')) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blueGrey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.videocam, color: Colors.blueGrey.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Video is attached (embedded). Use approved export or future file download to retrieve the full file.',
                style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade800),
              ),
            ),
          ],
        ),
      );
    }
    return Text(
      'Video reference: ${url.length > 80 ? '${url.substring(0, 80)}…' : url}',
      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
    );
  }
}
