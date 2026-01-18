import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pdr_engine.dart';

/// Service for automatic location detection using device sensors
class LocationDetectionService {
  final PDREngine _pdrEngine;
  
  // Current detected position
  double? _currentX;
  double? _currentY;
  int? _currentFloor;
  double? _currentHeading;
  double? _confidence; // 0.0 to 1.0
  
  // Sensor streams
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  
  // Detection state
  bool _isDetecting = false;
  bool _isInitialized = false;
  DateTime? _lastUpdate;
  
  // Building context
  String? _buildingId;
  List<Map<String, dynamic>> _buildingNodes = [];
  Map<String, dynamic>? _buildingBounds;
  
  // Callbacks
  Function(double x, double y, int floor, double heading, double confidence)? onLocationDetected;
  Function(String error)? onDetectionError;
  Function(DetectionStatus status)? onStatusChanged;
  
  // Constants
  static const double _gpsAccuracyThreshold = 20.0; // meters
  static const double _floorHeightMeters = 3.5; // average floor height
  static const Duration _updateInterval = Duration(seconds: 2);
  static const int _minSamplesForConfidence = 5;
  
  // Sensor data buffers
  final List<double> _headingBuffer = [];
  final List<double> _altitudeBuffer = [];
  final List<AccelerometerEvent> _accelerometerBuffer = [];
  
  LocationDetectionService(this._pdrEngine);
  
  /// Initialize the location detection service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // Request permissions
      final permissions = await _requestPermissions();
      if (!permissions) {
        onDetectionError?.call('Location permissions not granted');
        return false;
      }
      
      // Initialize PDR engine
      _pdrEngine.start();
      
      _isInitialized = true;
      onStatusChanged?.call(DetectionStatus.initialized);
      print('✅ Location detection service initialized');
      return true;
    } catch (e) {
      print('❌ Failed to initialize location detection: $e');
      onDetectionError?.call('Initialization failed: $e');
      return false;
    }
  }
  
  /// Request necessary permissions
  Future<bool> _requestPermissions() async {
    final locationStatus = await Permission.location.request();
    final activityStatus = await Permission.activityRecognition.request();
    
    return locationStatus.isGranted && activityStatus.isGranted;
  }
  
  /// Set building context for location detection
  void setBuildingContext({
    required String buildingId,
    required List<Map<String, dynamic>> nodes,
    Map<String, dynamic>? bounds,
  }) {
    _buildingId = buildingId;
    _buildingNodes = nodes;
    _buildingBounds = bounds;
    print('📍 Building context set: $buildingId with ${nodes.length} nodes');
  }
  
  /// Start automatic location detection
  Future<void> startDetection() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return;
    }
    
    if (_isDetecting) return;
    
    _isDetecting = true;
    onStatusChanged?.call(DetectionStatus.detecting);
    print('🔍 Starting location detection...');
    
    // Start GPS tracking
    _startGPSTracking();
    
    // Start compass tracking
    _startCompassTracking();
    
    // Start accelerometer tracking (for floor detection)
    _startAccelerometerTracking();
    
    // Start gyroscope tracking (for movement detection)
    _startGyroscopeTracking();
    
    // Start magnetometer tracking (for heading refinement)
    _startMagnetometerTracking();
    
    // Start periodic position estimation
    _startPositionEstimation();
  }
  
  /// Stop location detection
  void stopDetection() {
    _isDetecting = false;
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    
    onStatusChanged?.call(DetectionStatus.stopped);
    print('⏹️ Location detection stopped');
  }
  
  /// Start GPS tracking
  void _startGPSTracking() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen(
      (Position position) {
        _processGPSPosition(position);
      },
      onError: (error) {
        print('❌ GPS error: $error');
        onDetectionError?.call('GPS error: $error');
      },
    );
  }
  
  /// Process GPS position
  void _processGPSPosition(Position position) {
    if (!_isDetecting) return;
    
    // Check accuracy
    if (position.accuracy > _gpsAccuracyThreshold) {
      print('⚠️ Low GPS accuracy: ${position.accuracy}m');
      return;
    }
    
    // Convert GPS to building coordinates if bounds are available
    if (_buildingBounds != null) {
      final buildingCoords = _gpsToBuilding(
        position.latitude,
        position.longitude,
      );
      
      if (buildingCoords != null) {
        _currentX = buildingCoords['x'];
        _currentY = buildingCoords['y'];
        
        // Estimate floor from altitude
        if (position.altitude != null) {
          _altitudeBuffer.add(position.altitude!);
          if (_altitudeBuffer.length > 10) _altitudeBuffer.removeAt(0);
          _currentFloor = _estimateFloor();
        }
        
        // Update PDR engine with GPS position
        _pdrEngine.resetPosition(
          _currentX!,
          _currentY!,
          _currentFloor ?? 0,
          _currentHeading ?? 0.0,
        );
        
        _updateConfidence();
        _notifyLocationUpdate();
      }
    }
  }
  
  /// Convert GPS coordinates to building coordinates
  Map<String, double>? _gpsToBuilding(double lat, double lng) {
    if (_buildingBounds == null) return null;
    
    // Simple linear transformation
    // In production, use proper coordinate transformation
    final minLat = _buildingBounds!['min_lat'] ?? 0.0;
    final maxLat = _buildingBounds!['max_lat'] ?? 0.0;
    final minLng = _buildingBounds!['min_lng'] ?? 0.0;
    final maxLng = _buildingBounds!['max_lng'] ?? 0.0;
    
    if (lat < minLat || lat > maxLat || lng < minLng || lng > maxLng) {
      return null; // Outside building bounds
    }
    
    // Normalize to 0-1 range
    final normalizedLat = (lat - minLat) / (maxLat - minLat);
    final normalizedLng = (lng - minLng) / (maxLng - minLng);
    
    // Scale to building dimensions (assuming 100m x 100m building)
    final x = normalizedLng * 100;
    final y = normalizedLat * 100;
    
    return {'x': x, 'y': y};
  }
  
  /// Start compass tracking
  void _startCompassTracking() {
    _compassSubscription = FlutterCompass.events?.listen(
      (CompassEvent event) {
        if (event.heading != null) {
          _headingBuffer.add(event.heading!);
          if (_headingBuffer.length > 10) _headingBuffer.removeAt(0);
          _currentHeading = _getAverageHeading();
        }
      },
    );
  }
  
  /// Start accelerometer tracking
  void _startAccelerometerTracking() {
    _accelerometerSubscription = accelerometerEvents.listen(
      (AccelerometerEvent event) {
        _accelerometerBuffer.add(event);
        if (_accelerometerBuffer.length > 50) _accelerometerBuffer.removeAt(0);
        
        // Detect vertical movement for floor changes
        _detectFloorChange();
      },
    );
  }
  
  /// Start gyroscope tracking
  void _startGyroscopeTracking() {
    _gyroscopeSubscription = gyroscopeEvents.listen(
      (GyroscopeEvent event) {
        // Use gyroscope for movement detection and heading refinement
        // This helps with PDR accuracy
      },
    );
  }
  
  /// Start magnetometer tracking
  void _startMagnetometerTracking() {
    _magnetometerSubscription = magnetometerEvents.listen(
      (MagnetometerEvent event) {
        // Use magnetometer for heading calibration
        // Helps correct compass drift
      },
    );
  }
  
  /// Start periodic position estimation
  void _startPositionEstimation() {
    Timer.periodic(_updateInterval, (timer) {
      if (!_isDetecting) {
        timer.cancel();
        return;
      }
      
      _estimatePosition();
    });
  }
  
  /// Estimate current position using sensor fusion
  void _estimatePosition() {
    // If we have GPS position, use it as base
    if (_currentX != null && _currentY != null) {
      // Get PDR offset from last GPS fix
      final pdrPosition = _pdrEngine.getCurrentPosition();
      
      // Fuse GPS and PDR using weighted average
      // GPS has higher weight when stationary, PDR when moving
      final gpsWeight = _isStationary() ? 0.8 : 0.3;
      final pdrWeight = 1.0 - gpsWeight;
      
      _currentX = (_currentX! * gpsWeight) + (pdrPosition.x * pdrWeight);
      _currentY = (_currentY! * gpsWeight) + (pdrPosition.y * pdrWeight);
      
      // Snap to nearest node if close enough
      _snapToNearestNode();
      
      _updateConfidence();
      _notifyLocationUpdate();
    } else {
      // No GPS fix, try to estimate from nodes
      _estimateFromNodes();
    }
  }
  
  /// Estimate floor from altitude changes
  int _estimateFloor() {
    if (_altitudeBuffer.isEmpty) return 0;
    
    final avgAltitude = _altitudeBuffer.reduce((a, b) => a + b) / _altitudeBuffer.length;
    final baseAltitude = _altitudeBuffer.first;
    final relativeAltitude = avgAltitude - baseAltitude;
    
    return (relativeAltitude / _floorHeightMeters).round();
  }
  
  /// Detect floor changes from accelerometer
  void _detectFloorChange() {
    if (_accelerometerBuffer.length < 20) return;
    
    // Calculate vertical acceleration variance
    final zValues = _accelerometerBuffer.map((e) => e.z).toList();
    final avgZ = zValues.reduce((a, b) => a + b) / zValues.length;
    final variance = zValues.map((z) => math.pow(z - avgZ, 2)).reduce((a, b) => a + b) / zValues.length;
    
    // High variance indicates stairs/elevator movement
    if (variance > 2.0) {
      // Likely changing floors
      onStatusChanged?.call(DetectionStatus.floorChanging);
    }
  }
  
  /// Check if user is stationary
  bool _isStationary() {
    if (_accelerometerBuffer.length < 10) return true;
    
    final recent = _accelerometerBuffer.sublist(_accelerometerBuffer.length - 10);
    final avgX = recent.map((e) => e.x).reduce((a, b) => a + b) / 10;
    final avgY = recent.map((e) => e.y).reduce((a, b) => a + b) / 10;
    final avgZ = recent.map((e) => e.z).reduce((a, b) => a + b) / 10;
    
    final variance = recent.map((e) {
      return math.pow(e.x - avgX, 2) + math.pow(e.y - avgY, 2) + math.pow(e.z - avgZ, 2);
    }).reduce((a, b) => a + b) / 10;
    
    return variance < 0.5; // Low variance = stationary
  }
  
  /// Get average heading from buffer
  double _getAverageHeading() {
    if (_headingBuffer.isEmpty) return 0.0;
    
    // Handle circular averaging for angles
    double sumSin = 0;
    double sumCos = 0;
    
    for (final heading in _headingBuffer) {
      final radians = heading * math.pi / 180;
      sumSin += math.sin(radians);
      sumCos += math.cos(radians);
    }
    
    final avgRadians = math.atan2(sumSin / _headingBuffer.length, sumCos / _headingBuffer.length);
    return (avgRadians * 180 / math.pi + 360) % 360;
  }
  
  /// Snap position to nearest node if within threshold
  void _snapToNearestNode() {
    if (_currentX == null || _currentY == null || _buildingNodes.isEmpty) return;
    
    const snapThreshold = 3.0; // meters
    
    Map<String, dynamic>? nearestNode;
    double minDistance = double.infinity;
    
    for (final node in _buildingNodes) {
      final nodeX = (node['latitude'] ?? 0.0).toDouble();
      final nodeY = (node['longitude'] ?? 0.0).toDouble();
      final nodeFloor = node['floor_number'] ?? 0;
      
      // Only consider nodes on same floor
      if (nodeFloor != _currentFloor) continue;
      
      final distance = _calculateDistance(_currentX!, _currentY!, nodeX, nodeY);
      
      if (distance < minDistance) {
        minDistance = distance;
        nearestNode = node;
      }
    }
    
    if (nearestNode != null && minDistance < snapThreshold) {
      _currentX = (nearestNode['latitude'] ?? _currentX).toDouble();
      _currentY = (nearestNode['longitude'] ?? _currentY).toDouble();
      print('📍 Snapped to node: ${nearestNode['label']} (${minDistance.toStringAsFixed(1)}m)');
    }
  }
  
  /// Estimate position from nearby nodes (fallback when no GPS)
  void _estimateFromNodes() {
    if (_buildingNodes.isEmpty) return;
    
    // Use WiFi fingerprinting or beacon triangulation in production
    // For now, use the first node as fallback
    final firstNode = _buildingNodes.first;
    _currentX = (firstNode['latitude'] ?? 0.0).toDouble();
    _currentY = (firstNode['longitude'] ?? 0.0).toDouble();
    _currentFloor = firstNode['floor_number'] ?? 0;
    _confidence = 0.3; // Low confidence
    
    print('⚠️ Using fallback position estimation');
    _notifyLocationUpdate();
  }
  
  /// Update confidence score
  void _updateConfidence() {
    double confidence = 0.0;
    
    // GPS contribution
    if (_currentX != null && _currentY != null) {
      confidence += 0.4;
    }
    
    // Heading contribution
    if (_headingBuffer.length >= _minSamplesForConfidence) {
      confidence += 0.2;
    }
    
    // Floor detection contribution
    if (_currentFloor != null) {
      confidence += 0.2;
    }
    
    // Time since last update
    if (_lastUpdate != null) {
      final timeSinceUpdate = DateTime.now().difference(_lastUpdate!).inSeconds;
      if (timeSinceUpdate < 5) {
        confidence += 0.2;
      }
    }
    
    _confidence = confidence.clamp(0.0, 1.0);
  }
  
  /// Notify location update
  void _notifyLocationUpdate() {
    if (_currentX == null || _currentY == null) return;
    
    _lastUpdate = DateTime.now();
    
    onLocationDetected?.call(
      _currentX!,
      _currentY!,
      _currentFloor ?? 0,
      _currentHeading ?? 0.0,
      _confidence ?? 0.0,
    );
    
    if (_confidence! > 0.7) {
      onStatusChanged?.call(DetectionStatus.highConfidence);
    } else if (_confidence! > 0.4) {
      onStatusChanged?.call(DetectionStatus.mediumConfidence);
    } else {
      onStatusChanged?.call(DetectionStatus.lowConfidence);
    }
  }
  
  /// Calculate distance between two points
  double _calculateDistance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }
  
  /// Get current detected location
  Map<String, dynamic>? getCurrentLocation() {
    if (_currentX == null || _currentY == null) return null;
    
    return {
      'x': _currentX,
      'y': _currentY,
      'floor': _currentFloor ?? 0,
      'heading': _currentHeading ?? 0.0,
      'confidence': _confidence ?? 0.0,
      'timestamp': _lastUpdate?.toIso8601String(),
    };
  }
  
  /// Find nearest node to current position
  Map<String, dynamic>? findNearestNode() {
    if (_currentX == null || _currentY == null || _buildingNodes.isEmpty) return null;
    
    Map<String, dynamic>? nearestNode;
    double minDistance = double.infinity;
    
    for (final node in _buildingNodes) {
      final nodeX = (node['latitude'] ?? 0.0).toDouble();
      final nodeY = (node['longitude'] ?? 0.0).toDouble();
      final nodeFloor = node['floor_number'] ?? 0;
      
      // Prefer nodes on same floor
      if (nodeFloor != _currentFloor) continue;
      
      final distance = _calculateDistance(_currentX!, _currentY!, nodeX, nodeY);
      
      if (distance < minDistance) {
        minDistance = distance;
        nearestNode = node;
      }
    }
    
    return nearestNode;
  }
  
  /// Dispose resources
  void dispose() {
    stopDetection();
    _headingBuffer.clear();
    _altitudeBuffer.clear();
    _accelerometerBuffer.clear();
  }
}

/// Detection status enum
enum DetectionStatus {
  uninitialized,
  initialized,
  detecting,
  highConfidence,
  mediumConfidence,
  lowConfidence,
  floorChanging,
  stopped,
  error,
}
