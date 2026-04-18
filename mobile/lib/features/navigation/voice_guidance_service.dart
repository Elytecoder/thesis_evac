import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

/// Text-to-speech navigation. Only speaks when [shouldAttemptVoice] is true
/// (user preference + initialized) **and** internet is available (cached probe).
class VoiceGuidanceService {
  VoiceGuidanceService();

  final FlutterTts _tts = FlutterTts();

  bool _isInitialized = false;
  bool _userWantsVoice = true;
  bool _sessionEnabled = true;

  DateTime? _internetCacheTime;
  bool? _internetCached;

  String? _lastSpokenText;
  DateTime? _lastSpokenAt;
  static const Duration _dedupeWindow = Duration(seconds: 6);
  static const Duration _internetCacheTtl = Duration(seconds: 4);

  /// User setting from Settings + in-nav toggle (both gate speech).
  bool get shouldAttemptVoice =>
      _userWantsVoice && _sessionEnabled && _isInitialized && !kIsWeb;

  /// Initialize TTS engine (English, moderate speed, moderate volume).
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(0.55);
      await _tts.setPitch(1.0);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.duckOthers,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Voice guidance init failed: $e');
      _isInitialized = false;
    }
  }

  /// Cached reachability check (no voice when offline).
  Future<bool> _internetAvailable() async {
    final now = DateTime.now();
    if (_internetCacheTime != null &&
        now.difference(_internetCacheTime!) < _internetCacheTtl &&
        _internetCached != null) {
      return _internetCached!;
    }
    _internetCacheTime = now;
    try {
      final u = Uri.parse('https://connectivitycheck.gstatic.com/generate_204');
      final r = await http.head(u).timeout(const Duration(seconds: 2));
      _internetCached = r.statusCode == 204 || r.statusCode == 200;
    } catch (_) {
      try {
        final u2 = Uri.parse('https://www.google.com');
        final r2 = await http.head(u2).timeout(const Duration(seconds: 2));
        _internetCached = r2.statusCode < 500;
      } catch (_) {
        _internetCached = false;
      }
    }
    return _internetCached ?? false;
  }

  bool _shouldSkipDuplicate(String text) {
    final now = DateTime.now();
    if (_lastSpokenText == text &&
        _lastSpokenAt != null &&
        now.difference(_lastSpokenAt!) < _dedupeWindow) {
      return true;
    }
    _lastSpokenText = text;
    _lastSpokenAt = now;
    return false;
  }

  /// Stop current speech before starting another (no overlap).
  Future<void> stop() async {
    if (kIsWeb || !_isInitialized) return;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Speak raw instruction if online and enabled.
  Future<void> speak(String instruction) async {
    final text = instruction.trim();
    if (text.isEmpty) return;
    if (!shouldAttemptVoice) return;
    if (!await _internetAvailable()) return;
    if (_shouldSkipDuplicate(text)) return;

    try {
      await stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  /// Short imminent prompt without distance (e.g. "Turn left").
  Future<void> speakImminentTurn(String maneuver) async {
    if (!shouldAttemptVoice) return;
    if (!await _internetAvailable()) return;

    final m = maneuver.toLowerCase();
    String instruction;
    switch (m) {
      case 'left':
      case 'turn-left':
        instruction = 'Turn left';
        break;
      case 'sharp-left':
        instruction = 'Turn sharp left';
        break;
      case 'slight-left':
      case 'fork-left':
        instruction = 'Keep left';
        break;
      case 'right':
      case 'turn-right':
        instruction = 'Turn right';
        break;
      case 'sharp-right':
        instruction = 'Turn sharp right';
        break;
      case 'slight-right':
      case 'fork-right':
        instruction = 'Keep right';
        break;
      case 'straight':
      case 'continue':
        instruction = 'Continue straight';
        break;
      case 'u-turn':
        instruction = 'Make a U-turn';
        break;
      case 'roundabout':
        instruction = 'Enter the roundabout';
        break;
      case 'roundabout-exit':
        instruction = 'Exit the roundabout';
        break;
      default:
        instruction = maneuver;
    }
    if (_shouldSkipDuplicate(instruction)) return;
    try {
      await stop();
      await _tts.speak(instruction);
    } catch (e) {
      debugPrint('TTS imminent failed: $e');
    }
  }

  /// Speak turn instruction with distance ("Turn left in 50 meters").
  Future<void> speakTurnInstruction(String maneuver, double distanceMeters) async {
    if (!shouldAttemptVoice) return;
    if (!await _internetAvailable()) return;

    String distanceText;
    if (distanceMeters < 100) {
      distanceText = 'in ${distanceMeters.toInt()} meters';
    } else if (distanceMeters < 1000) {
      final rounded = (distanceMeters / 10).round() * 10;
      distanceText = 'in $rounded meters';
    } else {
      distanceText = 'in ${(distanceMeters / 1000).toStringAsFixed(1)} kilometers';
    }

    String instruction;
    switch (maneuver.toLowerCase()) {
      case 'left':
      case 'turn-left':
        instruction = 'Turn left $distanceText';
        break;
      case 'sharp-left':
        instruction = 'Turn sharp left $distanceText';
        break;
      case 'slight-left':
      case 'fork-left':
        instruction = 'Keep left $distanceText';
        break;
      case 'right':
      case 'turn-right':
        instruction = 'Turn right $distanceText';
        break;
      case 'sharp-right':
        instruction = 'Turn sharp right $distanceText';
        break;
      case 'slight-right':
      case 'fork-right':
        instruction = 'Keep right $distanceText';
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
      case 'roundabout':
        instruction = 'Enter the roundabout $distanceText';
        break;
      case 'roundabout-exit':
        instruction = 'Exit the roundabout $distanceText';
        break;
      default:
        instruction = '$maneuver $distanceText';
    }

    if (_shouldSkipDuplicate(instruction)) return;
    try {
      await stop();
      await _tts.speak(instruction);
    } catch (e) {
      debugPrint('TTS turn failed: $e');
    }
  }

  Future<void> speakRiskWarning() async {
    await speak(
      'Warning: You are entering a high-risk area. Rerouting to a safer path.',
    );
  }

  Future<void> speakDeviationWarning() async {
    await speak('You have left the route. Recalculating.');
  }

  Future<void> speakArrival() async {
    await speak('You have arrived at your destination. Stay safe.');
  }

  /// In-screen toggle during navigation (also persisted by the screen).
  void setSessionEnabled(bool enabled) {
    _sessionEnabled = enabled;
  }

  /// Settings / preference: master switch for voice navigation.
  void setUserWantsVoice(bool wants) {
    _userWantsVoice = wants;
    if (!wants) {
      stop();
    }
  }

  bool get userWantsVoice => _userWantsVoice;

  void setEnabled(bool enabled) {
    setSessionEnabled(enabled);
  }

  bool get isEnabled => _sessionEnabled;

  void dispose() {
    if (!kIsWeb) {
      _tts.stop();
    }
  }
}
