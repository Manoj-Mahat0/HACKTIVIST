import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:pedometer/pedometer.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../../../core/theme/app_theme.dart';
import '../widgets/ar_overlay_widgets.dart';

/// Enhanced AR Navigation Page
/// Provides comprehensive AR-based indoor navigation with GPS tracking,
/// voice guidance, turn-by-turn directions, and real-time positioning
class ArNavigationPage extends StatefulWidget {
  final String buildingName;
  final List<Map<String, dynamic>> route;
  final int initialRouteIndex;

  const ArNavigationPage({
    super.key,
    required this.buildingName,
    required this.route,
    this.initialRouteIndex = 0,
  });

  @override
  State<ArNavigationPage> createState() => _ArNavigationPageState();
}

class _ArNavigationPageState extends State<ArNavigationPage> with WidgetsBindingObserver {
  // Camera
  CameraController? _cameraController;

  // Navigation state
  double _currentHeading = 0.0;
  int _currentStepCount = 0;
  late int _currentRouteIndex;
  bool _showDirectionArrow = true;
  bool _showCompass = true;
  bool _audioEnabled = true;
  bool _isPlayingAudio = false;
  String _currentInstruction = '';
  
  // GPS and positioning
  Position? _currentPosition;
  double _distanceToNextWaypoint = 0.0;
  double _distanceToDestination = 0.0;
  double _targetBearing = 0.0;
  String _turnDirection = 'forward';
  bool _isNearWaypoint = false;
  
  // Progress tracking
  double _routeProgress = 0.0;
  Duration _estimatedTimeRemaining = Duration.zero;
  DateTime? _navigationStartTime;
  
  // Sensors
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<StepCount>? _stepCounterSubscription;
  StreamSubscription<Position>? _gpsSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  FlutterTts? _flutterTts;
  
  // Sensor data
  double _accelerometerX = 0.0;
  double _accelerometerY = 0.0;
  double _accelerometerZ = 0.0;
  double _gyroscopeX = 0.0;
  double _gyroscopeY = 0.0;
  double _gyroscopeZ = 0.0;
  
  // Calibration and error handling
  bool _isCompassCalibrated = true;
  bool _hasGPSSignal = true;
  int _gpsSignalStrength = 100;
  String? _errorMessage;
  
  // Performance optimization
  Timer? _updateTimer;
  Timer? _voiceGuidanceTimer;
  bool _isLowPowerMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentRouteIndex = widget.initialRouteIndex;
    _navigationStartTime = DateTime.now();
    _initCamera();
    _initSensors();
    _initFlutterTts();
    _startPeriodicUpdates();
    _giveInitialInstructions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _compassSubscription?.cancel();
    _stepCounterSubscription?.cancel();
    _gpsSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _flutterTts?.stop();
    _updateTimer?.cancel();
    _voiceGuidanceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Optimize battery usage based on app state
    if (state == AppLifecycleState.paused) {
      _enableLowPowerMode();
    } else if (state == AppLifecycleState.resumed) {
      _disableLowPowerMode();
    }
  }

  void _enableLowPowerMode() {
    setState(() => _isLowPowerMode = true);
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (_) => _updateNavigationData());
  }

  void _disableLowPowerMode() {
    setState(() => _isLowPowerMode = false);
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _updateNavigationData());
  }

  void _startPeriodicUpdates() {
    // Update navigation data periodically
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updateNavigationData();
    });
    
    // Voice guidance timer (less frequent to save battery)
    _voiceGuidanceTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _providePeriodicGuidance();
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showError('No camera available');
        return;
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium, // Use medium for better battery life
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showError('Failed to initialize camera: $e');
    }
  }

  Future<void> _initSensors() async {
    try {
      // Initialize compass
      _compassSubscription = FlutterCompass.events?.listen((event) {
        if (mounted && event.heading != null) {
          setState(() {
            _currentHeading = event.heading!;
            _isCompassCalibrated = event.accuracy != null;
          });
        }
      });

      // Initialize pedometer
      _stepCounterSubscription = Pedometer.stepCountStream.listen(
        (StepCount stepCount) {
          if (mounted) {
            setState(() {
              _currentStepCount = stepCount.steps;
            });
          }
        },
        onError: (error) {
          print('⚠️ Pedometer error: $error');
        },
      );

      // Initialize GPS
      _initGPS();

      // Initialize accelerometer
      _accelerometerSubscription = accelerometerEvents.listen(
        (AccelerometerEvent event) {
          if (mounted) {
            setState(() {
              _accelerometerX = event.x;
              _accelerometerY = event.y;
              _accelerometerZ = event.z;
            });
          }
        },
      );

      // Initialize gyroscope
      _gyroscopeSubscription = gyroscopeEvents.listen(
        (GyroscopeEvent event) {
          if (mounted) {
            setState(() {
              _gyroscopeX = event.x;
              _gyroscopeY = event.y;
              _gyroscopeZ = event.z;
            });
          }
        },
      );
    } catch (e) {
      print('⚠️ Sensor initialization error: $e');
    }
  }

  Future<void> _initGPS() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _hasGPSSignal = false;
            _errorMessage = 'Location permission denied';
          });
          return;
        }
      }

      _gpsSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1, // Update every meter
        ),
      ).listen(
        (Position position) {
          if (mounted) {
            setState(() {
              _currentPosition = position;
              _hasGPSSignal = true;
              _gpsSignalStrength = _calculateGPSStrength(position.accuracy);
              _errorMessage = null;
            });
            _updateNavigationData();
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _hasGPSSignal = false;
              _errorMessage = 'GPS signal lost';
            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _hasGPSSignal = false;
        _errorMessage = 'GPS initialization failed';
      });
    }
  }

  int _calculateGPSStrength(double accuracy) {
    // Convert accuracy to signal strength (0-100)
    if (accuracy <= 5) return 100;
    if (accuracy <= 10) return 80;
    if (accuracy <= 20) return 60;
    if (accuracy <= 50) return 40;
    return 20;
  }

  Future<void> _initFlutterTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts!.setLanguage("en-US");
    await _flutterTts!.setSpeechRate(0.5);
    await _flutterTts!.setVolume(1.0);
    await _flutterTts!.setPitch(1.0);
  }

  void _giveInitialInstructions() {
    if (widget.route.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        final destination = widget.route.last['label'];
        final distance = _calculateTotalDistance();
        _speakInstruction('Starting AR navigation to $destination. Total distance: ${distance.toStringAsFixed(0)} meters');
      });
    }
  }

  void _updateNavigationData() {
    if (_currentPosition == null || widget.route.isEmpty) return;

    final currentWaypoint = widget.route[_currentRouteIndex];
    
    // Calculate distance to next waypoint
    _distanceToNextWaypoint = _calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      (currentWaypoint['latitude'] as num).toDouble(),
      (currentWaypoint['longitude'] as num).toDouble(),
    );

    // Calculate distance to final destination
    final destination = widget.route.last;
    _distanceToDestination = _calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      (destination['latitude'] as num).toDouble(),
      (destination['longitude'] as num).toDouble(),
    );

    // Calculate bearing to next waypoint
    _targetBearing = _calculateBearing(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      (currentWaypoint['latitude'] as num).toDouble(),
      (currentWaypoint['longitude'] as num).toDouble(),
    );

    // Determine turn direction
    _turnDirection = _getTurnDirection(_currentHeading, _targetBearing);

    // Calculate route progress
    _routeProgress = _calculateRouteProgress();

    // Estimate time remaining
    _estimatedTimeRemaining = _calculateETA();

    // Check if near waypoint
    _isNearWaypoint = _distanceToNextWaypoint < 5.0; // Within 5 meters

    // Auto-advance to next waypoint if very close
    if (_distanceToNextWaypoint < 2.0 && _currentRouteIndex < widget.route.length - 1) {
      _moveToNextMilestone();
    }

    // Check if reached destination
    if (_distanceToDestination < 2.0 && _currentRouteIndex == widget.route.length - 1) {
      _onDestinationReached();
    }

    if (mounted) {
      setState(() {});
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
        math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) *
        math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = _degreesToRadians(lon2 - lon1);
    final y = math.sin(dLon) * math.cos(_degreesToRadians(lat2));
    final x = math.cos(_degreesToRadians(lat1)) * math.sin(_degreesToRadians(lat2)) -
        math.sin(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) * math.cos(dLon);
    
    final bearing = math.atan2(y, x);
    return (_radiansToDegrees(bearing) + 360) % 360;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  double _radiansToDegrees(double radians) {
    return radians * 180 / math.pi;
  }

  String _getTurnDirection(double currentHeading, double targetBearing) {
    double diff = (targetBearing - currentHeading + 360) % 360;
    
    if (diff < 30 || diff > 330) return 'forward';
    if (diff >= 30 && diff < 150) return 'right';
    if (diff >= 150 && diff < 210) return 'backward';
    return 'left';
  }

  double _calculateRouteProgress() {
    if (widget.route.isEmpty) return 0.0;
    return (_currentRouteIndex + 1) / widget.route.length;
  }

  double _calculateTotalDistance() {
    double total = 0.0;
    for (int i = 0; i < widget.route.length - 1; i++) {
      final current = widget.route[i];
      final next = widget.route[i + 1];
      total += _calculateDistance(
        (current['latitude'] as num).toDouble(),
        (current['longitude'] as num).toDouble(),
        (next['latitude'] as num).toDouble(),
        (next['longitude'] as num).toDouble(),
      );
    }
    return total;
  }

  Duration _calculateETA() {
    if (_navigationStartTime == null || _distanceToDestination == 0) {
      return Duration.zero;
    }

    // Assume average walking speed of 1.4 m/s
    const double walkingSpeed = 1.4;
    final seconds = (_distanceToDestination / walkingSpeed).round();
    return Duration(seconds: seconds);
  }

  void _providePeriodicGuidance() {
    if (!_audioEnabled || _isPlayingAudio) return;

    if (_distanceToNextWaypoint < 10) {
      final waypoint = widget.route[_currentRouteIndex];
      _speakInstruction('${_distanceToNextWaypoint.toStringAsFixed(0)} meters to ${waypoint['label']}. Turn $_turnDirection');
    } else if (_distanceToNextWaypoint < 50) {
      _speakInstruction('Continue $_turnDirection. ${_distanceToNextWaypoint.toStringAsFixed(0)} meters ahead');
    }
  }

  void _onDestinationReached() {
    HapticFeedback.heavyImpact();
    _speakInstruction('You have arrived at your destination: ${widget.route.last['label']}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Destination Reached'),
        content: Text('You have arrived at ${widget.route.last['label']}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  void _speakInstruction(String instruction) async {
    if (_audioEnabled && _flutterTts != null && !_isPlayingAudio) {
      setState(() {
        _isPlayingAudio = true;
        _currentInstruction = instruction;
      });

      await _flutterTts!.speak(instruction);

      // Wait for speech to complete
      await Future.delayed(Duration(milliseconds: instruction.length * 50));

      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
          _currentInstruction = '';
        });
      }
    }
  }

  void _moveToNextMilestone() {
    if (_currentRouteIndex < widget.route.length - 1) {
      HapticFeedback.mediumImpact();
      
      setState(() {
        _currentRouteIndex++;
      });

      if (_currentRouteIndex < widget.route.length) {
        final nextNode = widget.route[_currentRouteIndex];
        final distance = _distanceToNextWaypoint.toStringAsFixed(0);
        _speakInstruction('Approaching ${nextNode['label']}. $distance meters ahead. Turn $_turnDirection');
      }
    } else {
      _onDestinationReached();
    }
  }

  void _moveToPreviousMilestone() {
    if (_currentRouteIndex > 0) {
      HapticFeedback.lightImpact();
      
      setState(() {
        _currentRouteIndex--;
      });

      final currentNode = widget.route[_currentRouteIndex];
      _speakInstruction('Going back to ${currentNode['label']}');
    }
  }

  double _calculateTargetHeading() {
    return _targetBearing;
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildDirectionArrow() {
    if (!_showDirectionArrow || _currentPosition == null) return const SizedBox.shrink();

    final relativeBearing = (_targetBearing - _currentHeading + 360) % 360;

    return Positioned(
      top: MediaQuery.of(context).size.height * 0.3,
      left: 0,
      right: 0,
      child: Center(
        child: Transform.rotate(
          angle: _degreesToRadians(relativeBearing),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _isNearWaypoint ? Colors.green.withOpacity(0.8) : AppColors.primaryOrange.withOpacity(0.8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.navigation,
              size: 60,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompassIndicator() {
    if (!_showCompass) return const SizedBox.shrink();

    return Positioned(
      top: 100,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Transform.rotate(
              angle: _degreesToRadians(-_currentHeading),
              child: const Icon(
                Icons.navigation,
                color: Colors.red,
                size: 40,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_currentHeading.toStringAsFixed(0)}°',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!_isCompassCalibrated)
              const Icon(
                Icons.warning_amber,
                color: Colors.orange,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceIndicator() {
    if (_currentPosition == null) return const SizedBox.shrink();

    return Positioned(
      top: 100,
      left: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place, color: AppColors.primaryOrange, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${_distanceToNextWaypoint.toStringAsFixed(0)}m',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'To destination: ${_distanceToDestination.toStringAsFixed(0)}m',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnDirectionIndicator() {
    if (_currentPosition == null) return const SizedBox.shrink();

    IconData icon;
    String text;
    
    switch (_turnDirection) {
      case 'left':
        icon = Icons.turn_left;
        text = 'Turn Left';
        break;
      case 'right':
        icon = Icons.turn_right;
        text = 'Turn Right';
        break;
      case 'backward':
        icon = Icons.u_turn_left;
        text = 'Turn Around';
        break;
      default:
        icon = Icons.arrow_upward;
        text = 'Go Straight';
    }

    return Positioned(
      top: MediaQuery.of(context).size.height * 0.5,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primaryOrange, size: 32),
              const SizedBox(width: 12),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Positioned(
      bottom: 200,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress: ${(_routeProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'ETA: ${_estimatedTimeRemaining.inMinutes}:${(_estimatedTimeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _routeProgress,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorIndicator() {
    if (_errorMessage == null && _hasGPSSignal && _isCompassCalibrated) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 200,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage ?? (!_hasGPSSignal ? 'GPS signal lost' : 'Compass needs calibration'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGPSStrengthIndicator() {
    return Positioned(
      top: 60,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.gps_fixed,
              color: _gpsSignalStrength > 60 ? Colors.green : (_gpsSignalStrength > 30 ? Colors.orange : Colors.red),
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '$_gpsSignalStrength%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          if (_cameraController != null && _cameraController!.value.isInitialized)
            SizedBox.expand(
              child: CameraPreview(_cameraController!),
            ),

          // Enhanced AR Overlays
          _buildDirectionArrow(),
          _buildCompassIndicator(),
          _buildDistanceIndicator(),
          _buildTurnDirectionIndicator(),
          _buildProgressBar(),
          _buildErrorIndicator(),
          _buildGPSStrengthIndicator(),

          // Legacy AR overlays (kept for backward compatibility)
          if (widget.route.isNotEmpty && _showDirectionArrow)
            ArDirectionArrow(
              currentWaypoint: _currentRouteIndex > 0 ? widget.route[_currentRouteIndex - 1] : null,
              nextWaypoint: widget.route[_currentRouteIndex],
              showArrow: _showDirectionArrow,
            ),

          ArMilestoneIndicator(
            route: widget.route,
            currentIndex: _currentRouteIndex,
            buildingName: widget.buildingName,
          ),

          AudioIndicator(
            isPlaying: _isPlayingAudio,
            instruction: _currentInstruction,
            audioEnabled: _audioEnabled,
          ),

          // Navigation Controls
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AR Navigation',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.route.isNotEmpty && _currentRouteIndex < widget.route.length)
                              Text(
                                'To: ${widget.route.last['label']}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Battery indicator
                      if (_isLowPowerMode)
                        const Icon(
                          Icons.battery_saver,
                          color: Colors.orange,
                          size: 20,
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _audioEnabled = !_audioEnabled;
                          });
                          if (_audioEnabled) {
                            _speakInstruction('Voice guidance enabled');
                          }
                        },
                        icon: Icon(
                          _audioEnabled ? Icons.volume_up : Icons.volume_off,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Bottom Controls
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Current waypoint info
                      if (_currentRouteIndex < widget.route.length)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${_currentRouteIndex + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.route[_currentRouteIndex]['label'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_currentPosition != null)
                                      Text(
                                        '${_distanceToNextWaypoint.toStringAsFixed(0)}m • $_turnDirection',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Navigation buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _currentRouteIndex > 0 ? _moveToPreviousMilestone : null,
                            icon: const Icon(Icons.arrow_back_ios, size: 16),
                            label: const Text('Previous'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _currentRouteIndex < widget.route.length - 1 ? _moveToNextMilestone : null,
                            icon: const Icon(Icons.arrow_forward_ios, size: 16),
                            label: const Text('Next'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Settings toggles
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          FilterChip(
                            label: const Text('Arrow', style: TextStyle(fontSize: 12)),
                            selected: _showDirectionArrow,
                            onSelected: (bool selected) {
                              setState(() => _showDirectionArrow = selected);
                            },
                            selectedColor: AppColors.primaryOrange,
                          ),
                          FilterChip(
                            label: const Text('Compass', style: TextStyle(fontSize: 12)),
                            selected: _showCompass,
                            onSelected: (bool selected) {
                              setState(() => _showCompass = selected);
                            },
                            selectedColor: AppColors.primaryOrange,
                          ),
                          FilterChip(
                            label: Text(
                              _isLowPowerMode ? 'Power Save' : 'Normal',
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: _isLowPowerMode,
                            onSelected: (bool selected) {
                              if (selected) {
                                _enableLowPowerMode();
                              } else {
                                _disableLowPowerMode();
                              }
                            },
                            selectedColor: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
