import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../core/config/hazard_media_config.dart';

class HazardMediaValidationException implements Exception {
  HazardMediaValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Result of client-side image preparation (compressed JPEG bytes for upload).
class PreparedHazardImage {
  PreparedHazardImage({required this.bytes, this.filename = 'hazard.jpg'});
  final Uint8List bytes;
  final String filename;
}

bool hazardImageNameAllowed(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png');
}

/// Validates original size and format, compresses (~70% quality, max width 1280).
Future<PreparedHazardImage> prepareImageForUpload(XFile file) async {
  if (!hazardImageNameAllowed(file.name)) {
    throw HazardMediaValidationException(
      'Use a JPG, JPEG, or PNG image.',
    );
  }
  final raw = await file.readAsBytes();
  if (raw.length > HazardMediaConfig.maxImageBytes) {
    throw HazardMediaValidationException(HazardMediaConfig.imageTooLargeMessage);
  }

  Uint8List? compressed;
  try {
    compressed = await FlutterImageCompress.compressWithList(
      raw,
      quality: HazardMediaConfig.imageCompressQuality,
      minWidth: HazardMediaConfig.imageMaxWidth,
      minHeight: 0,
      format: CompressFormat.jpeg,
    );
  } catch (_) {
    compressed = null;
  }
  if (compressed == null || compressed.isEmpty) {
    throw HazardMediaValidationException('Could not process image.');
  }
  if (compressed.length > HazardMediaConfig.maxImageBytes) {
    throw HazardMediaValidationException(HazardMediaConfig.imageTooLargeMessage);
  }
  return PreparedHazardImage(bytes: compressed, filename: 'hazard.jpg');
}

/// When [HazardMediaConfig.videoUploadEnabled], validates MP4 extension and size.
/// Duration is constrained by the picker [maxDuration] and by the server (ffprobe when available).
Future<void> validateVideoForUpload(XFile file) async {
  final name = file.name.toLowerCase();
  if (!name.endsWith('.mp4')) {
    throw HazardMediaValidationException(HazardMediaConfig.videoInvalidMessage);
  }
  final len = await file.length();
  if (len > HazardMediaConfig.maxVideoBytes) {
    throw HazardMediaValidationException(HazardMediaConfig.videoInvalidMessage);
  }
}
