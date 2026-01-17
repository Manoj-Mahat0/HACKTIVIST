import 'package:flutter/services.dart';

/// Haptic Feedback Service for Navigation
/// Provides different vibration patterns for various navigation events
class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  /// Pattern types for different navigation events
  static const Map<String, List<int>> patterns = {
    'go_straight': [200],
    'turn_left': [100, 50, 100],
    'turn_right': [100, 50, 100, 50, 100],
    'turn_around': [200, 100, 200, 100, 200],
    'arrived': [100, 50, 100, 50, 100, 50, 300],
    'warning': [50, 50, 50, 50, 50],
    'milestone_reached': [150, 75, 150],
    'floor_change': [200, 100, 200],
    'recalculating': [50, 100, 50, 100, 50],
    'qr_scanned': [100, 50, 200],
    'emergency': [100, 50, 100, 50, 100, 50, 100],
  };

  /// Execute haptic feedback for a specific pattern type
  Future<void> executePattern(String patternType) async {
    final pattern = patterns[patternType];
    if (pattern == null) {
      await HapticFeedback.mediumImpact();
      return;
    }

    for (int i = 0; i < pattern.length; i++) {
      if (i % 2 == 0) {
        // Vibration
        await HapticFeedback.vibrate();
      }
      await Future.delayed(Duration(milliseconds: pattern[i]));
    }
  }

  /// Light impact for minor events
  Future<void> lightImpact() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium impact for standard events
  Future<void> mediumImpact() async {
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact for important events
  Future<void> heavyImpact() async {
    await HapticFeedback.heavyImpact();
  }

  /// Selection click for UI interactions
  Future<void> selectionClick() async {
    await HapticFeedback.selectionClick();
  }

  /// Direction-based haptic feedback
  Future<void> directionFeedback(String direction) async {
    switch (direction.toUpperCase()) {
      case 'N':
      case 'S':
        await executePattern('go_straight');
        break;
      case 'E':
      case 'NE':
      case 'SE':
        await executePattern('turn_right');
        break;
      case 'W':
      case 'NW':
      case 'SW':
        await executePattern('turn_left');
        break;
      case 'UP':
      case 'DOWN':
        await executePattern('floor_change');
        break;
      default:
        await mediumImpact();
    }
  }

  /// Milestone reached feedback
  Future<void> milestoneReached() async {
    await executePattern('milestone_reached');
  }

  /// Destination arrived feedback
  Future<void> arrived() async {
    await executePattern('arrived');
  }

  /// Warning feedback
  Future<void> warning() async {
    await executePattern('warning');
  }

  /// Emergency feedback
  Future<void> emergency() async {
    await executePattern('emergency');
  }

  /// QR code scanned feedback
  Future<void> qrScanned() async {
    await executePattern('qr_scanned');
  }

  /// Route recalculating feedback
  Future<void> recalculating() async {
    await executePattern('recalculating');
  }

  /// Get haptic data for API response
  static Map<String, dynamic> getHapticData(String direction) {
    String patternType;
    switch (direction.toUpperCase()) {
      case 'N':
      case 'S':
        patternType = 'go_straight';
        break;
      case 'E':
      case 'NE':
      case 'SE':
        patternType = 'turn_right';
        break;
      case 'W':
      case 'NW':
      case 'SW':
        patternType = 'turn_left';
        break;
      case 'UP':
      case 'DOWN':
        patternType = 'floor_change';
        break;
      default:
        patternType = 'go_straight';
    }

    return {
      'pattern_type': patternType,
      'vibration_pattern': patterns[patternType] ?? [200],
      'intensity': _getIntensity(patternType),
    };
  }

  static double _getIntensity(String patternType) {
    switch (patternType) {
      case 'arrived':
      case 'emergency':
        return 1.0;
      case 'turn_around':
      case 'floor_change':
        return 0.8;
      case 'turn_left':
      case 'turn_right':
        return 0.6;
      default:
        return 0.5;
    }
  }
}
