import 'dart:async';
import 'dart:math';
// import 'package:sensors_plus/sensors_plus.dart'; // Temporarily disabled
import 'local_position.dart';

class PDREngine {
  // Current estimated position
  double _x = 0;
  double _y = 0;
  int _floor = 0;
  double _heading = 0; // radians

  // Step detection parameters
  static const double _stepLength = 0.7; // Average step length in meters
  static const double _stepThreshold = 12.0; // Acceleration threshold
  static const double _stepDebounceMs = 300; // Minimum time between steps
  static const double _confidenceDecayPerStep = 0.1; // Confidence decreases by 0.1m per step
  
  // State
  double _currentConfidence = 5.0; // Initial confidence radius in meters

  // Sensor data
  final double _lastAccelMagnitude = 0;
  final bool _isStepDetected = false;
  final DateTime _lastStepTime = DateTime.now();

  // Magnetometer calibration
  double _magXMin = 0, _magXMax = 0;
  double _magYMin = 0, _magYMax = 0;
  final bool _isMagCalibrated = false;

  final StreamController<LocalPosition> _positionController =
      StreamController<LocalPosition>.broadcast();

  Stream<LocalPosition> get positionStream => _positionController.stream;

  final List<StreamSubscription> _subscriptions = [];

  void start() {
    // Sensors temporarily disabled - using pedometer_2 and smooth_compass instead
    // Listen to accelerometer for step detection
    // _subscriptions.add(
    //   accelerometerEvents.listen(_onAccelerometerData),
    // );

    // Listen to magnetometer for heading
    // _subscriptions.add(
    //   magnetometerEvents.listen(_onMagnetometerData),
    // );

    // Listen to gyroscope for rotation
    // _subscriptions.add(
    //   gyroscopeEvents.listen(_onGyroscopeData),
    // );
  }

  void _onAccelerometerData(dynamic event) {
    // Temporarily disabled - sensors_plus removed
    // Calculate acceleration magnitude
    // double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    // Step detection using peak detection with debouncing
    // final now = DateTime.now();
    // final timeSinceLastStep = now.difference(_lastStepTime).inMilliseconds;

    // if (!_isStepDetected && magnitude > _stepThreshold && timeSinceLastStep > _stepDebounceMs) {
    //   _isStepDetected = true;
    //   _lastStepTime = now;
    //   _onStepDetected();
    // } else if (magnitude < _stepThreshold - 2) {
    //   _isStepDetected = false;
    // }

    // _lastAccelMagnitude = magnitude;
  }

  void _onMagnetometerData(dynamic event) {
    // Temporarily disabled - sensors_plus removed
    // Calibrate magnetometer on first readings
    // if (!_isMagCalibrated) {
    //   _magXMin = min(_magXMin, event.x);
    //   _magXMax = max(_magXMax, event.x);
    //   _magYMin = min(_magYMin, event.y);
    //   _magYMax = max(_magYMax, event.y);
    //
    //   // Consider calibrated after 100 readings
    //   if (_magXMax - _magXMin > 10 && _magYMax - _magYMin > 10) {
    //     _isMagCalibrated = true;
    //   }
    // }
    //
    // // Calculate heading from magnetometer
    // double x = event.x;
    // double y = event.y;
    //
    // // Apply calibration
    // if (_isMagCalibrated) {
    //   x = (2 * x - _magXMax - _magXMin) / (_magXMax - _magXMin);
    //   y = (2 * y - _magYMax - _magYMin) / (_magYMax - _magYMin);
    // }
    //
    // _heading = atan2(y, x);
    //
    // // Convert to 0-360 range
    // if (_heading < 0) {
    //   _heading += 2 * pi;
    // }
  }

  void _onGyroscopeData(dynamic event) {
    // Temporarily disabled
    // Gyroscope data can be used for short-term heading changes
    // For now, we rely on magnetometer for heading
  }

  void _onStepDetected() {
    // Update position based on step and heading
    _x += _stepLength * cos(_heading);
    _y += _stepLength * sin(_heading);
    
    // Decrease confidence
    _currentConfidence += _confidenceDecayPerStep;
    if (_currentConfidence > 20.0) _currentConfidence = 20.0; // Cap max error

    // Emit new position
    _positionController.add(LocalPosition(
      x: _x,
      y: _y,
      floor: _floor,
      heading: _heading * 180 / pi,
      accuracy: _calculateAccuracy(),
      timestamp: DateTime.now(),
    ));
  }

  double _calculateAccuracy() {
    // Accuracy decreases over time without correction
    // This is a simplified model - in production, use Kalman filter
    return _currentConfidence;
  }

  // Reset position when QR code is scanned
  void resetPosition(double x, double y, int floor, double heading) {
    _x = x;
    _y = y;
    _floor = floor;
    _heading = heading * pi / 180;

    _positionController.add(LocalPosition(
      x: _x,
      y: _y,
      floor: _floor,
      heading: heading,
      accuracy: 0.5, // High accuracy after reset
      timestamp: DateTime.now(),
    ));
    
    _currentConfidence = 0.5; // Reset confidence
  }

  void setFloor(int floor) {
    _floor = floor;
  }

  LocalPosition getCurrentPosition() {
    return LocalPosition(
      x: _x,
      y: _y,
      floor: _floor,
      heading: _heading * 180 / pi,
      accuracy: _calculateAccuracy(),
      timestamp: DateTime.now(),
    );
  }

  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _positionController.close();
  }
}
