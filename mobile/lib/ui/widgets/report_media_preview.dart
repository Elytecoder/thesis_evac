import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/config/api_config.dart';
import '../../models/hazard_report.dart';

bool reportHasMedia(HazardReport r) {
  final p = r.photoUrl?.trim() ?? '';
  final v = r.videoUrl?.trim() ?? '';
  return p.isNotEmpty || v.isNotEmpty;
}

/// Normalise a media URL so it always points to the currently configured backend host.
/// This handles stale URLs stored from a different session/deployment.
/// Public so other screens (e.g. map_screen) can use it directly.
String normalizeMediaUrl(String url) {
  if (url.isEmpty) return url;
  if (!url.startsWith('http')) return url; // data: URL or relative — leave as-is

  try {
    final stored = Uri.parse(url);
    // Derive the expected media host from the configured API base URL
    final apiBase = Uri.parse(ApiConfig.baseUrl);
    if (stored.host == apiBase.host && stored.port == apiBase.port) {
      return url; // Already correct
    }
    // Re-base the path onto the current API host
    final corrected = stored.replace(
      scheme: apiBase.scheme,
      host: apiBase.host,
      port: apiBase.hasPort ? apiBase.port : null,
    );
    return corrected.toString();
  } catch (_) {
    return url;
  }
}

/// Small square preview for list cards (photo only).
Widget reportMediaListThumb(HazardReport report, {double size = 56}) {
  final url = normalizeMediaUrl(report.photoUrl?.trim() ?? '');
  if (url.isEmpty) {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(Icons.perm_media_outlined, size: size * 0.45, color: Colors.grey[500]),
    );
  }
  final child = buildImageFromUrl(url, width: size, height: size, fit: BoxFit.cover);
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(width: size, height: size, child: child),
  );
}

/// Builds an image widget from either a data URL (`data:image/...`) or an HTTP URL.
/// Public so other screens (e.g. map_screen, live_navigation_screen) can reuse it.
Widget buildImageFromUrl(String url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
  // Handle data URLs (base64)
  if (url.startsWith('data:image')) {
    try {
      final i = url.indexOf(',');
      if (i < 0) {
        print('Error: Invalid data URL format (no comma separator)');
        return _brokenImage(width, height);
      }
      final bytes = base64Decode(url.substring(i + 1));
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) {
          print('Error: Failed to decode base64 image');
          return _brokenImage(width, height);
        },
      );
    } catch (e) {
      print('Error: Exception decoding base64 image: $e');
      return _brokenImage(width, height);
    }
  }
  
  // Handle HTTP URLs
  if (url.startsWith('http://') || url.startsWith('https://')) {
    print('Loading image from URL: $url');
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
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('Error loading image from $url: $error');
        return _brokenImage(width, height);
      },
    );
  }
  
  print('Error: Unsupported URL format: ${url.substring(0, url.length > 50 ? 50 : url.length)}');
  return _brokenImage(width, height);
}

Widget _brokenImage(double? width, double? height) {
  return Container(
    width: width,
    height: height,
    color: Colors.grey[300],
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image_outlined, color: Colors.grey[600], size: 32),
        const SizedBox(height: 4),
        Text(
          'Image unavailable',
          style: TextStyle(color: Colors.grey[700], fontSize: 11),
        ),
      ],
    ),
  );
}

/// Opens the image full-screen in a modal overlay
void _openFullscreenImage(BuildContext context, String url) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FullscreenImageViewer(url: url),
    ),
  );
}

class _FullscreenImageViewer extends StatelessWidget {
  final String url;

  const _FullscreenImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Photo'),
        actions: [
          if (url.startsWith('http'))
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open in browser',
              onPressed: () async {
                final uri = Uri.tryParse(url);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: buildImageFromUrl(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// Full-width photo + video actions for report detail.
class ReportMediaSection extends StatelessWidget {
  final HazardReport report;

  const ReportMediaSection({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final photo = normalizeMediaUrl(report.photoUrl?.trim() ?? '');
    final video = normalizeMediaUrl(report.videoUrl?.trim() ?? '');
    if (photo.isEmpty && video.isEmpty) {
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
        if (photo.isNotEmpty) ...[
          GestureDetector(
            onTap: () => _openFullscreenImage(context, photo),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 220,
                    child: buildImageFromUrl(photo, fit: BoxFit.contain),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Tap to enlarge', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (video.isNotEmpty) _VideoRow(url: video),
      ],
    );
  }
}

class _VideoRow extends StatefulWidget {
  final String url;

  const _VideoRow({required this.url});

  @override
  State<_VideoRow> createState() => _VideoRowState();
}

class _VideoRowState extends State<_VideoRow> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _error = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      VideoPlayerController ctrl;

      if (widget.url.startsWith('data:video')) {
        if (kIsWeb) {
          // Web: pass data URL directly to the HTML5 video element
          ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
        } else {
          // Mobile: decode base64 → temp file
          final i = widget.url.indexOf(',');
          if (i < 0) {
            setState(() { _error = true; _loading = false; });
            return;
          }
          final bytes = base64Decode(widget.url.substring(i + 1));
          final dir = await getTemporaryDirectory();
          final file = File(
            '${dir.path}/hzv_${DateTime.now().millisecondsSinceEpoch}.mp4',
          );
          await file.writeAsBytes(bytes, flush: true);
          ctrl = VideoPlayerController.file(file);
        }
      } else if (widget.url.startsWith('http://') ||
          widget.url.startsWith('https://')) {
        ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      } else {
        setState(() { _error = true; _loading = false; });
        return;
      }

      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return; }
      setState(() {
        _controller = ctrl;
        _initialized = true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              SizedBox(height: 10),
              Text('Loading video…',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_error) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.videocam_off, color: Colors.red.shade400),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Video could not be loaded.',
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ),
            if (widget.url.startsWith('http'))
              TextButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(widget.url);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open'),
              ),
          ],
        ),
      );
    }

    final ctrl = _controller!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video frame
          AspectRatio(
            aspectRatio: ctrl.value.aspectRatio,
            child: VideoPlayer(ctrl),
          ),
          // Play/pause overlay
          GestureDetector(
            onTap: _togglePlayPause,
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: ctrl,
              builder: (_, value, __) {
                return AnimatedOpacity(
                  opacity: value.isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                );
              },
            ),
          ),
          // Bottom progress bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: ctrl,
              builder: (_, value, __) {
                return VideoProgressIndicator(
                  ctrl,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.blue,
                    bufferedColor: Colors.white30,
                    backgroundColor: Colors.black26,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
