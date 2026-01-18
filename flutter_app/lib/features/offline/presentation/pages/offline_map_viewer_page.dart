import 'package:flutter/material.dart';
import 'package:indoor_navigation/core/database/local_database.dart';
import 'package:indoor_navigation/core/di/injection_container.dart';
import 'package:indoor_navigation/models/navigation_node.dart';
import 'package:indoor_navigation/features/admin/presentation/widgets/building_3d_viewer.dart';

class OfflineMapViewerPage extends StatefulWidget {
  final String buildingId;
  final String buildingName;

  const OfflineMapViewerPage({
    super.key,
    required this.buildingId,
    required this.buildingName,
  });

  @override
  State<OfflineMapViewerPage> createState() => _OfflineMapViewerPageState();
}

class _OfflineMapViewerPageState extends State<OfflineMapViewerPage> {
  final LocalDatabase _database = getIt<LocalDatabase>();
  
  bool _isLoading = true;
  bool _is3DView = false;
  String? _error;
  
  // Building data
  Map<int, List<NavigationNode>> _nodesByFloor = {};
  List<int> _floorNumbers = [];
  int _currentFloor = 0;
  
  // 3D View controller
  BuildingInteractionController? _3dController;

  @override
  void initState() {
    super.initState();
    _loadBuildingData();
  }

  Future<void> _loadBuildingData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load all navigation nodes for this building
      final allNodes = await _database.getNavigationNodes(widget.buildingId);
      
      if (allNodes.isEmpty) {
        setState(() {
          _error = 'No navigation data found for this building';
          _isLoading = false;
        });
        return;
      }

      // Group nodes by floor
      final nodesByFloor = <int, List<NavigationNode>>{};
      for (final node in allNodes) {
        final floorNumber = await _getFloorNumber(node.floorId);
        if (!nodesByFloor.containsKey(floorNumber)) {
          nodesByFloor[floorNumber] = [];
        }
        nodesByFloor[floorNumber]!.add(node);
      }

      // Sort floor numbers
      final floorNumbers = nodesByFloor.keys.toList()..sort();

      setState(() {
        _nodesByFloor = nodesByFloor;
        _floorNumbers = floorNumbers;
        _currentFloor = floorNumbers.isNotEmpty ? floorNumbers.first : 0;
        _isLoading = false;
      });

      // Initialize 3D controller
      _3dController = BuildingInteractionController();
    } catch (e) {
      setState(() {
        _error = 'Failed to load building data: $e';
        _isLoading = false;
      });
    }
  }

  Future<int> _getFloorNumber(String floorId) async {
    final floor = await _database.getFloor(floorId);
    return floor?.floorNumber ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          widget.buildingName,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 2D/3D Toggle Button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: _is3DView 
                  ? Colors.orange.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _is3DView ? Colors.orange : Colors.grey,
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _is3DView = !_is3DView;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _is3DView ? Icons.view_in_ar : Icons.map,
                        color: _is3DView ? Colors.orange : Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _is3DView ? '3D' : '2D',
                        style: TextStyle(
                          color: _is3DView ? Colors.orange : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Node count badge
          if (!_isLoading && _error == null)
            Container(
              margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: Colors.blue, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${_getCurrentFloorNodes().length}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildFloorSelector(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Loading offline map...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadBuildingData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  // Delete and go back to re-download
                  final database = getIt<LocalDatabase>();
                  await database.deleteBuilding(widget.buildingId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Building deleted. Please download again.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.download, color: Colors.orange),
                label: const Text(
                  'Delete & Re-download',
                  style: TextStyle(color: Colors.orange),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _is3DView ? _build3DView() : _build2DView();
  }

  Widget _build2DView() {
    final floorNodes = _getCurrentFloorNodes();

    if (floorNodes.isEmpty) {
      return const Center(
        child: Text(
          'No nodes on this floor',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.1,
      maxScale: 5.0,
      child: CustomPaint(
        painter: _FloorMapPainter(floorNodes),
        size: Size.infinite,
      ),
    );
  }

  Widget _build3DView() {
    if (_3dController == null) {
      return const Center(
        child: Text(
          'Initializing 3D view...',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // Convert nodes to 3D building structure
    final building3D = _convertTo3DBuilding();

    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // Floor info overlay
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Viewing all ${_floorNumbers.length} floors',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Selected: Floor $_currentFloor',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onScaleStart: (details) {
                // Store initial scale for relative scaling
              },
              onScaleUpdate: (details) {
                // Handle rotation (pan)
                if (details.scale == 1.0) {
                  // Pure pan gesture
                  _3dController!.updateRotation(
                    details.focalPointDelta.dy * 0.01,
                    details.focalPointDelta.dx * 0.01,
                  );
                } else {
                  // Scale gesture
                  _3dController!.updateScale(details.scale);
                }
              },
              child: AnimatedBuilder(
                animation: _3dController!,
                builder: (context, child) {
                  return CustomPaint(
                    painter: Building3DPainter(
                      building: building3D,
                      controller: _3dController!,
                      selectedFloor: _currentFloor,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),
          // 3D Controls hint
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Drag to rotate • Pinch to zoom • Two-finger drag to pan',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Building3D _convertTo3DBuilding() {
    final floors = <Floor3D>[];

    for (final floorNumber in _floorNumbers) {
      final nodes = _nodesByFloor[floorNumber] ?? [];
      
      // Convert nodes to rooms for 3D visualization
      final rooms = nodes.map((node) {
        return Room3D(
          id: node.id,
          x: node.x / 100, // Scale down for visualization
          y: node.y / 100,
          width: 0.5,
          depth: 0.5,
          type: _getNodeRoomType(node),
          name: node.name ?? 'Node',
        );
      }).toList();

      floors.add(Floor3D(
        floorNumber: floorNumber,
        thickness: 0.2,
        rooms: rooms,
      ));
    }

    return Building3D(
      name: widget.buildingName,
      baseWidth: 50.0,
      baseDepth: 50.0,
      floors: floors,
    );
  }

  RoomType _getNodeRoomType(NavigationNode node) {
    final type = NodeType.values[node.typeIndex];
    switch (type) {
      case NodeType.stairs:
        return RoomType.stairs;
      case NodeType.elevator:
        return RoomType.elevator;
      case NodeType.entrance:
      case NodeType.exit:
        return RoomType.lobby;
      default:
        return RoomType.office;
    }
  }

  List<NavigationNode> _getCurrentFloorNodes() {
    return _nodesByFloor[_currentFloor] ?? [];
  }

  Widget _buildFloorSelector() {
    if (_floorNumbers.isEmpty) return const SizedBox.shrink();

    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select Floor',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _floorNumbers.length,
              itemBuilder: (context, index) {
                final floorNumber = _floorNumbers[index];
                final isSelected = floorNumber == _currentFloor;
                final nodeCount = _nodesByFloor[floorNumber]?.length ?? 0;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentFloor = floorNumber;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.orange
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.orange : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Floor $floorNumber',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$nodeCount nodes',
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _3dController?.dispose();
    super.dispose();
  }
}

// Custom painter for 2D floor map
class _FloorMapPainter extends CustomPainter {
  final List<NavigationNode> nodes;

  _FloorMapPainter(this.nodes);

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;

    // Calculate bounds
    double minX = nodes.first.x;
    double maxX = nodes.first.x;
    double minY = nodes.first.y;
    double maxY = nodes.first.y;

    for (final node in nodes) {
      if (node.x < minX) minX = node.x;
      if (node.x > maxX) maxX = node.x;
      if (node.y < minY) minY = node.y;
      if (node.y > maxY) maxY = node.y;
    }

    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    final scale = (size.width * 0.8) / (rangeX > rangeY ? rangeX : rangeY);
    final offsetX = size.width / 2 - (minX + maxX) / 2 * scale;
    final offsetY = size.height / 2 - (minY + maxY) / 2 * scale;

    // Draw connections
    final connectionPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final node in nodes) {
      final x1 = node.x * scale + offsetX;
      final y1 = node.y * scale + offsetY;

      for (final connectedId in node.connectedNodeIds) {
        final connectedNode = nodes.firstWhere(
          (n) => n.id == connectedId,
          orElse: () => node,
        );
        if (connectedNode.id != node.id) {
          final x2 = connectedNode.x * scale + offsetX;
          final y2 = connectedNode.y * scale + offsetY;
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), connectionPaint);
        }
      }
    }

    // Draw nodes
    for (final node in nodes) {
      final x = node.x * scale + offsetX;
      final y = node.y * scale + offsetY;
      final nodeType = NodeType.values[node.typeIndex];

      // Node circle
      final nodePaint = Paint()
        ..color = _getNodeColor(nodeType)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 8, nodePaint);

      // Node border
      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(Offset(x, y), 8, borderPaint);

      // Node label
      if (node.name != null && node.name!.isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: node.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, y + 12),
        );
      }
    }
  }

  Color _getNodeColor(NodeType type) {
    switch (type) {
      case NodeType.entrance:
        return Colors.green;
      case NodeType.exit:
        return Colors.red;
      case NodeType.stairs:
        return Colors.purple;
      case NodeType.elevator:
        return Colors.orange;
      case NodeType.junction:
        return Colors.yellow;
      default:
        return Colors.blue;
    }
  }

  @override
  bool shouldRepaint(_FloorMapPainter oldDelegate) {
    return oldDelegate.nodes != nodes;
  }
}
