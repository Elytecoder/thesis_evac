import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // kIsWeb + Uint8List
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';

/// OSM tile provider that persists tiles to the app's cache directory.
///
/// Behaviour:
///   1. Disk hit  → return cached bytes immediately (works fully offline).
///   2. Disk miss → fetch from OSM, save to disk, return bytes.
///   3. Offline + not cached → return a neutral grey grid placeholder tile
///      so the map still opens without crashing.
///
/// Cache path: `<app-cache>/map_tiles/{z}_{x}_{y}.png`
/// Tiles never auto-expire; they change slowly and the cache is small
/// for a municipal-scale area.
class CachedNetworkTileProvider extends TileProvider {
  static const String _userAgent =
      'EvacuationRouteApp/1.0 (thesis; bulan-sorsogon)';

  final Dio _dio = Dio(
    BaseOptions(
      // Shorter timeouts so a slow OSM tile server doesn't stall the map.
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'User-Agent': _userAgent},
    ),
  );

  Directory? _cacheDir;

  // Pre-warm the cache directory so the first tile requests don't pay the
  // async file-system cost.  Call this once at app startup.
  static CachedNetworkTileProvider? _sharedInstance;

  /// Returns the singleton instance (creates + pre-warms on first call).
  factory CachedNetworkTileProvider.shared() {
    _sharedInstance ??= CachedNetworkTileProvider._();
    _sharedInstance!._warmUpCache();
    return _sharedInstance!;
  }

  CachedNetworkTileProvider() {
    _warmUpCache();
  }

  CachedNetworkTileProvider._();

  void _warmUpCache() {
    // No disk cache on web — nothing to pre-warm.
    if (kIsWeb) return;
    // Fire-and-forget: resolve the directory once so subsequent tile
    // requests hit the in-memory _cacheDir cache immediately.
    _getCacheDir().ignore();
  }

  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final base = await getApplicationCacheDirectory();
    final dir = Directory('${base.path}/map_tiles');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _DiskCachedTileImage(
      url: getTileUrl(coordinates, options),
      tileId: '${coordinates.z}_${coordinates.x}_${coordinates.y}',
      getCacheDir: _getCacheDir,
      dio: _dio,
    );
  }
}

// ---------------------------------------------------------------------------

class _DiskCachedTileImage extends ImageProvider<_DiskCachedTileImage> {
  final String url;
  final String tileId;
  final Future<Directory> Function() getCacheDir;
  final Dio dio;

  const _DiskCachedTileImage({
    required this.url,
    required this.tileId,
    required this.getCacheDir,
    required this.dio,
  });

  @override
  Future<_DiskCachedTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
      _DiskCachedTileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1.0,
      informationCollector: () => [DiagnosticsProperty('URL', url)],
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    // ── Web: dart:io not available — fetch directly from network, no disk cache
    if (kIsWeb) {
      return _fetchFromNetwork(decode, saveToFile: null);
    }

    // ── Native: try disk cache first, fall back to network ─────────────────
    try {
      final dir = await getCacheDir();
      final file = File('${dir.path}/$tileId.png');

      // 1. Cache hit — return immediately without any network request.
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final buf = await ui.ImmutableBuffer.fromUint8List(bytes);
          return decode(buf);
        }
      }

      // 2. Fetch from OSM, persist to disk.
      return _fetchFromNetwork(decode, saveToFile: file);
    } catch (_) {
      // Offline or file-system error — fall through to placeholder.
    }

    // 3. Return a grey grid placeholder tile so the map still opens offline.
    return _greyPlaceholderCodec(decode);
  }

  /// Fetch tile bytes from OSM. If [saveToFile] is non-null (native only),
  /// persist bytes to disk after a successful response.
  Future<ui.Codec> _fetchFromNetwork(
    ImageDecoderCallback decode, {
    required File? saveToFile,
  }) async {
    try {
      final resp = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (resp.statusCode == 200 && resp.data != null) {
        final bytes = Uint8List.fromList(resp.data!);
        if (saveToFile != null) {
          await saveToFile.writeAsBytes(bytes, flush: true);
        }
        final buf = await ui.ImmutableBuffer.fromUint8List(bytes);
        return decode(buf);
      }
    } catch (_) {
      // Network unavailable or server error.
    }
    return _greyPlaceholderCodec(decode);
  }

  /// Draws a 256×256 light-grey tile with a subtle grid so users can see
  /// the map is loading / cached data is being shown in offline mode.
  Future<ui.Codec> _greyPlaceholderCodec(ImageDecoderCallback decode) async {
    try {
      const size = 256.0;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Background fill.
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, size, size),
        ui.Paint()..color = const ui.Color(0xFFE8E8E8),
      );

      // Grid lines every 64 px.
      final linePaint = ui.Paint()
        ..color = const ui.Color(0xFFD0D0D0)
        ..strokeWidth = 0.5;
      for (double i = 64; i < size; i += 64) {
        canvas.drawLine(ui.Offset(i, 0), ui.Offset(i, size), linePaint);
        canvas.drawLine(ui.Offset(0, i), ui.Offset(size, i), linePaint);
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(256, 256);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        final buf = await ui.ImmutableBuffer.fromUint8List(bytes);
        return decode(buf);
      }
    } catch (_) {
      // If even the placeholder fails, let flutter_map handle it.
    }
    // Last resort: propagate so flutter_map can show its own error tile.
    throw Exception('Tile unavailable offline: $url');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _DiskCachedTileImage && url == other.url);

  @override
  int get hashCode => url.hashCode;
}
