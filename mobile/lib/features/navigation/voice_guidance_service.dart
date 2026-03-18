// import 'package:flutter_tts/flutter_tts.dart';  // Temporarily disabled for build compatibility

/// Voice Guidance Service
/// Provides text-to-speech navigation instructions
class VoiceGuidanceService {
  // final FlutterTts _tts = FlutterTts();  // Temporarily disabled
  bool _isEnabled = true;
  bool _isInitialized = false;

  /// Initialize TTS engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // TTS initialization temporarily disabled for build compatibility
      _isInitialized = true;
      print('✅ Voice guidance initialized (TTS temporarily disabled)');
    } catch (e) {
      print('❌ Failed to initialize voice guidance: $e');
    }
  }

  /// Speak navigation instruction
  Future<void> speak(String instruction) async {
    if (!_isEnabled || !_isInitialized) return;

    try {
      // await _tts.speak(instruction);  // Temporarily disabled
      print('🔊 Speaking: $instruction');
    } catch (e) {
      print('❌ Failed to speak: $e');
    }
  }

  /// Speak turn instruction with distance
  Future<void> speakTurnInstruction(String maneuver, double distanceMeters) async {
    if (!_isEnabled || !_isInitialized) return;

    String instruction;

    // Format distance
    String distanceText;
    if (distanceMeters < 100) {
      distanceText = 'in ${distanceMeters.toInt()} meters';
    } else if (distanceMeters < 1000) {
      distanceText = 'in ${(distanceMeters / 100).round() * 100} meters';
    } else {
      distanceText = 'in ${(distanceMeters / 1000).toStringAsFixed(1)} kilometers';
    }

    // Build instruction
    switch (maneuver.toLowerCase()) {
      case 'left':
      case 'turn-left':
      case 'sharp-left':
        instruction = 'Turn left $distanceText';
        break;
      case 'right':
      case 'turn-right':
      case 'sharp-right':
        instruction = 'Turn right $distanceText';
        break;
      case 'straight':
      case 'continue':
        instruction = 'Continue straight $distanceText';
        break;
      case 'arrive':
      case 'destination':
        instruction = 'You have arrived at your destination';
        break;
      case 'u-turn':
        instruction = 'Make a U-turn $distanceText';
        break;
      default:
        instruction = maneuver;
    }

    await speak(instruction);
  }

  /// Speak high-risk warning
  Future<void> speakRiskWarning() async {
    await speak('Warning: You are entering a high-risk area. Rerouting to safer path.');
  }

  /// Speak deviation warning
  Future<void> speakDeviationWarning() async {
    await speak('You have deviated from the route. Recalculating.');
  }

  /// Speak arrival
  Future<void> speakArrival() async {
    await speak('You have arrived at the evacuation center. Stay safe.');
  }

  /// Enable/disable voice guidance
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    print('🔊 Voice guidance ${enabled ? "enabled" : "disabled"}');
  }

  /// Check if voice is enabled
  bool get isEnabled => _isEnabled;

  /// Stop current speech
  Future<void> stop() async {
    try {
      // await _tts.stop();  // Temporarily disabled
    } catch (e) {
      print('❌ Failed to stop speech: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    // _tts.stop();  // Temporarily disabled
  }
}
