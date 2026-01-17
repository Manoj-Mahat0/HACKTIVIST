import 'package:flutter_tts/flutter_tts.dart';

class AudioFeedbackService {
  static final AudioFeedbackService _instance = AudioFeedbackService._internal();
  factory AudioFeedbackService() => _instance;
  AudioFeedbackService._internal();

  FlutterTts? _flutterTts;

  Future<void> initialize() async {
    _flutterTts = FlutterTts();
    await _flutterTts!.setLanguage("en-US");
    await _flutterTts!.setSpeechRate(0.45);
    await _flutterTts!.setVolume(1.0);
    await _flutterTts!.setPitch(1.0);
  }

  Future<void> speakInstruction(String instruction) async {
    if (_flutterTts != null) {
      await _flutterTts!.speak(instruction);
    }
  }

  Future<void> speakDistance(double meters) async {
    if (_flutterTts != null) {
      String distanceText;
      if (meters >= 1000) {
        distanceText = 'In ${(meters / 1000).toStringAsFixed(1)} kilometers';
      } else {
        distanceText = 'In ${meters.round()} meters';
      }
      await _flutterTts!.speak(distanceText);
    }
  }

  Future<void> speakDirection(String direction) async {
    if (_flutterTts != null) {
      String directionText = _formatDirection(direction);
      await _flutterTts!.speak(directionText);
    }
  }

  Future<void> announceMilestone(String name) async {
    if (_flutterTts != null) {
      await _flutterTts!.speak('You have reached $name');
    }
  }

  Future<void> announceArrival(String destination) async {
    if (_flutterTts != null) {
      await _flutterTts!.speak('You have arrived at your destination: $destination');
    }
  }

  Future<void> stop() async {
    if (_flutterTts != null) {
      await _flutterTts!.stop();
    }
  }

  String _formatDirection(String direction) {
    switch (direction.toUpperCase()) {
      case 'N':
        return 'Go north';
      case 'S':
        return 'Go south';
      case 'E':
        return 'Go east';
      case 'W':
        return 'Go west';
      case 'NE':
        return 'Go northeast';
      case 'NW':
        return 'Go northwest';
      case 'SE':
        return 'Go southeast';
      case 'SW':
        return 'Go southwest';
      case 'UP':
        return 'Go upstairs';
      case 'DOWN':
        return 'Go downstairs';
      default:
        return 'Continue straight';
    }
  }
}