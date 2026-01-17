import 'package:flutter/material.dart';
import 'building_3d_viewer.dart';

class Building3DPreviewDialog extends StatefulWidget {
  final List<FloorData> floors;
  final String buildingName;

  const Building3DPreviewDialog({
    super.key,
    required this.floors,
    required this.buildingName,
  });

  @override
  State<Building3DPreviewDialog> createState() => _Building3DPreviewDialogState();
}

class _Building3DPreviewDialogState extends State<Building3DPreviewDialog> with SingleTickerProviderStateMixin {
  late BuildingInteractionController _controller;
  late AnimationController _explodeAnimController;
  int? _selectedFloorIndex;

  @override
  void initState() {
    super.initState();
    _controller = BuildingInteractionController();
    _explodeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(() {
      _controller.setExplodeFactor(_explodeAnimController.value);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _explodeAnimController.dispose();
    super.dispose();
  }

  Building3D _convertToBuilding3D() {
    final floors3D = widget.floors.map((floorData) {
      final rooms3D = floorData.rooms.map((room) {
        return Room3D(
          id: room.id,
          name: room.name,
          type: _getRoomType(room.type),
          x: room.x,
          y: room.y,
          width: room.width,
          depth: room.depth,
          height: room.height,
        );
      }).toList();

      return Floor3D(
        floorNumber: floorData.floorNumber,
        rooms: rooms3D,
      );
    }).toList();

    return Building3D(
      name: widget.buildingName,
      floors: floors3D,
    );
  }

  RoomType _getRoomType(String type) {
    switch (type.toLowerCase()) {
      case 'office':
        return RoomType.office;
      case 'classroom':
        return RoomType.classroom;
      case 'restroom':
      case 'bathroom':
        return RoomType.restroom;
      case 'stairs':
        return RoomType.stairs;
      case 'elevator':
        return RoomType.elevator;
      case 'lobby':
        return RoomType.lobby;
      case 'storage':
        return RoomType.storage;
      case 'cafeteria':
        return RoomType.cafeteria;
      default:
        return RoomType.office;
    }
  }

  void _toggleExplode() {
    if (_controller.isExploded) {
      _explodeAnimController.reverse();
    } else {
      _explodeAnimController.forward();
    }
    _controller.toggleExplode();
  }

  @override
  Widget build(BuildContext context) {
    final building = _convertToBuilding3D();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade900,
              Colors.grey.shade800,
              Colors.grey.shade900,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // 3D Viewer
            Expanded(
              child: Stack(
                children: [
                  // Main viewer
                  GestureDetector(
                    onScaleStart: (details) {
                      // Store initial values
                    },
                    onScaleUpdate: (details) {
                      if (details.scale != 1.0) {
                        // Pinch to zoom
                        _controller.updateScale(details.scale);
                      } else {
                        // Drag to rotate
                        _controller.updateRotation(
                          details.focalPointDelta.dy * 0.01,
                          details.focalPointDelta.dx * 0.01,
                        );
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: Building3DPainter(
                            building: building,
                            controller: _controller,
                          ),
                          size: Size.infinite,
                        );
                      },
                    ),
                  ),
                  
                  // Toolbar
                  Positioned(
                    right: 16,
                    top: 16,
                    child: _buildToolbar(),
                  ),
                ],
              ),
            ),
            
            // Floor selector
            _buildFloorSelector(),
            
            // Legend
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.buildingName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '3D Interactive Viewer',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolbarButton(
            icon: Icons.view_in_ar,
            label: 'Isometric',
            onPressed: () => _controller.setIsometricView(),
          ),
          const Divider(height: 1, color: Colors.white24),
          _buildToolbarButton(
            icon: Icons.view_agenda,
            label: 'Top',
            onPressed: () => _controller.setTopView(),
          ),
          const Divider(height: 1, color: Colors.white24),
          _buildToolbarButton(
            icon: Icons.view_column,
            label: 'Front',
            onPressed: () => _controller.setFrontView(),
          ),
          const Divider(height: 1, color: Colors.white24),
          _buildToolbarButton(
            icon: _controller.isExploded ? Icons.layers : Icons.layers_outlined,
            label: 'Explode',
            onPressed: _toggleExplode,
            isActive: _controller.isExploded,
          ),
          const Divider(height: 1, color: Colors.white24),
          _buildToolbarButton(
            icon: Icons.zoom_in,
            label: 'Zoom+',
            onPressed: () => _controller.updateScale(1.2),
          ),
          const Divider(height: 1, color: Colors.white24),
          _buildToolbarButton(
            icon: Icons.zoom_out,
            label: 'Zoom-',
            onPressed: () => _controller.updateScale(0.8),
          ),
          const Divider(height: 1, color: Colors.white24),
          _buildToolbarButton(
            icon: Icons.refresh,
            label: 'Reset',
            onPressed: () => _controller.reset(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: isActive ? Colors.amber : Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloorSelector() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.floors.length,
        itemBuilder: (context, index) {
          final floor = widget.floors[index];
          final isSelected = _selectedFloorIndex == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFloorIndex = isSelected ? null : index;
                _controller.selectFloor(isSelected ? null : floor.floorNumber);
              });
            },
            child: Container(
              width: 90,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.amber : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? Colors.amberAccent : Colors.grey.shade700,
                  width: 2,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.layers,
                        color: isSelected ? Colors.black : Colors.white,
                        size: 20,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Floor ${floor.floorNumber}',
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '${floor.rooms.length} rooms',
                        style: TextStyle(
                          color: isSelected ? Colors.black87 : Colors.white70,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 80),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Room Types: ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            ...RoomType.values.map((type) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: type.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      type.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// Data classes for compatibility with existing code
class FloorData {
  final int floorNumber;
  final String name;
  final List<RoomModel> rooms;
  final List<WallModel> walls;
  
  FloorData({
    required this.floorNumber, 
    required this.name,
    this.rooms = const [],
    this.walls = const [],
  });
}

class RoomModel {
  final String id;
  final String name;
  final String type;
  final double x;
  final double y;
  final double width;
  final double depth;
  final double height;

  RoomModel({
    required this.id,
    required this.name,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.depth,
    this.height = 3.0,
  });
}

class WallModel {
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  WallModel({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });
}

