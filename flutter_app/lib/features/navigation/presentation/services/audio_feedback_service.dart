import 'package:flutter_tts/flutter_tts.dart';

/// Service for providing audio feedback during navigation
class AudioFeedbackService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isEnabled = true;

  // Callbacks
  Function()? onSpeakStart;
  Function()? onSpeakComplete;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5); // Slightly slower for clarity
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Set up handlers
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        onSpeakStart?.call();
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        onSpeakComplete?.call();
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        print('TTS Error: $msg');
      });

      _isInitialized = true;
      print('✅ Audio feedback service initialized');
    } catch (e) {
      print('❌ Failed to initialize TTS: $e');
    }
  }

  Future<void> dispose() async {
    await stop();
    _isInitialized = false;
  }

  /// Enable or disable audio feedback
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled && _isSpeaking) {
      stop();
    }
  }

  bool get isEnabled => _isEnabled;
  bool get isSpeaking => _isSpeaking;

  /// Speak a custom message
  Future<void> speak(String text) async {
    if (!_isEnabled || !_isInitialized) return;

    try {
      await stop(); // Stop any current speech
      await _flutterTts.speak(text);
    } catch (e) {
      print('❌ Failed to speak: $e');
    }
  }

  /// Stop current speech
  Future<void> stop() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      _isSpeaking = false;
    }
  }

  /// Announce navigation start
  Future<void> announceNavigationStart(String destination) async {
    await speak('Starting navigation to $destination');
  }

  /// Announce direction change
  Future<void> announceDirection(String direction, double distance) async {
    final distanceText = _formatDistance(distance);
    String instruction;

    switch (direction.toUpperCase()) {
      case 'N':
        instruction = 'Continue straight ahead for $distanceText';
        break;
      case 'S':
        instruction = 'Turn around and go $distanceText';
        break;
      case 'E':
        instruction = 'Turn right and continue for $distanceText';
        break;
      case 'W':
        instruction = 'Turn left and continue for $distanceText';
        break;
      case 'NE':
        instruction = 'Turn slightly right and go $distanceText';
        break;
      case 'NW':
        instruction = 'Turn slightly left and go $distanceText';
        break;
      case 'SE':
        instruction = 'Turn sharp right and go $distanceText';
        break;
      case 'SW':
        instruction = 'Turn sharp left and go $distanceText';
        break;
      case 'UP':
        instruction = 'Go upstairs';
        break;
      case 'DOWN':
        instruction = 'Go downstairs';
        break;
      default:
        instruction = 'Continue for $distanceText';
    }

    await speak(instruction);
  }

  /// Announce milestone reached
  Future<void> announceMilestone(int current, int total, String nextLocation) async {
    await speak('Waypoint $current of $total. Heading to $nextLocation');
  }

  /// Announce approaching destination
  Future<void> announceApproaching(String destination, double distance) async {
    final distanceText = _formatDistance(distance);
    await speak('Approaching $destination in $distanceText');
  }

  /// Announce arrival at destination
  Future<void> announceArrival(String destination) async {
    await speak('You have arrived at $destination');
  }

  /// Announce off-route
  Future<void> announceOffRoute() async {
    await speak('You are off route. Recalculating');
  }

  /// Announce route recalculated
  Future<void> announceRouteRecalculated() async {
    await speak('New route calculated');
  }

  /// Announce distance to next waypoint
  Future<void> announceDistance(double distance) async {
    final distanceText = _formatDistance(distance);
    await speak('$distanceText to next waypoint');
  }

  /// Announce floor change
  Future<void> announceFloorChange(int fromFloor, int toFloor) async {
    if (toFloor > fromFloor) {
      await speak('Go up to floor $toFloor');
    } else {
      await speak('Go down to floor $toFloor');
    }
  }

  /// Announce QR code scanned
  Future<void> announceQRScanned(String location) async {
    await speak('Position updated at $location');
  }

  /// Announce turn instruction
  Future<void> announceTurn(String turnType, String nextLocation) async {
    String instruction;
    switch (turnType.toLowerCase()) {
      case 'left':
        instruction = 'Turn left towards $nextLocation';
        break;
      case 'right':
        instruction = 'Turn right towards $nextLocation';
        break;
      case 'slight_left':
        instruction = 'Turn slightly left towards $nextLocation';
        break;
      case 'slight_right':
        instruction = 'Turn slightly right towards $nextLocation';
        break;
      case 'sharp_left':
        instruction = 'Make a sharp left turn towards $nextLocation';
        break;
      case 'sharp_right':
        instruction = 'Make a sharp right turn towards $nextLocation';
        break;
      case 'u_turn':
        instruction = 'Make a U-turn towards $nextLocation';
        break;
      default:
        instruction = 'Continue towards $nextLocation';
    }
    await speak(instruction);
  }

  /// Announce emergency exit
  Future<void> announceEmergencyExit(String exitName, double distance) async {
    final distanceText = _formatDistance(distance);
    await speak('Emergency exit $exitName is $distanceText away');
  }

  /// Format distance for speech
  String _formatDistance(double meters) {
    if (meters < 1) {
      return 'less than 1 meter';
    } else if (meters < 10) {
      return '${meters.toStringAsFixed(0)} meters';
    } else if (meters < 100) {
      return '${(meters / 10).round() * 10} meters';
    } else {
      return '${(meters / 100).round() * 100} meters';
    }
  }

  /// Get turn type from direction change
  String getTurnType(double fromHeading, double toHeading) {
    double diff = (toHeading - fromHeading + 360) % 360;

    if (diff < 15 || diff > 345) {
      return 'straight';
    } else if (diff >= 15 && diff < 45) {
      return 'slight_right';
    } else if (diff >= 45 && diff < 135) {
      return 'right';
    } else if (diff >= 135 && diff < 160) {
      return 'sharp_right';
    } else if (diff >= 160 && diff <= 200) {
      return 'u_turn';
    } else if (diff > 200 && diff < 225) {
      return 'sharp_left';
    } else if (diff >= 225 && diff < 315) {
      return 'left';
    } else {
      return 'slight_left';
    }
  }

  /// Announce accessibility feature
  Future<void> announceAccessibility(String feature) async {
    await speak('Accessible route: $feature available');
  }

  /// Announce crowd warning
  Future<void> announceCrowdWarning() async {
    await speak('High traffic ahead. Consider alternate route');
  }

  /// Announce battery warning
  Future<void> announceBatteryWarning() async {
    await speak('Low battery. Consider saving route for offline use');
  }
}
