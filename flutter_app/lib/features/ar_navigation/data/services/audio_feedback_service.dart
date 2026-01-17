import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

/// Audio Feedback Service
/// Handles text-to-speech for navigation instructions and audio cues
class AudioFeedbackService {
  static final AudioFeedbackService _instance = AudioFeedbackService._internal();
  late final FlutterTts _flutterTts;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  // Singleton pattern
  factory AudioFeedbackService() {
    return _instance;
  }

  AudioFeedbackService._internal() {
    _flutterTts = FlutterTts();
  }

  /// Initialize the TTS engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(1.0);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        debugPrint('🔊 Audio started');
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        debugPrint('🔊 Audio completed');
      });

      _flutterTts.setErrorHandler((message) {
        _isSpeaking = false;
        debugPrint('🔊 Audio error: $message');
      });

      _isInitialized = true;
      debugPrint('✅ Audio feedback service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize audio service: $e');
    }
  }

  /// Speak navigation instruction
  Future<void> speakInstruction(String instruction) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Clean up instruction text for better TTS
      final cleanText = _cleanTextForTTS(instruction);
      debugPrint('🔊 Speaking: $cleanText');
      await _flutterTts.speak(cleanText);
    } catch (e) {
      debugPrint('❌ Error speaking instruction: $e');
    }
  }

  /// Speak distance to destination
  Future<void> speakDistance(double meters) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final distance = _formatDistance(meters);
      final text = 'Continue for $distance';
      debugPrint('🔊 Speaking: $text');
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('❌ Error speaking distance: $e');
    }
  }

  /// Speak direction to turn
  Future<void> speakDirection(String direction) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final directionText = _formatDirection(direction);
      debugPrint('🔊 Speaking: $directionText');
      await _flutterTts.speak(directionText);
    } catch (e) {
      debugPrint('❌ Error speaking direction: $e');
    }
  }

  /// Announce milestone reached
  Future<void> announceMilestone(String milestoneName) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final text = 'You have reached $milestoneName';
      debugPrint('🔊 Speaking: $text');
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('❌ Error announcing milestone: $e');
    }
  }

  /// Announce arrival at destination
  Future<void> announceArrival(String destinationName) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final text = 'You have arrived at $destinationName';
      debugPrint('🔊 Speaking: $text');
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('❌ Error announcing arrival: $e');
    }
  }

  /// Speak warning message
  Future<void> speakWarning(String message) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      debugPrint('🔊 Warning: $message');
      await _flutterTts.speak(message);
    } catch (e) {
      debugPrint('❌ Error speaking warning: $e');
    }
  }

  /// Stop current speech
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint('❌ Error stopping speech: $e');
    }
  }

  /// Check if currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Get initialization status
  bool get isInitialized => _isInitialized;

  /// Clean text for better TTS pronunciation
  String _cleanTextForTTS(String text) {
    // Remove special characters and extra spaces
    String cleaned = text.replaceAll(RegExp(r'[^a-zA-Z0-9\s,.!?-]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  /// Format distance for speech
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} meters';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} kilometers';
    }
  }

  /// Format direction for speech
  String _formatDirection(String direction) {
    switch (direction.toUpperCase()) {
      case 'N':
        return 'north';
      case 'NE':
        return 'northeast';
      case 'E':
        return 'east';
      case 'SE':
        return 'southeast';
      case 'S':
        return 'south';
      case 'SW':
        return 'southwest';
      case 'W':
        return 'west';
      case 'NW':
        return 'northwest';
      default:
        return direction;
    }
  }

  /// Dispose resources
  void dispose() {
    _flutterTts.stop();
  }
}
