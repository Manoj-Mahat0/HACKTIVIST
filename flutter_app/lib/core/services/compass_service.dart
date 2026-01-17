import 'dart:async';
import 'package:flutter_compass/flutter_compass.dart';

/// Service to manage compass sensor with reduced logging spam
class CompassService {
  static final CompassService _instance = CompassService._internal();
  factory CompassService() => _instance;
  CompassService._internal();

  StreamSubscription<CompassEvent>? _compassSubscription;
  final _compassController = StreamController<double>.broadcast();
  
  double? _lastHeading;
  DateTime? _lastCalibrationWarning;
  bool _isInitialized = false;
  
  /// Minimum change in degrees to emit new heading (reduces noise)
  static const double _headingThreshold = 2.0;
  
  /// Minimum time between calibration warnings (reduces spam)
  static const Duration _calibrationWarningInterval = Duration(minutes: 5);

  /// Get compass heading stream (filtered and optimized)
  Stream<double> get headingStream => _compassController.stream;

  /// Get last known heading
  double? get lastHeading => _lastHeading;

  /// Check if compass is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize compass service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final compassStream = FlutterCompass.events;
      
      if (compassStream == null) {
        print('⚠️ Compass not available on this device');
        return;
      }

      _compassSubscription = compassStream.listen(
        (CompassEvent event) {
          _handleCompassEvent(event);
        },
        onError: (error) {
          // Suppress repeated calibration warnings
          _logCalibrationWarning();
        },
      );

      _isInitialized = true;
      print('✅ Compass service initialized');
    } catch (e) {
      print('❌ Failed to initialize compass: $e');
    }
  }

  /// Handle compass events with filtering
  void _handleCompassEvent(CompassEvent event) {
    if (event.heading == null) return;

    final heading = event.heading!;
    
    // Check accuracy and log calibration warning if needed
    if (event.accuracy != null && event.accuracy! < 0) {
      _logCalibrationWarning();
    }

    // Only emit if heading changed significantly (reduces noise)
    if (_lastHeading == null || 
        (heading - _lastHeading!).abs() >= _headingThreshold) {
      _lastHeading = heading;
      _compassController.add(heading);
    }
  }

  /// Log calibration warning with rate limiting
  void _logCalibrationWarning() {
    final now = DateTime.now();
    
    if (_lastCalibrationWarning == null ||
        now.difference(_lastCalibrationWarning!) >= _calibrationWarningInterval) {
      _lastCalibrationWarning = now;
      print('📱 Compass calibration needed - Move device in figure-8 pattern');
    }
  }

  /// Dispose compass service
  void dispose() {
    _compassSubscription?.cancel();
    _compassController.close();
    _isInitialized = false;
  }

  /// Reset service (useful for testing)
  void reset() {
    dispose();
    _lastHeading = null;
    _lastCalibrationWarning = null;
  }
}
