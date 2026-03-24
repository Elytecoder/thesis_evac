/// Limits and feature flags for hazard report media (aligned with backend).
class HazardMediaConfig {
  HazardMediaConfig._();

  /// When true, the app offers MP4 video (max 10 MB / 10 s). Backend uses `HAZARD_VIDEO_UPLOAD`.
  static const bool videoUploadEnabled = true;

  static const int maxImageBytes = 2 * 1024 * 1024;
  static const int maxVideoBytes = 10 * 1024 * 1024;
  static const int maxVideoSeconds = 10;

  static const int imageCompressQuality = 70;
  static const int imageMaxWidth = 1280;

  static const String imageTooLargeMessage = 'Image must be less than 2 MB';
  static const String videoInvalidMessage =
      'Video must be less than 10 MB and 10 seconds long';
}
