import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/positioning/pdr_engine.dart';
import '../../../../core/positioning/location_detection_service.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../buildings/domain/entities/building.dart';
import '../widgets/ar_overlay_widgets.dart';
import 'ar_navigation_page.dart';
import 'dart:math' as math;

/// Unified Navigation Page
/// Single page for all navigation needs: location selection, camera navigation, QR positioning
class UnifiedNavigationPage extends StatefulWidget {
  final Building building;
  final String? destinationNodeId; // Optional pre-selected destination

  const UnifiedNavigationPage({
    super.key,
    required this.building,
    this.destinationNodeId,
  });

  @override
  State<UnifiedNavigationPage> createState() => _UnifiedNavigationPageState();
}

class _UnifiedNavigationPageState extends State<UnifiedNavigationPage> {
  // Services
  late final PDREngine _pdrEngine;
  late final LocationDetectionService _locationDetectionService;
  static const String _apiBaseUrl = 'https://be.google.knocknockindia.com';

  // Navigation state
  List<Map<String, dynamic>> _nodes = [];
  Map<String, dynamic>? _startNode;
  Map<String, dynamic>? _endNode;
  Map<String, dynamic>? _currentPosition;
  Map<String, dynamic>? _detectedLocation;
  List<Map<String, dynamic>> _route = [];
  
  // UI state
  bool _isLoading = false;
  bool _isCameraActive = false;
  bool _isQRScannerActive = false;
  bool _isDetectingLocation = false;
  bool _useAutoLocation = true; // Auto-detect location by default
  double _locationConfidence = 0.0;
  DetectionStatus _detectionStatus = DetectionStatus.uninitialized;
  CameraController? _cameraController;
  MobileScannerController? _qrController;

  // Proximity detection state (GPS-based)
  StreamSubscription<Position>? _gpsSubscription;
  Map<String, dynamic>? _nearestNode;
  double _nearestNodeDistance = double.infinity;
  Timer? _proximityCheckTimer;
  Position? _lastGPSPosition;

  @override
  void initState() {
    super.initState();
    print('🔍 UnifiedNavigationPage initState - destinationNodeId: ${widget.destinationNodeId}');
    
    // If destination is pre-selected (from Intent Navigation), disable auto-location
    // so user can manually select start point
    if (widget.destinationNodeId != null) {
      _useAutoLocation = false;
      print('🔍 Disabled auto-location because destination is pre-selected');
    }
    
    _pdrEngine = getIt<PDREngine>();
    _locationDetectionService = getIt<LocationDetectionService>();
    _setupLocationDetection();
    _loadNodes();
  }

  void _setupLocationDetection() {
    // Set up callbacks for location detection
    _locationDetectionService.onLocationDetected = (x, y, floor, heading, confidence) {
      if (mounted) {
        setState(() {
          _detectedLocation = {
            'latitude': x,
            'longitude': y,
            'floor_number': floor,
            'heading': heading,
            'label': 'Current Location',
            'id': 'detected_location',
          };
          _locationConfidence = confidence;
          _currentPosition = _detectedLocation;
          
          // Auto-set as start node if using auto location
          if (_useAutoLocation) {
            _startNode = _detectedLocation;
          }
        });
        
        print('📍 Location detected: ($x, $y) Floor: $floor, Confidence: ${(confidence * 100).toStringAsFixed(0)}%');
      }
    };
    
    _locationDetectionService.onStatusChanged = (status) {
      if (mounted) {
        setState(() {
          _detectionStatus = status;
        });
        
        // Removed success/warning messages for location detection
      }
    };
    
    _locationDetectionService.onDetectionError = (error) {
      if (mounted) {
        // Silently log error without showing to user
        print('⚠️ Location detection error: $error');
      }
    };
  }

  /// Start GPS-based proximity detection for nearby nodes
  Future<void> _startProximityDetection() async {
    if (_nodes.isEmpty) return;
    
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('⚠️ Location permission denied');
          return;
        }
      }
      
      // Start GPS stream
      _gpsSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 2, // Update every 2 meters
        ),
      ).listen((Position position) {
        _lastGPSPosition = position;
        _checkProximityToNodes(position);
      });
      
      // Also check periodically
      _proximityCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_lastGPSPosition != null) {
          _checkProximityToNodes(_lastGPSPosition!);
        }
      });
      
      print('✅ Proximity detection started');
    } catch (e) {
      print('❌ Failed to start proximity detection: $e');
    }
  }

  /// Check proximity to all nodes using expanding radius search
  void _checkProximityToNodes(Position userPosition) {
    if (_nodes.isEmpty) return;
    
    print('🔍 GPS Position: ${userPosition.latitude}, ${userPosition.longitude}');
    
    const double initialRadius = 5.0;
    const double radiusIncrement = 5.0;
    const double maxRadius = 50.0; // 50 meters for indoor navigation
    
    double currentRadius = initialRadius;
    Map<String, dynamic>? closestNode;
    double closestDistance = double.infinity;
    
    // Expanding radius search
    while (currentRadius <= maxRadius) {
      print('🔍 Checking radius: ${currentRadius}m');
      
      for (final node in _nodes) {
        final nodeLat = (node['latitude'] as num?)?.toDouble() ?? 0.0;
        final nodeLng = (node['longitude'] as num?)?.toDouble() ?? 0.0;
        
        if (nodeLat == 0.0 && nodeLng == 0.0) continue;
        
        final distance = _calculateDistance(
          userPosition.latitude,
          userPosition.longitude,
          nodeLat,
          nodeLng,
        );
        
        if (distance <= currentRadius && distance < closestDistance) {
          closestDistance = distance;
          closestNode = node;
          print('🔍 Found node within ${currentRadius}m: ${node['label']} at ${distance.toStringAsFixed(1)}m');
        }
      }
      
      // Found a node within current radius
      if (closestNode != null) {
        print('✅ Closest node: ${closestNode['label']} at ${closestDistance.toStringAsFixed(1)}m');
        _handleNearbyNode(closestNode, closestDistance);
        return;
      }
      
      currentRadius += radiusIncrement;
    }
    
    print('⚠️ No nodes found within ${maxRadius}m');
    
    // No nodes found within max radius
    if (_nearestNode != null) {
      setState(() {
        _nearestNode = null;
        _nearestNodeDistance = double.infinity;
      });
    }
  }

  /// Handle when a nearby node is detected
  void _handleNearbyNode(Map<String, dynamic> node, double distance) {
    print('🔍 _handleNearbyNode called');
    print('🔍 Node: ${node['label']}, Distance: ${distance.toStringAsFixed(1)}m');
    print('🔍 widget.destinationNodeId: ${widget.destinationNodeId}');
    print('🔍 _startNode: ${_startNode != null ? _startNode!['label'] : 'NULL'}');
    
    // Only update if it's a new node or distance changed significantly
    if (_nearestNode == null || 
        _nearestNode!['id'] != node['id'] ||
        (distance - _nearestNodeDistance).abs() > 2.0) {
      
      setState(() {
        _nearestNode = node;
        _nearestNodeDistance = distance;
      });
      
      // Auto-set as start location if:
      // 1. Coming from Intent Navigation (destination pre-selected)
      // 2. Start location not yet set
      // 3. Within reasonable distance (< 50m)
      if (widget.destinationNodeId != null && 
          _startNode == null && 
          distance < 50.0) {
        print('✅ Auto-setting start location...');
        setState(() {
          _startNode = node;
        });
        print('✅ Auto-set start location to nearby node: ${node['label']} (${distance.toStringAsFixed(1)}m away)');
        _showSuccess('Start location set to ${node['label']} (${distance.toStringAsFixed(0)}m away). Walk towards it!');
        
        // Auto-calculate route after setting start
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _endNode != null) {
            _calculateRoute();
          }
        });
      } else {
        print('⚠️ Not auto-setting because:');
        print('   - destinationNodeId is null: ${widget.destinationNodeId == null}');
        print('   - _startNode already set: ${_startNode != null}');
        print('   - distance >= 50m: ${distance >= 50.0}');
        
        // Show notification for new node
        if (_nearestNode!['id'] != node['id']) {
          _showProximityNotification(node, distance);
        }
      }
      
      print('📍 Near ${node['label']}: ${distance.toStringAsFixed(1)}m');
    }
  }

  /// Show notification when near a node
  void _showProximityNotification(Map<String, dynamic> node, double distance) {
    final distanceText = distance < 10 
        ? '${distance.toStringAsFixed(0)}m' 
        : '${distance.toStringAsFixed(1)}m';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You are $distanceText from ${node['label']}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Set as Start',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _startNode = node;
              _useAutoLocation = false;
            });
            _showSuccess('Start location set to ${node['label']}');
          },
        ),
      ),
    );
  }

  /// Calculate distance between two GPS coordinates (Haversine formula)
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

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// Stop proximity detection
  void _stopProximityDetection() {
    _gpsSubscription?.cancel();
    _proximityCheckTimer?.cancel();
    _gpsSubscription = null;
    _proximityCheckTimer = null;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _qrController?.dispose();
    _locationDetectionService.stopDetection();
    _locationDetectionService.dispose();
    _stopProximityDetection();
    super.dispose();
  }

  Future<void> _loadNodes() async {
    setState(() => _isLoading = true);
    try {
      final tokenStorage = getIt<TokenStorage>();
      final token = await tokenStorage.getToken();
      
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/indoor/buildings/${widget.building.id}/indoor-graph'),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final nodesList = data['nodes'] as List;
        
        final mappedNodes = nodesList.map((node) => {
          'id': node['id'],
          'label': node['label'] ?? 'Node ${node['id']}',
          'floor_number': node['floor_number'] ?? 0,
          'node_type': node['node_type'] ?? 'waypoint',
          'latitude': (node['latitude'] ?? 0.0).toDouble(),
          'longitude': (node['longitude'] ?? 0.0).toDouble(),
          'qr_code': node['qr_code'] ?? 'indoor-nav://${widget.building.id}/${node['id']}',
          'edges': node['edges'] ?? [],
        }).toList();
        
        print('🔍 Loaded ${mappedNodes.length} nodes');
        print('🔍 Looking for destinationNodeId: ${widget.destinationNodeId}');
        
        // Find preselected destination before setState
        Map<String, dynamic>? preselectedDestination;
        if (widget.destinationNodeId != null) {
          print('🔍 Searching for destination node...');
          for (var node in mappedNodes) {
            print('🔍 Node ID: ${node['id']}, Label: ${node['label']}');
          }
          
          preselectedDestination = mappedNodes.firstWhere(
            (node) => node['id'] == widget.destinationNodeId,
            orElse: () => {},
          );
          
          if (preselectedDestination.isEmpty) {
            print('❌ Destination node NOT FOUND!');
            preselectedDestination = null;
          } else {
            print('✅ Found destination: ${preselectedDestination['label']} (${preselectedDestination['id']})');
          }
        }
        
        setState(() {
          _nodes = mappedNodes;
          _endNode = preselectedDestination;
          _isLoading = false;
        });
        
        print('🔍 After setState - _endNode: ${_endNode != null ? _endNode!['label'] : 'NULL'}');
        
        if (_nodes.isEmpty) {
          _showError('No navigation points found for this building. Please use the Admin panel to create navigation points first.');
        } else {
          // Only start proximity detection, not auto-location
          _startProximityDetection();
          
          // Show success message if destination was preselected
          if (preselectedDestination != null) {
            _showSuccess('Destination set to ${preselectedDestination['label']}');
          }
        }
      } else {
        setState(() => _isLoading = false);
        _showError('Failed to load navigation data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load locations: $e');
    }
  }

  Future<void> _startAutomaticLocationDetection() async {
    if (!_useAutoLocation || _nodes.isEmpty) return;
    
    setState(() => _isDetectingLocation = true);
    
    // Set building context for location detection
    _locationDetectionService.setBuildingContext(
      buildingId: widget.building.id,
      nodes: _nodes,
      bounds: null, // TODO: Get building bounds from API
    );
    
    // Start detection
    final success = await _locationDetectionService.initialize();
    if (success) {
      await _locationDetectionService.startDetection();
      // Silently start detection without notification
      print('📍 Automatic location detection started');
    } else {
      setState(() => _isDetectingLocation = false);
      print('⚠️ Could not start location detection');
    }
  }

  void _toggleAutoLocation() {
    setState(() {
      _useAutoLocation = !_useAutoLocation;
      
      if (_useAutoLocation) {
        _startAutomaticLocationDetection();
        if (_detectedLocation != null) {
          _startNode = _detectedLocation;
        }
      } else {
        _locationDetectionService.stopDetection();
        _isDetectingLocation = false;
        _startNode = null;
        _detectedLocation = null;
        _locationConfidence = 0.0;
      }
    });
  }

  Future<void> _calculateRoute() async {
    print('🔍 _calculateRoute called');
    print('🔍 _useAutoLocation: $_useAutoLocation');
    print('🔍 _detectedLocation: ${_detectedLocation != null ? _detectedLocation!['label'] : 'NULL'}');
    print('🔍 _startNode: ${_startNode != null ? _startNode!['label'] : 'NULL'}');
    print('🔍 _endNode: ${_endNode != null ? _endNode!['label'] : 'NULL'}');
    
    // Use detected location if auto-location is enabled and available
    if (_useAutoLocation && _detectedLocation != null) {
      _startNode = _detectedLocation;
      print('🔍 Set _startNode to detected location: ${_startNode!['label']}');
    }
    
    // Check if we have both start and end nodes
    if (_endNode == null) {
      print('❌ End node is null');
      _showError('Please select a destination');
      return;
    }
    
    if (_startNode == null) {
      print('❌ Start node is null');
      if (_useAutoLocation) {
        _showError('Waiting for location detection. Turn off Auto-Detect or use "Set as Start" from nearby location.');
      } else {
        _showError('Please select a start location or enable Auto-Detect');
      }
      return;
    }
    
    print('✅ Both nodes available, proceeding with route calculation');

    setState(() => _isLoading = true);
    try {
      final tokenStorage = getIt<TokenStorage>();
      final token = await tokenStorage.getToken();
      
      // If using detected location, find nearest node for API call
      String fromNodeId = _startNode!['id'];
      if (_useAutoLocation && _detectedLocation != null) {
        final nearestNode = _locationDetectionService.findNearestNode();
        if (nearestNode != null) {
          fromNodeId = nearestNode['id'];
          print('📍 Using nearest node: ${nearestNode['label']} for route calculation');
        }
      }
      
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/indoor/buildings/${widget.building.id}/indoor-graph/route'
            '?from_node=$fromNodeId&to_node=${_endNode!['id']}'),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['path'] != null && (data['path'] as List).isNotEmpty) {
          final pathNodeIds = List<String>.from(data['path']);
          
          // Map path node IDs to full node objects
          setState(() {
            _route = pathNodeIds.map((nodeId) {
              final node = _nodes.firstWhere(
                (n) => n['id'] == nodeId,
                orElse: () => {
                  'id': nodeId,
                  'label': 'Node $nodeId',
                  'latitude': 0.0,
                  'longitude': 0.0,
                },
              );
              return node;
            }).toList();
            _currentPosition = _startNode;
            _isLoading = false;
          });

          final totalSteps = data['total_steps'] ?? _route.length;
          final eta = data['eta'];
          final etaText = eta != null ? ' (${eta['time_formatted']})' : '';
          _showSuccess('Route calculated: $totalSteps steps$etaText');
          
          // Start continuous position tracking during navigation
          if (_useAutoLocation) {
            _startContinuousTracking();
          }
        } else {
          setState(() => _isLoading = false);
          _showError('No route found between these locations');
        }
      } else {
        setState(() => _isLoading = false);
        _showError('Failed to calculate route: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to calculate route: $e');
    }
  }

  void _startContinuousTracking() {
    // Monitor position changes and recalculate route if user deviates
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_route.isEmpty) {
        timer.cancel();
        return;
      }
      
      _checkIfOffRoute();
    });
  }

  void _checkIfOffRoute() {
    if (_detectedLocation == null || _route.isEmpty) return;
    
    final currentX = _detectedLocation!['latitude'];
    final currentY = _detectedLocation!['longitude'];
    
    // Check distance to current route segment
    bool isOffRoute = true;
    const offRouteThreshold = 10.0; // meters
    
    for (int i = 0; i < _route.length - 1; i++) {
      final segmentStart = _route[i];
      final segmentEnd = _route[i + 1];
      
      final distance = _perpendicularDistance(
        currentX,
        currentY,
        segmentStart['latitude'],
        segmentStart['longitude'],
        segmentEnd['latitude'],
        segmentEnd['longitude'],
      );
      
      if (distance < offRouteThreshold) {
        isOffRoute = false;
        break;
      }
    }
    
    if (isOffRoute) {
      _showWarning('You are off route. Recalculating...');
      _recalculateRoute();
    }
  }

  Future<void> _recalculateRoute() async {
    if (_endNode == null || _detectedLocation == null) return;
    
    // Update start node to current detected location
    _startNode = _detectedLocation;
    
    // Recalculate route
    await _calculateRoute();
    
    _showSuccess('Route recalculated from your current location');
  }

  double _perpendicularDistance(
    double px,
    double py,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final lengthSquared = dx * dx + dy * dy;

    if (lengthSquared == 0) {
      final distX = px - x1;
      final distY = py - y1;
      return (distX * distX + distY * distY).abs();
    }

    final t = ((px - x1) * dx + (py - y1) * dy) / lengthSquared;
    final clampedT = t.clamp(0.0, 1.0);
    final projectionX = x1 + clampedT * dx;
    final projectionY = y1 + clampedT * dy;

    final distX = px - projectionX;
    final distY = py - projectionY;
    return (distX * distX + distY * distY).abs();
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showError('No camera available');
        return;
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      setState(() => _isCameraActive = true);
      
      // Start PDR engine for position tracking
      _pdrEngine.start();
    } catch (e) {
      _showError('Failed to open camera: $e');
    }
  }

  void _closeCamera() {
    _cameraController?.dispose();
    _cameraController = null;
    // PDR engine doesn't have a stop method, it stops automatically
    setState(() => _isCameraActive = false);
  }

  Future<void> _openARNavigation() async {
    if (_route.isEmpty) {
      _showError('Please calculate a route first');
      return;
    }

    // Navigate to AR Navigation Page
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArNavigationPage(
            buildingName: widget.building.name,
            route: _route,
            initialRouteIndex: 0,
          ),
        ),
      );
    }
  }

  void _openQRScanner() {
    _qrController = MobileScannerController();
    setState(() => _isQRScannerActive = true);
  }

  void _closeQRScanner() {
    _qrController?.dispose();
    _qrController = null;
    setState(() => _isQRScannerActive = false);
  }

  Future<void> _handleQRCode(String qrData) async {
    try {
      // Parse QR code: indoor-nav://building_id/node_id
      if (qrData.startsWith('indoor-nav://')) {
        final parts = qrData.replaceFirst('indoor-nav://', '').split('/');
        if (parts.length >= 2) {
          final buildingId = parts[0];
          final nodeId = parts[1];

          if (buildingId != widget.building.id) {
            _showError('QR code is for a different building');
            return;
          }

          // Find the node
          final node = _nodes.firstWhere(
            (n) => n['id'] == nodeId,
            orElse: () => {},
          );

          if (node.isEmpty) {
            _showError('Node not found');
            return;
          }

          // Reset position to scanned location
          setState(() {
            _currentPosition = node;
            _startNode = node;
          });

          // Reset PDR engine to this position (x, y, floor, heading)
          _pdrEngine.resetPosition(
            node['latitude'],
            node['longitude'],
            node['floor_number'] ?? 0,
            0.0, // heading - default to 0
          );

          _closeQRScanner();
          _showSuccess('Position reset to: ${node['label']}');

          // Recalculate route if end node is selected
          if (_endNode != null) {
            await _calculateRoute();
          }
        }
      }
    } catch (e) {
      _showError('Failed to process QR code: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isQRScannerActive) {
      return _buildQRScanner();
    }

    if (_isCameraActive) {
      return _buildCameraNavigation();
    }

    return _buildLocationSelection();
  }

  Widget _buildLocationSelection() {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text('Navigate ${widget.building.name}'),
        backgroundColor: AppColors.surfaceDark,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // No nodes warning
                  if (_nodes.isEmpty)
                    Card(
                      color: Colors.orange.shade900.withOpacity(0.3),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber, color: Colors.orange.shade400, size: 32),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'No Navigation Data',
                                        style: TextStyle(
                                          color: Colors.orange.shade400,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'This building has no navigation points yet.',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'To use navigation:',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildStep('1', 'Go to Admin Dashboard → Coordinate Collection'),
                            const SizedBox(height: 4),
                            _buildStep('2', 'Select this building and create navigation points'),
                            const SizedBox(height: 4),
                            _buildStep('3', 'Save the navigation graph'),
                            const SizedBox(height: 4),
                            _buildStep('4', 'Return here to navigate'),
                          ],
                        ),
                      ),
                    ),
                  if (_nodes.isEmpty) const SizedBox(height: 20),
                  
                  // Nearby Node Card (Proximity Detection)
                  if (_nearestNode != null && _nearestNodeDistance < 50)
                    Card(
                      color: AppColors.surfaceDark,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryOrange.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryOrange.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.near_me,
                                      color: AppColors.primaryOrange,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Nearby Location',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _nearestNode!['label'] ?? 'Unknown',
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryOrange,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${_nearestNodeDistance.toStringAsFixed(0)}m',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _startNode = _nearestNode;
                                          _useAutoLocation = false;
                                        });
                                        _showSuccess('Start location set to ${_nearestNode!['label']}');
                                      },
                                      icon: const Icon(Icons.my_location, size: 16),
                                      label: const Text('Set as Start', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primaryOrange,
                                        side: const BorderSide(color: AppColors.primaryOrange),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _endNode = _nearestNode;
                                        });
                                        _showSuccess('Destination set to ${_nearestNode!['label']}');
                                      },
                                      icon: const Icon(Icons.flag, size: 16),
                                      label: const Text('Set as Dest', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryOrange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_nearestNode != null && _nearestNodeDistance < 50) const SizedBox(height: 16),
                  
                  // Current Position Card
                  if (_currentPosition != null)
                    Card(
                      color: AppColors.surfaceDark,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.my_location, color: AppColors.primaryOrange),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Current Position',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _currentPosition!['label'] ?? 'Unknown',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Auto Location Toggle
                  Card(
                    color: AppColors.surfaceDark,
                    child: SwitchListTile(
                      title: const Text(
                        'Auto-Detect Start Location',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        _useAutoLocation
                            ? (_isDetectingLocation
                                ? 'Detecting your location...'
                                : 'Using detected location')
                            : 'Select start location manually',
                        style: TextStyle(
                          color: _useAutoLocation && _locationConfidence > 0.7
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      value: _useAutoLocation,
                      activeColor: AppColors.primaryOrange,
                      onChanged: (value) => _toggleAutoLocation(),
                      secondary: Icon(
                        _useAutoLocation ? Icons.gps_fixed : Icons.gps_off,
                        color: _useAutoLocation ? AppColors.primaryOrange : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  
                  // Location Detection Status
                  if (_useAutoLocation && _detectedLocation != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Card(
                        color: _locationConfidence > 0.7
                            ? Colors.green.shade900.withOpacity(0.3)
                            : Colors.orange.shade900.withOpacity(0.3),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                _locationConfidence > 0.7
                                    ? Icons.check_circle
                                    : Icons.warning_amber,
                                color: _locationConfidence > 0.7
                                    ? Colors.green.shade400
                                    : Colors.orange.shade400,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Location: ${_detectedLocation!['label']}',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Confidence: ${(_locationConfidence * 100).toStringAsFixed(0)}%',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '• Floor ${_detectedLocation!['floor_number']}',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Start Location (only show if not using auto-location)
                  if (!_useAutoLocation) ...[
                    const Text(
                      'Start Location',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, dynamic>>(
                          value: _startNode,
                          isExpanded: true,
                          hint: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Select start location',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                          dropdownColor: AppColors.cardDark,
                          icon: const Padding(
                            padding: EdgeInsets.only(right: 16),
                            child: Icon(Icons.arrow_drop_down, color: AppColors.primaryOrange),
                          ),
                          items: _nodes.map((node) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: node,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  '${node['label']} (Floor ${node['floor_number']})',
                                  style: const TextStyle(color: AppColors.textPrimary),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (node) {
                            setState(() => _startNode = node);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Info card when destination is pre-selected from Intent Navigation
                  if (widget.destinationNodeId != null && _endNode != null) ...[
                    Card(
                      color: Colors.deepPurple.withOpacity(0.2),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.deepPurple.shade300,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Destination Pre-Selected',
                                    style: TextStyle(
                                      color: Colors.deepPurple.shade200,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _startNode == null
                                        ? 'Walk near any location to auto-detect your start point, or select manually below'
                                        : 'Start location detected! Ready to calculate route.',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // End Location
                  const Text(
                    'Destination',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        value: _endNode,
                        isExpanded: true,
                        hint: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Select destination',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        dropdownColor: AppColors.cardDark,
                        icon: const Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: Icon(Icons.arrow_drop_down, color: AppColors.primaryOrange),
                        ),
                        items: _nodes.map((node) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: node,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                '${node['label']} (Floor ${node['floor_number']})',
                                style: const TextStyle(color: AppColors.textPrimary),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (node) {
                          setState(() => _endNode = node);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Calculate Route Button
                  ElevatedButton.icon(
                    onPressed: _calculateRoute,
                    icon: const Icon(Icons.route),
                    label: const Text('Calculate Route'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Camera Navigation Button
                  OutlinedButton.icon(
                    onPressed: _route.isNotEmpty ? _openCamera : null,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Start Camera Navigation'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryOrange,
                      side: const BorderSide(color: AppColors.primaryOrange),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // AR Navigation Button
                  if (_route.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _openARNavigation,
                      icon: const Icon(Icons.spatial_tracking_outlined),
                      label: const Text('Start AR Navigation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  if (_route.isNotEmpty) const SizedBox(height: 16),

                  // QR Scanner Button
                  OutlinedButton.icon(
                    onPressed: _openQRScanner,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR to Set Position'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.textSecondary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  // Route Info
                  if (_route.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Card(
                      color: AppColors.surfaceDark,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Route Information',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.straighten, color: AppColors.primaryOrange, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${_route.length} waypoints',
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildCameraNavigation() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          if (_cameraController != null && _cameraController!.value.isInitialized)
            SizedBox.expand(
              child: CameraPreview(_cameraController!),
            ),

          // Navigation Overlay
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black54,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _closeCamera,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Camera Navigation',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_endNode != null)
                              Text(
                                'To: ${_endNode!['label']}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _openQRScanner,
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Bottom Navigation Info
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
                      if (_currentPosition != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.navigation, color: Colors.white),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Current Position',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      _currentPosition!['label'] ?? 'Unknown',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildQRScanner() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // QR Scanner
          MobileScanner(
            controller: _qrController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  _handleQRCode(code);
                }
              }
            },
          ),

          // Overlay
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black54,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _closeQRScanner,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          'Scan QR Code to Set Position',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Instructions
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.qr_code_2, color: AppColors.primaryOrange, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'Point camera at QR code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your position will be reset to the scanned location',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primaryOrange.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryOrange, width: 1.5),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: AppColors.primaryOrange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
