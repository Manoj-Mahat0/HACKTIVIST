import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:pedometer/pedometer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:indoor_navigation/features/buildings/presentation/bloc/buildings_bloc.dart';
import 'package:indoor_navigation/features/buildings/domain/entities/building.dart';
import 'package:indoor_navigation/core/storage/token_storage.dart';
import 'package:indoor_navigation/core/theme/app_theme.dart';
import 'package:indoor_navigation/features/admin/presentation/widgets/building_3d_viewer.dart';

class CoordinateCollectionPage extends StatefulWidget {
  const CoordinateCollectionPage({super.key});

  @override
  State<CoordinateCollectionPage> createState() => _CoordinateCollectionPageState();
}

class _CoordinateCollectionPageState extends State<CoordinateCollectionPage> 
    with SingleTickerProviderStateMixin {
  static const String _apiBaseUrl = 'https://be.google.knocknockindia.com';
  
  // State
  Building? _selectedBuilding;
  final List<IndoorNode> _nodes = [];
  int _currentFloor = 0;
  bool _isLoading = false;
  bool _isRecording = false;
  bool _is3DView = false; // Toggle for 3D view
  BuildingInteractionController? _3dController; // Controller for 3D view
  
  // Sensors
  double _currentHeading = 0;
  int _stepCount = 0;
  int _startStepCount = 0;
  String _currentDirection = 'N';
  Position? _currentPosition;
  
  // Streams
  StreamSubscription<dynamic>? _compassSubscription;
  StreamSubscription<dynamic>? _stepSubscription;
  StreamSubscription<Position>? _positionSubscription;
  
  // Animation
  late AnimationController _pulseController;
  
  // For connecting nodes
  IndoorNode? _lastNode;
  
  // Image picker
  final ImagePicker _imagePicker = ImagePicker();
  
  // User preferences
  double _userStepLength = 0.7; // Default step length in meters
  bool _preferAccessible = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _3dController = BuildingInteractionController();
    
    context.read<BuildingsBloc>().add(LoadBuildingsEvent());
    _initSensors();
  }


  @override
  void dispose() {
    _pulseController.dispose();
    _3dController?.dispose();
    _compassSubscription?.cancel();
    _stepSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initSensors() async {
    // Request permissions
    await Permission.activityRecognition.request();
    await Permission.location.request();
    
    // Initialize compass using flutter_compass
    try {
      final compassStream = FlutterCompass.events;
      if (compassStream != null) {
        _compassSubscription = compassStream.listen((CompassEvent event) {
          if (mounted && event.heading != null) {
            setState(() {
              _currentHeading = event.heading!;
              _currentDirection = _headingToDirection(_currentHeading);
            });
          }
        });
      } else {
        debugPrint('Compass not available on this device');
        // Set default values
        _currentHeading = 0;
        _currentDirection = 'N';
      }
    } catch (e) {
      debugPrint('Compass initialization error: $e');
      _currentHeading = 0;
      _currentDirection = 'N';
    }
    
    // Initialize pedometer using pedometer_2
    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        (StepCount stepCount) {
          if (mounted) {
            setState(() {
              _stepCount = stepCount.steps;
            });
          }
        },
        onError: (error) {
          debugPrint('Pedometer error: $error');
        },
      );
    } catch (e) {
      debugPrint('Pedometer initialization error: $e');
      // Pedometer might not be available on emulator
      _stepCount = 0;
    }
    
    // Initialize GPS
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((position) {
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    });
  }

  String _headingToDirection(double heading) {
    if (heading >= 337.5 || heading < 22.5) return 'N';
    if (heading >= 22.5 && heading < 67.5) return 'NE';
    if (heading >= 67.5 && heading < 112.5) return 'E';
    if (heading >= 112.5 && heading < 157.5) return 'SE';
    if (heading >= 157.5 && heading < 202.5) return 'S';
    if (heading >= 202.5 && heading < 247.5) return 'SW';
    if (heading >= 247.5 && heading < 292.5) return 'W';
    if (heading >= 292.5 && heading < 337.5) return 'NW';
    return 'N';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildBuildingSelector(),
            if (_selectedBuilding != null) ...[
              _buildSensorPanel(),
              _buildFloorSelector(),
              Expanded(child: _buildFloorView()),
              _buildBottomActions(),
            ] else
              Expanded(child: _buildEmptyState()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Indoor Graph Builder',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_nodes.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_nodes.length} nodes',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildBuildingSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: BlocBuilder<BuildingsBloc, BuildingsState>(
        builder: (context, state) {
          // Handle loading state
          if (state is BuildingsLoadingState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading buildings...',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ],
              ),
            );
          }
          
          // Handle error state
          if (state is BuildingsErrorState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Error loading buildings',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<BuildingsBloc>().add(LoadBuildingsEvent());
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            );
          }
          
          // Handle loaded state
          if (state is BuildingsLoadedState) {
            final buildings = state.buildings;
            
            if (buildings.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.business_outlined, color: Colors.white38, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'No buildings available',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create a building first from Building Management',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            
            return DropdownButtonFormField<Building>(
              initialValue: _selectedBuilding,
              dropdownColor: AppColors.surfaceDark,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.business, color: AppColors.primaryOrange),
                hintText: 'Select Building (${buildings.length} available)',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              isExpanded: true,
              items: buildings.map((b) {
                final hasBoundary = b.boundaryPoints != null && b.boundaryPoints!.length >= 3;
                return DropdownMenuItem(
                  value: b,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: hasBoundary ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: hasBoundary ? Colors.green : Colors.orange,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasBoundary ? Icons.check_circle : Icons.warning_amber,
                              color: hasBoundary ? Colors.green : Colors.orange,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasBoundary ? 'GPS' : 'No GPS',
                              style: TextStyle(
                                color: hasBoundary ? Colors.green : Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (b) {
                setState(() {
                  _selectedBuilding = b;
                  _nodes.clear();
                  _lastNode = null;
                });
                if (b != null) {
                  // Warn if building has no boundary
                  if (b.boundaryPoints == null || b.boundaryPoints!.length < 3) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('GPS validation disabled for this building'),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                  _loadExistingGraph(b.id);
                }
              },
            );
          }
          
          // Handle initial/other states - show loading indicator and trigger load
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Initializing...',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSensorPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryOrange.withOpacity(0.8),
            AppColors.primaryOrange.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Compass
          Expanded(
            child: _buildSensorCard(
              icon: Icons.explore,
              label: 'Direction',
              value: _currentDirection,
              subtitle: '${_currentHeading.toStringAsFixed(0)}°',
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white24),
          // Steps
          Expanded(
            child: _buildSensorCard(
              icon: Icons.directions_walk,
              label: 'Steps',
              value: _isRecording 
                  ? '${_stepCount - _startStepCount}'
                  : '0',
              subtitle: _isRecording ? 'Recording...' : 'Tap to start',
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white24),
          // GPS
          Expanded(
            child: _buildSensorCard(
              icon: Icons.gps_fixed,
              label: 'GPS',
              value: _currentPosition != null ? '✓' : '...',
              subtitle: _currentPosition != null 
                  ? '${_currentPosition!.accuracy.toStringAsFixed(0)}m'
                  : 'Waiting',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildFloorSelector() {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 13, // -2 to 10
        itemBuilder: (context, index) {
          final floor = index - 2;
          final nodesOnFloor = _nodes.where((n) => n.floorNumber == floor).length;
          final isSelected = floor == _currentFloor;
          
          return GestureDetector(
            onTap: () => setState(() => _currentFloor = floor),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryOrange : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primaryOrange : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'F$floor',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (nodesOnFloor > 0) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$nodesOnFloor',
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildFloorView() {
    final floorNodes = _nodes.where((n) => n.floorNumber == _currentFloor).toList();
    
    if (_selectedBuilding == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Grid background
            CustomPaint(
              size: Size.infinite,
              painter: _GridPainter(),
            ),
            
            // Floor label
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Floor $_currentFloor',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            
            // 2D/3D Toggle Button
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _is3DView = !_is3DView;
                  });
                  // Show feedback
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _is3DView ? 'Switched to 3D View' : 'Switched to 2D View',
                      ),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: _is3DView ? AppColors.primaryOrange : Colors.grey.shade800,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _is3DView ? AppColors.primaryOrange : Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _is3DView ? AppColors.primaryOrange : Colors.white24,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_is3DView ? AppColors.primaryOrange : Colors.black)
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _is3DView ? Icons.view_in_ar : Icons.map,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _is3DView ? '3D' : '2D',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Nodes visualization
            if (floorNodes.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_location_alt, size: 48, color: Colors.white24),
                      const SizedBox(height: 8),
                      Text(
                        'No nodes on Floor $_currentFloor',
                        style: const TextStyle(color: Colors.white38),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap + to add a node',
                        style: TextStyle(color: Colors.white24, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
          else
            _is3DView ? _build3DFloorView(floorNodes) : _build2DFloorView(floorNodes),
        ],
      ),
      ),
    );
  }

  Widget _build2DFloorView(List<IndoorNode> floorNodes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _NodesPainter(
            nodes: floorNodes,
            allNodes: _nodes,
            building: _selectedBuilding!,
            lastNode: _lastNode,
          ),
          child: Stack(
            children: floorNodes.map((node) {
              final pos = _getNodePosition(node, constraints);
              return Positioned(
                left: pos.dx - 20,
                top: pos.dy - 20,
                child: GestureDetector(
                  onTap: () => _showNodeOptions(node),
                  child: _buildNodeWidget(node),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _build3DFloorView(List<IndoorNode> floorNodes) {
    if (_3dController == null) return const SizedBox.shrink();
    
    // Show message if no nodes
    if (floorNodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.view_in_ar,
              size: 64,
              color: AppColors.primaryOrange.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              '3D View',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add nodes to see 3D visualization',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    // Convert nodes to rooms for 3D visualization
    final rooms3D = floorNodes.asMap().entries.map((entry) {
      final index = entry.key;
      final node = entry.value;
      
      // Calculate position in a grid layout
      final gridSize = math.sqrt(floorNodes.length.toDouble()).ceil();
      final row = index ~/ gridSize;
      final col = index % gridSize;
      
      return Room3D(
        id: node.id,
        name: node.label,
        type: _getNodeRoomType(node.nodeType),
        x: 0.1 + (col * 0.8 / gridSize),
        y: 0.1 + (row * 0.8 / gridSize),
        width: 0.7 / gridSize,
        depth: 0.7 / gridSize,
        height: 2.5,
      );
    }).toList();

    final floor3D = Floor3D(
      floorNumber: _currentFloor,
      rooms: rooms3D,
    );

    final building3D = Building3D(
      name: _selectedBuilding?.name ?? 'Building',
      floors: [floor3D],
    );

    return GestureDetector(
      onScaleStart: (details) {
        // Store initial values
      },
      onScaleUpdate: (details) {
        if (details.scale != 1.0) {
          // Pinch to zoom
          _3dController!.updateScale(details.scale);
        } else {
          // Drag to rotate
          _3dController!.updateRotation(
            details.focalPointDelta.dy * 0.01,
            details.focalPointDelta.dx * 0.01,
          );
        }
      },
      child: Stack(
        children: [
          // Main 3D viewer
          AnimatedBuilder(
            animation: _3dController!,
            builder: (context, child) {
              return CustomPaint(
                painter: Building3DPainter(
                  building: building3D,
                  controller: _3dController!,
                ),
                size: Size.infinite,
              );
            },
          ),
          
          // 3D Controls overlay
          Positioned(
            right: 16,
            top: 60,
            child: _build3DControls(),
          ),
          
          // Instructions overlay
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: AppColors.primaryOrange,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Drag to rotate',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pinch,
                        color: AppColors.primaryOrange,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Pinch to zoom',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  RoomType _getNodeRoomType(String nodeType) {
    switch (nodeType.toLowerCase()) {
      case 'entrance':
      case 'exit':
        return RoomType.lobby;
      case 'elevator':
        return RoomType.elevator;
      case 'stairs':
        return RoomType.stairs;
      case 'bathroom':
      case 'restroom':
        return RoomType.restroom;
      case 'room':
        return RoomType.office;
      default:
        return RoomType.office;
    }
  }

  Widget _build3DControls() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _build3DControlButton(
            icon: Icons.view_in_ar,
            tooltip: 'Isometric',
            onPressed: () => _3dController?.setIsometricView(),
          ),
          const Divider(height: 1, color: Colors.white24),
          _build3DControlButton(
            icon: Icons.view_agenda,
            tooltip: 'Top View',
            onPressed: () => _3dController?.setTopView(),
          ),
          const Divider(height: 1, color: Colors.white24),
          _build3DControlButton(
            icon: Icons.zoom_in,
            tooltip: 'Zoom In',
            onPressed: () => _3dController?.updateScale(1.2),
          ),
          const Divider(height: 1, color: Colors.white24),
          _build3DControlButton(
            icon: Icons.zoom_out,
            tooltip: 'Zoom Out',
            onPressed: () => _3dController?.updateScale(0.8),
          ),
          const Divider(height: 1, color: Colors.white24),
          _build3DControlButton(
            icon: Icons.refresh,
            tooltip: 'Reset',
            onPressed: () => _3dController?.reset(),
          ),
        ],
      ),
    );
  }

  Widget _build3DControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Offset _getNodePosition(IndoorNode node, BoxConstraints constraints) {
    if (_selectedBuilding == null || _selectedBuilding!.boundaryPoints == null || _selectedBuilding!.boundaryPoints!.length < 3) {
      // Fallback: center the node if no boundary
      return Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
    }
    
    final boundary = _selectedBuilding!.boundaryPoints!;
    double minLat = boundary.map((p) => p['lat']!).reduce(math.min);
    double maxLat = boundary.map((p) => p['lat']!).reduce(math.max);
    double minLng = boundary.map((p) => p['lng']!).reduce(math.min);
    double maxLng = boundary.map((p) => p['lng']!).reduce(math.max);
    
    // Ensure we have valid dimensions
    if (constraints.maxWidth < 40 || constraints.maxHeight < 40) {
      return Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
    }
    
    double x = ((node.longitude - minLng) / (maxLng - minLng)) * (constraints.maxWidth - 40) + 20;
    double y = ((maxLat - node.latitude) / (maxLat - minLat)) * (constraints.maxHeight - 40) + 20;
    
    return Offset(
      x.clamp(20.0, constraints.maxWidth - 20.0), 
      y.clamp(20.0, constraints.maxHeight - 20.0)
    );
  }

  Widget _buildNodeWidget(IndoorNode node) {
    final isLast = _lastNode?.id == node.id;
    final hasConnections = node.edges.isNotEmpty;
    
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLast 
                ? AppColors.primaryOrange 
                : hasConnections ? Colors.green : Colors.red,
            boxShadow: isLast ? [
              BoxShadow(
                color: AppColors.primaryOrange.withOpacity(0.5 * _pulseController.value),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ] : null,
          ),
          child: Center(
            child: Icon(
              _getNodeIcon(node.nodeType),
              color: Colors.white,
              size: 20,
            ),
          ),
        );
      },
    );
  }

  IconData _getNodeIcon(String type) {
    switch (type) {
      case 'entrance': return Icons.door_front_door;
      case 'exit': return Icons.exit_to_app;
      case 'elevator': return Icons.elevator;
      case 'stairs': return Icons.stairs;
      case 'bathroom': return Icons.wc;
      case 'room': return Icons.meeting_room;
      default: return Icons.location_on;
    }
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 80, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            'Select a building to start',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'All buildings are available for indoor graph creation',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick actions row
          Row(
            children: [
              // Validate button
              Expanded(
                child: _buildQuickAction(
                  icon: Icons.check_circle_outline,
                  label: 'Validate',
                  color: Colors.purple,
                  onTap: _validateGraph,
                ),
              ),
              const SizedBox(width: 8),
              // Export button
              Expanded(
                child: _buildQuickAction(
                  icon: Icons.download,
                  label: 'Export',
                  color: Colors.teal,
                  onTap: _exportGraph,
                ),
              ),
              const SizedBox(width: 8),
              // Settings button
              Expanded(
                child: _buildQuickAction(
                  icon: Icons.settings,
                  label: 'Settings',
                  color: Colors.grey,
                  onTap: _showSettingsDialog,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Main actions row
          Row(
            children: [
              // Recording button
              Expanded(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return ElevatedButton.icon(
                      onPressed: _toggleRecording,
                      icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
                      label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRecording 
                            ? Colors.red.withOpacity(0.8 + 0.2 * _pulseController.value)
                            : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              
              // Add node button
              FloatingActionButton(
                heroTag: 'add_node',
                onPressed: _addNode,
                backgroundColor: AppColors.primaryOrange,
                child: const Icon(Icons.add_location),
              ),
              const SizedBox(width: 12),
              
              // Save button
              FloatingActionButton(
                heroTag: 'save_graph',
                onPressed: _nodes.isNotEmpty ? _saveGraph : null,
                backgroundColor: _nodes.isNotEmpty ? Colors.blue : Colors.grey,
                child: const Icon(Icons.save),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }


  // ============================================
  // ACTIONS
  // ============================================

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _startStepCount = _stepCount;
      }
    });
  }

  void _addNode() {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for GPS...'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    // Check if inside boundary
    if (!_isInsideBoundary(_currentPosition!.latitude, _currentPosition!.longitude)) {
      _showOutsideBoundaryDialog();
      return;
    }
    
    _showAddNodeDialog();
  }

  void _showOutsideBoundaryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Outside Boundary'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You are currently outside the building boundary.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildBoundaryMapView(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.3),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Building boundary', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.my_location, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text('Your location', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Please move inside the boundary to add nodes.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildBoundaryMapView() {
    if (_selectedBuilding?.boundaryPoints == null || _currentPosition == null) {
      return const Center(child: Text('Map unavailable'));
    }

    final boundary = _selectedBuilding!.boundaryPoints!;
    final boundaryLatLngs = boundary
        .map((p) => LatLng(p['lat']!, p['lng']!))
        .toList();

    // Calculate bounds to fit both boundary and current position
    double minLat = boundary.map((p) => p['lat']!).reduce(math.min);
    double maxLat = boundary.map((p) => p['lat']!).reduce(math.max);
    double minLng = boundary.map((p) => p['lng']!).reduce(math.min);
    double maxLng = boundary.map((p) => p['lng']!).reduce(math.max);

    // Include current position in bounds
    minLat = math.min(minLat, _currentPosition!.latitude);
    maxLat = math.max(maxLat, _currentPosition!.latitude);
    minLng = math.min(minLng, _currentPosition!.longitude);
    maxLng = math.max(maxLng, _currentPosition!.longitude);

    final center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: center,
        zoom: 18,
      ),
      markers: {
        Marker(
          markerId: const MarkerId('current_position'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      },
      polygons: {
        Polygon(
          polygonId: const PolygonId('boundary'),
          points: boundaryLatLngs,
          strokeColor: Colors.blue,
          strokeWidth: 3,
          fillColor: Colors.blue.withOpacity(0.2),
        ),
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        // Fit bounds after map is created
        Future.delayed(const Duration(milliseconds: 500), () {
          controller.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(minLat, minLng),
                northeast: LatLng(maxLat, maxLng),
              ),
              50, // padding
            ),
          );
        });
      },
    );
  }

  void _showAddNodeDialog() {
    final labelController = TextEditingController();
    final landmarkController = TextEditingController();
    String nodeType = 'waypoint';
    String? category;
    bool isEmergencyExit = false;
    bool isAccessible = true;
    String? imageUrl;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.add_location, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'Add Node',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Floor $_currentFloor',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Auto-detected info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _infoRow(Icons.explore, 'Direction', _currentDirection),
                      const Divider(color: Colors.white24),
                      _infoRow(Icons.directions_walk, 'Steps from last', 
                          _isRecording ? '${_stepCount - _startStepCount}' : '0'),
                      const Divider(color: Colors.white24),
                      _infoRow(Icons.gps_fixed, 'GPS', 
                          '${_currentPosition?.latitude.toStringAsFixed(6)}, ${_currentPosition?.longitude.toStringAsFixed(6)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Label input
                TextField(
                  controller: labelController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Node Label *',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'e.g., Room 101, Main Entrance',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Landmark description
                TextField(
                  controller: landmarkController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Landmark Description',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'e.g., Near the water fountain, Blue door on left',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.visibility, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Node type selector
                const Text('Node Type', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _nodeTypeChip('waypoint', 'Waypoint', Icons.location_on, nodeType, (v) => setSheetState(() => nodeType = v)),
                    _nodeTypeChip('room', 'Room', Icons.meeting_room, nodeType, (v) => setSheetState(() => nodeType = v)),
                    _nodeTypeChip('entrance', 'Entrance', Icons.door_front_door, nodeType, (v) => setSheetState(() => nodeType = v)),
                    _nodeTypeChip('exit', 'Exit', Icons.exit_to_app, nodeType, (v) => setSheetState(() => nodeType = v)),
                    _nodeTypeChip('elevator', 'Elevator', Icons.elevator, nodeType, (v) => setSheetState(() => nodeType = v)),
                    _nodeTypeChip('stairs', 'Stairs', Icons.stairs, nodeType, (v) => setSheetState(() => nodeType = v)),
                    _nodeTypeChip('bathroom', 'Bathroom', Icons.wc, nodeType, (v) => setSheetState(() => nodeType = v)),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Category selector for intent-based navigation
                const Text('Category (for intent-based navigation)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: category,
                      hint: const Text('Select category (optional)', style: TextStyle(color: Colors.white54)),
                      isExpanded: true,
                      dropdownColor: AppColors.surfaceDark,
                      style: const TextStyle(color: Colors.white),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('None', style: TextStyle(color: Colors.white70))),
                        DropdownMenuItem(value: 'food', child: Row(children: [Icon(Icons.restaurant, size: 16, color: Colors.orange), SizedBox(width: 8), Text('Food & Dining')])),
                        DropdownMenuItem(value: 'shopping', child: Row(children: [Icon(Icons.shopping_bag, size: 16, color: Colors.pink), SizedBox(width: 8), Text('Shopping')])),
                        DropdownMenuItem(value: 'services', child: Row(children: [Icon(Icons.business_center, size: 16, color: Colors.blue), SizedBox(width: 8), Text('Services')])),
                        DropdownMenuItem(value: 'entertainment', child: Row(children: [Icon(Icons.movie, size: 16, color: Colors.purple), SizedBox(width: 8), Text('Entertainment')])),
                        DropdownMenuItem(value: 'health', child: Row(children: [Icon(Icons.local_hospital, size: 16, color: Colors.red), SizedBox(width: 8), Text('Health & Medical')])),
                        DropdownMenuItem(value: 'education', child: Row(children: [Icon(Icons.school, size: 16, color: Colors.green), SizedBox(width: 8), Text('Education')])),
                        DropdownMenuItem(value: 'office', child: Row(children: [Icon(Icons.work, size: 16, color: Colors.blueGrey), SizedBox(width: 8), Text('Office')])),
                        DropdownMenuItem(value: 'parking', child: Row(children: [Icon(Icons.local_parking, size: 16, color: Colors.grey), SizedBox(width: 8), Text('Parking')])),
                        DropdownMenuItem(value: 'amenities', child: Row(children: [Icon(Icons.local_convenience_store, size: 16, color: Colors.teal), SizedBox(width: 8), Text('Amenities')])),
                      ],
                      onChanged: (value) => setSheetState(() => category = value),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Special flags
                Row(
                  children: [
                    Expanded(
                      child: _buildToggleOption(
                        icon: Icons.emergency,
                        label: 'Emergency Exit',
                        value: isEmergencyExit,
                        color: Colors.red,
                        onChanged: (v) => setSheetState(() => isEmergencyExit = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildToggleOption(
                        icon: Icons.accessible,
                        label: 'Accessible',
                        value: isAccessible,
                        color: Colors.blue,
                        onChanged: (v) => setSheetState(() => isAccessible = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Photo capture
                InkWell(
                  onTap: () async {
                    final XFile? image = await _imagePicker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 800,
                      maxHeight: 600,
                      imageQuality: 80,
                    );
                    if (image != null) {
                      setSheetState(() => imageUrl = image.path);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Photo captured!'), backgroundColor: Colors.green),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: imageUrl != null ? Colors.green : Colors.white24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          imageUrl != null ? Icons.check_circle : Icons.camera_alt,
                          color: imageUrl != null ? Colors.green : Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          imageUrl != null ? 'Photo Added ✓' : 'Add Landmark Photo',
                          style: TextStyle(
                            color: imageUrl != null ? Colors.green : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Add button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (labelController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a label')),
                        );
                        return;
                      }
                      
                      final nodeId = 'node_${DateTime.now().millisecondsSinceEpoch}';
                      final newNode = IndoorNode(
                        id: nodeId,
                        label: labelController.text.trim(),
                        latitude: _currentPosition!.latitude,
                        longitude: _currentPosition!.longitude,
                        floorNumber: _currentFloor,
                        nodeType: nodeType,
                        imageUrl: imageUrl,
                        qrCode: 'indoor-nav://${_selectedBuilding!.id}/$nodeId',
                        isEmergencyExit: isEmergencyExit,
                        isAccessible: isAccessible,
                        landmarkDescription: landmarkController.text.trim().isNotEmpty 
                            ? landmarkController.text.trim() 
                            : null,
                        category: category,
                      );
                      
                      // Auto-connect to last node if recording
                      if (_lastNode != null && _isRecording) {
                        final steps = _stepCount - _startStepCount;
                        _lastNode!.edges.add(EdgeData(
                          toNodeId: newNode.id,
                          steps: steps > 0 ? steps : 5,
                          direction: _currentDirection,
                          isAccessible: isAccessible,
                          crowdLevel: 0,
                        ));
                        // Add reverse edge
                        newNode.edges.add(EdgeData(
                          toNodeId: _lastNode!.id,
                          steps: steps > 0 ? steps : 5,
                          direction: _reverseDirection(_currentDirection),
                          isAccessible: isAccessible,
                          crowdLevel: 0,
                        ));
                      }
                      
                      setState(() {
                        _nodes.add(newNode);
                        _lastNode = newNode;
                        _startStepCount = _stepCount; // Reset step counter
                      });
                      
                      // Haptic feedback
                      HapticFeedback.mediumImpact();
                      
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Node "${newNode.label}" added!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add Node', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String label,
    required bool value,
    required Color color,
    required Function(bool) onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: value ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: value ? color : Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, color: value ? color : Colors.white54, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: value ? color : Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
            Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              color: value ? color : Colors.white38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryOrange, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _nodeTypeChip(String value, String label, IconData icon, String selected, Function(String) onSelect) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateStepsAndDirection(IndoorNode from, IndoorNode to) {
    // Calculate distance using Haversine formula
    const earthRadius = 6371000; // meters
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLat = (to.latitude - from.latitude) * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = earthRadius * c; // in meters

    // Calculate bearing (direction)
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final bearing = (math.atan2(y, x) * 180 / math.pi + 360) % 360;

    // Convert bearing to direction
    String direction;
    if (bearing >= 337.5 || bearing < 22.5) {
      direction = 'N';
    } else if (bearing >= 22.5 && bearing < 67.5) {
      direction = 'NE';
    } else if (bearing >= 67.5 && bearing < 112.5) {
      direction = 'E';
    } else if (bearing >= 112.5 && bearing < 157.5) {
      direction = 'SE';
    } else if (bearing >= 157.5 && bearing < 202.5) {
      direction = 'S';
    } else if (bearing >= 202.5 && bearing < 247.5) {
      direction = 'SW';
    } else if (bearing >= 247.5 && bearing < 292.5) {
      direction = 'W';
    } else {
      direction = 'NW';
    }

    // Convert distance to steps (assuming average step length of 0.7m)
    final steps = (distance / _userStepLength).round().clamp(1, 1000);

    return {
      'steps': steps,
      'direction': direction,
      'distance': distance,
      'bearing': bearing,
    };
  }

  String _reverseDirection(String dir) {
    const reverseMap = {
      'N': 'S', 'S': 'N', 'E': 'W', 'W': 'E',
      'NE': 'SW', 'SW': 'NE', 'NW': 'SE', 'SE': 'NW',
      'UP': 'DOWN', 'DOWN': 'UP',
    };
    return reverseMap[dir] ?? dir;
  }


  void _showNodeOptions(IndoorNode node) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Node info
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: node.edges.isNotEmpty ? Colors.green : Colors.red,
                  ),
                  child: Icon(_getNodeIcon(node.nodeType), color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(node.label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Floor ${node.floorNumber} • ${node.nodeType}', style: const TextStyle(color: Colors.white70)),
                      Text('${node.edges.length} connections', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Connections
            if (node.edges.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Connections:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              ...node.edges.map((edge) {
                final toNode = _nodes.firstWhere((n) => n.id == edge.toNodeId, orElse: () => node);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_forward, color: AppColors.primaryOrange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(toNode.label, style: const TextStyle(color: Colors.white))),
                      Text('${edge.steps} steps ${edge.direction}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
            
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _lastNode = node);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Selected "${node.label}" as starting point')),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Here'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showManualConnectDialog(node);
                    },
                    icon: const Icon(Icons.link),
                    label: const Text('Connect'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteNode(node);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showManualConnectDialog(IndoorNode fromNode) {
    final otherNodes = _nodes.where((n) => n.id != fromNode.id).toList();
    if (otherNodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add more nodes first')),
      );
      return;
    }
    
    IndoorNode? selectedNode;
    int steps = 10;
    String direction = 'N';
    bool autoCalculated = false;
    
    // Auto-calculate when node is selected
    void autoCalculate() {
      if (selectedNode != null) {
        final calculated = _calculateStepsAndDirection(fromNode, selectedNode!);
        steps = calculated['steps'] as int;
        direction = calculated['direction'] as String;
        autoCalculated = true;
      }
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Connect from "${fromNode.label}"', 
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (autoCalculated)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.auto_awesome, color: Colors.green, size: 14),
                          SizedBox(width: 4),
                          Text('Auto', style: TextStyle(color: Colors.green, fontSize: 11)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Target node
              DropdownButtonFormField<IndoorNode>(
                initialValue: selectedNode,
                dropdownColor: AppColors.surfaceDark,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Connect to',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: otherNodes.map((n) => DropdownMenuItem(
                  value: n,
                  child: Text('${n.label} (F${n.floorNumber})', style: const TextStyle(color: Colors.white)),
                )).toList(),
                onChanged: (v) {
                  setSheetState(() {
                    selectedNode = v;
                    if (v != null) {
                      autoCalculate();
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Auto-calculate button
              if (selectedNode != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryOrange),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calculate, color: AppColors.primaryOrange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Auto-calculated',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              'Based on GPS distance & bearing',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setSheetState(() {
                            autoCalculate();
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Recalc', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryOrange,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              
              // Steps and direction
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('steps_$steps'), // Force rebuild when auto-calculated
                      initialValue: steps.toString(),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Steps',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => steps = int.tryParse(v) ?? 10,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('direction_$direction'), // Force rebuild when auto-calculated
                      value: direction,
                      dropdownColor: AppColors.surfaceDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Direction',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: ['N', 'S', 'E', 'W', 'NE', 'NW', 'SE', 'SW', 'UP', 'DOWN']
                          .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (v) => setSheetState(() => direction = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedNode == null ? null : () {
                    setState(() {
                      fromNode.edges.add(EdgeData(toNodeId: selectedNode!.id, steps: steps, direction: direction));
                      selectedNode!.edges.add(EdgeData(toNodeId: fromNode.id, steps: steps, direction: _reverseDirection(direction)));
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Connected to "${selectedNode!.label}"'), backgroundColor: Colors.green),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Connect'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteNode(IndoorNode node) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Delete Node?', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${node.label}" and all connections?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _nodes.removeWhere((n) => n.id == node.id);
                for (final n in _nodes) {
                  n.edges.removeWhere((e) => e.toNodeId == node.id);
                }
                if (_lastNode?.id == node.id) _lastNode = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }


  // ============================================
  // API CALLS
  // ============================================

  Future<void> _loadExistingGraph(String buildingId) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/indoor/buildings/$buildingId/indoor-graph'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final nodesList = data['nodes'] as List? ?? [];
        setState(() {
          _nodes.clear();
          for (final nodeData in nodesList) {
            _nodes.add(IndoorNode.fromJson(nodeData));
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading graph: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveGraph() async {
    if (_selectedBuilding == null || _nodes.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final tokenStorage = TokenStorage(const FlutterSecureStorage());
      final token = await tokenStorage.getToken();
      
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login again'), backgroundColor: Colors.red),
        );
        return;
      }
      
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/indoor/buildings/${_selectedBuilding!.id}/indoor-graph'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: json.encode({'nodes': _nodes.map((n) => n.toJson()).toList()}),
      );
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved! ${_nodes.length} nodes, ${_nodes.fold(0, (sum, n) => sum + n.edges.length)} edges'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.body}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isInsideBoundary(double lat, double lng) {
    if (_selectedBuilding?.boundaryPoints == null) return true;
    final boundary = _selectedBuilding!.boundaryPoints!;
    if (boundary.length < 3) return true;
    
    int intersections = 0;
    for (int i = 0; i < boundary.length; i++) {
      final p1 = boundary[i];
      final p2 = boundary[(i + 1) % boundary.length];
      
      if (((p1['lat']! <= lat && lat < p2['lat']!) ||
           (p2['lat']! <= lat && lat < p1['lat']!)) &&
          lng < (p2['lng']! - p1['lng']!) * (lat - p1['lat']!) / 
                 (p2['lat']! - p1['lat']!) + p1['lng']!) {
        intersections++;
      }
    }
    return intersections % 2 == 1;
  }

  // ============================================
  // NEW FEATURE METHODS
  // ============================================

  Future<void> _validateGraph() async {
    if (_selectedBuilding == null || _nodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No graph to validate'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/indoor/buildings/${_selectedBuilding!.id}/indoor-graph/validate'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final validation = data['validation'];
        
        _showValidationResultDialog(validation);
      } else {
        // Validate locally
        _showLocalValidationResult();
      }
    } catch (e) {
      _showLocalValidationResult();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showLocalValidationResult() {
    // Local validation
    final disconnected = <String>[];
    final deadEnds = <String>[];
    final missingReverse = <Map<String, String>>[];
    
    final nodeIds = _nodes.map((n) => n.id).toSet();
    
    for (final node in _nodes) {
      if (node.edges.isEmpty) {
        disconnected.add(node.label);
      } else if (node.edges.length == 1) {
        deadEnds.add(node.label);
      }
      
      for (final edge in node.edges) {
        final toNode = _nodes.firstWhere(
          (n) => n.id == edge.toNodeId,
          orElse: () => node,
        );
        final hasReverse = toNode.edges.any((e) => e.toNodeId == node.id);
        if (!hasReverse && toNode.id != node.id) {
          missingReverse.add({'from': node.label, 'to': toNode.label});
        }
      }
    }
    
    _showValidationResultDialog({
      'is_valid': disconnected.isEmpty && missingReverse.isEmpty,
      'disconnected_nodes': disconnected,
      'dead_ends': deadEnds,
      'missing_reverse_edges': missingReverse,
      'warnings': [],
    });
  }

  void _showValidationResultDialog(Map<String, dynamic> validation) {
    final isValid = validation['is_valid'] ?? false;
    final disconnected = validation['disconnected_nodes'] as List? ?? [];
    final deadEnds = validation['dead_ends'] as List? ?? [];
    final missingReverse = validation['missing_reverse_edges'] as List? ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Row(
          children: [
            Icon(
              isValid ? Icons.check_circle : Icons.warning,
              color: isValid ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(
              isValid ? 'Graph Valid!' : 'Issues Found',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (disconnected.isNotEmpty) ...[
                const Text('Disconnected Nodes:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ...disconnected.map((n) => Text('  • $n', style: const TextStyle(color: Colors.white70))),
                const SizedBox(height: 8),
              ],
              if (deadEnds.isNotEmpty) ...[
                const Text('Dead Ends:', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                ...deadEnds.map((n) => Text('  • $n', style: const TextStyle(color: Colors.white70))),
                const SizedBox(height: 8),
              ],
              if (missingReverse.isNotEmpty) ...[
                const Text('Missing Reverse Edges:', style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)),
                ...missingReverse.map((e) => Text('  • ${e['from']} → ${e['to']}', style: const TextStyle(color: Colors.white70))),
              ],
              if (isValid)
                const Text('All nodes are properly connected!', style: TextStyle(color: Colors.green)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportGraph() async {
    if (_nodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No graph to export'), backgroundColor: Colors.orange),
      );
      return;
    }

    final exportData = {
      'building_id': _selectedBuilding?.id,
      'building_name': _selectedBuilding?.name,
      'exported_at': DateTime.now().toIso8601String(),
      'nodes': _nodes.map((n) => n.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    
    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: jsonString));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Graph exported! ${_nodes.length} nodes copied to clipboard'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () => _showExportPreview(jsonString),
        ),
      ),
    );
  }

  void _showExportPreview(String jsonString) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Export Preview', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              jsonString,
              style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    final heightController = TextEditingController(text: '170');
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Navigation Settings',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              // Step length from height
              TextField(
                controller: heightController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Your Height (cm)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'e.g., 170',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixText: 'cm',
                  suffixStyle: const TextStyle(color: Colors.white54),
                ),
                onChanged: (v) {
                  final height = int.tryParse(v) ?? 170;
                  setSheetState(() {
                    _userStepLength = (height / 100) * 0.41;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Calculated step length: ${_userStepLength.toStringAsFixed(2)}m',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              
              // Prefer accessible routes
              SwitchListTile(
                title: const Text('Prefer Accessible Routes', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Avoid stairs, prefer elevators', style: TextStyle(color: Colors.white54)),
                value: _preferAccessible,
                activeThumbColor: AppColors.primaryOrange,
                onChanged: (v) {
                  setSheetState(() => _preferAccessible = v);
                  setState(() => _preferAccessible = v);
                },
              ),
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final height = int.tryParse(heightController.text) ?? 170;
                    setState(() {
                      _userStepLength = (height / 100) * 0.41;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings saved!'), backgroundColor: Colors.green),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// PAINTERS
// ============================================

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    
    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NodesPainter extends CustomPainter {
  final List<IndoorNode> nodes;
  final List<IndoorNode> allNodes;
  final Building building;
  final IndoorNode? lastNode;

  _NodesPainter({
    required this.nodes,
    required this.allNodes,
    required this.building,
    this.lastNode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Skip painting if no boundary
    if (building.boundaryPoints == null || building.boundaryPoints!.length < 3) {
      return;
    }
    
    final boundary = building.boundaryPoints!;
    double minLat = boundary.map((p) => p['lat']!).reduce(math.min);
    double maxLat = boundary.map((p) => p['lat']!).reduce(math.max);
    double minLng = boundary.map((p) => p['lng']!).reduce(math.min);
    double maxLng = boundary.map((p) => p['lng']!).reduce(math.max);

    Offset getPos(IndoorNode node) {
      // Ensure we have valid dimensions
      if (size.width < 40 || size.height < 40) {
        return Offset(size.width / 2, size.height / 2);
      }
      
      double x = ((node.longitude - minLng) / (maxLng - minLng)) * (size.width - 40) + 20;
      double y = ((maxLat - node.latitude) / (maxLat - minLat)) * (size.height - 40) + 20;
      return Offset(
        x.clamp(20.0, size.width - 20.0), 
        y.clamp(20.0, size.height - 20.0)
      );
    }

    // Draw edges
    final edgePaint = Paint()
      ..color = Colors.orange.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final node in nodes) {
      final fromPos = getPos(node);
      for (final edge in node.edges) {
        final toNode = allNodes.firstWhere((n) => n.id == edge.toNodeId, orElse: () => node);
        if (toNode.floorNumber == node.floorNumber) {
          final toPos = getPos(toNode);
          canvas.drawLine(fromPos, toPos, edgePaint);
          
          // Draw arrow
          final angle = math.atan2(toPos.dy - fromPos.dy, toPos.dx - fromPos.dx);
          final midPoint = Offset((fromPos.dx + toPos.dx) / 2, (fromPos.dy + toPos.dy) / 2);
          final arrowPath = Path()
            ..moveTo(midPoint.dx + 8 * math.cos(angle), midPoint.dy + 8 * math.sin(angle))
            ..lineTo(midPoint.dx + 8 * math.cos(angle + 2.5), midPoint.dy + 8 * math.sin(angle + 2.5))
            ..lineTo(midPoint.dx + 8 * math.cos(angle - 2.5), midPoint.dy + 8 * math.sin(angle - 2.5))
            ..close();
          canvas.drawPath(arrowPath, Paint()..color = Colors.orange);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================
// DATA MODELS
// ============================================

class EdgeData {
  final String toNodeId;
  final int steps;
  final String direction;
  final bool isAccessible;
  final int crowdLevel;

  EdgeData({
    required this.toNodeId, 
    required this.steps, 
    required this.direction,
    this.isAccessible = true,
    this.crowdLevel = 0,
  });

  Map<String, dynamic> toJson() => {
    'to_node_id': toNodeId, 
    'steps': steps, 
    'direction': direction,
    'is_accessible': isAccessible,
    'crowd_level': crowdLevel,
  };
  
  factory EdgeData.fromJson(Map<String, dynamic> json) => EdgeData(
    toNodeId: json['to_node_id'] ?? '',
    steps: json['steps'] ?? 0,
    direction: json['direction'] ?? 'N',
    isAccessible: json['is_accessible'] ?? true,
    crowdLevel: json['crowd_level'] ?? 0,
  );
}

class IndoorNode {
  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final int floorNumber;
  final String? imageUrl;
  final String nodeType;
  final List<EdgeData> edges;
  final String? qrCode;
  final bool isEmergencyExit;
  final bool isAccessible;
  final String? landmarkDescription;
  final String? category;

  IndoorNode({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.floorNumber,
    this.imageUrl,
    this.nodeType = 'waypoint',
    List<EdgeData>? edges,
    this.qrCode,
    this.isEmergencyExit = false,
    this.isAccessible = true,
    this.landmarkDescription,
    this.category,
  }) : edges = edges ?? [];

  Map<String, dynamic> toJson() => {
    'id': id, 
    'label': label, 
    'latitude': latitude, 
    'longitude': longitude,
    'floor_number': floorNumber, 
    'image_url': imageUrl, 
    'node_type': nodeType,
    'edges': edges.map((e) => e.toJson()).toList(),
    'qr_code': qrCode,
    'is_emergency_exit': isEmergencyExit,
    'is_accessible': isAccessible,
    'landmark_description': landmarkDescription,
    'category': category,
  };

  factory IndoorNode.fromJson(Map<String, dynamic> json) => IndoorNode(
    id: json['id'] ?? '',
    label: json['label'] ?? '',
    latitude: (json['latitude'] ?? 0).toDouble(),
    longitude: (json['longitude'] ?? 0).toDouble(),
    floorNumber: json['floor_number'] ?? 0,
    imageUrl: json['image_url'],
    nodeType: json['node_type'] ?? 'waypoint',
    edges: (json['edges'] as List?)?.map((e) => EdgeData.fromJson(e)).toList() ?? [],
    qrCode: json['qr_code'],
    isEmergencyExit: json['is_emergency_exit'] ?? false,
    isAccessible: json['is_accessible'] ?? true,
    landmarkDescription: json['landmark_description'],
    category: json['category'],
  );
}

