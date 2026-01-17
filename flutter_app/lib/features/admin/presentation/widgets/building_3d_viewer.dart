import 'dart:math';
import 'package:flutter/material.dart';

// ============================================================================
// DATA MODELS
// ============================================================================

enum RoomType {
  office(Colors.blue, Icons.business),
  classroom(Colors.green, Icons.school),
  restroom(Colors.purple, Icons.wc),
  stairs(Colors.orange, Icons.stairs),
  elevator(Colors.red, Icons.elevator),
  lobby(Colors.cyan, Icons.meeting_room),
  storage(Colors.brown, Icons.inventory),
  cafeteria(Colors.amber, Icons.restaurant);

  final Color color;
  final IconData icon;
  const RoomType(this.color, this.icon);
}

class Room3D {
  final String id;
  final String name;
  final RoomType type;
  final double x; // 0.0 to 1.0 relative to floor
  final double y; // 0.0 to 1.0 relative to floor
  final double width; // 0.0 to 1.0 relative to floor
  final double depth; // 0.0 to 1.0 relative to floor
  final double height; // Actual height in units

  Room3D({
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

class Floor3D {
  final int floorNumber;
  final List<Room3D> rooms;
  final double thickness;

  Floor3D({
    required this.floorNumber,
    required this.rooms,
    this.thickness = 0.3,
  });
}

class Building3D {
  final String name;
  final List<Floor3D> floors;
  final double baseWidth;
  final double baseDepth;

  Building3D({
    required this.name,
    required this.floors,
    this.baseWidth = 50.0,
    this.baseDepth = 50.0,
  });
}

// ============================================================================
// INTERACTION CONTROLLER
// ============================================================================

class BuildingInteractionController extends ChangeNotifier {
  double _rotationX = -0.5; // Tilt
  double _rotationZ = 0.5; // Spin
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  int? _selectedFloor;
  String? _selectedRoom;
  bool _isExploded = false;
  double _explodeFactor = 0.0;

  double get rotationX => _rotationX;
  double get rotationZ => _rotationZ;
  double get scale => _scale;
  Offset get offset => _offset;
  int? get selectedFloor => _selectedFloor;
  String? get selectedRoom => _selectedRoom;
  bool get isExploded => _isExploded;
  double get explodeFactor => _explodeFactor;

  void setRotation(double x, double z) {
    _rotationX = x;
    _rotationZ = z;
    notifyListeners();
  }

  void updateRotation(double dx, double dz) {
    _rotationX += dx;
    _rotationZ += dz;
    notifyListeners();
  }

  void setScale(double scale) {
    _scale = scale.clamp(0.3, 3.0);
    notifyListeners();
  }

  void updateScale(double delta) {
    _scale = (_scale * delta).clamp(0.3, 3.0);
    notifyListeners();
  }

  void setOffset(Offset offset) {
    _offset = offset;
    notifyListeners();
  }

  void updateOffset(Offset delta) {
    _offset += delta;
    notifyListeners();
  }

  void selectFloor(int? floor) {
    _selectedFloor = floor;
    notifyListeners();
  }

  void selectRoom(String? roomId) {
    _selectedRoom = roomId;
    notifyListeners();
  }

  void toggleExplode() {
    _isExploded = !_isExploded;
    notifyListeners();
  }

  void setExplodeFactor(double factor) {
    _explodeFactor = factor.clamp(0.0, 1.0);
    notifyListeners();
  }

  // Preset views
  void setTopView() {
    _rotationX = -pi / 2;
    _rotationZ = 0;
    notifyListeners();
  }

  void setFrontView() {
    _rotationX = 0;
    _rotationZ = 0;
    notifyListeners();
  }

  void setIsometricView() {
    _rotationX = -0.5;
    _rotationZ = 0.5;
    notifyListeners();
  }

  void reset() {
    _rotationX = -0.5;
    _rotationZ = 0.5;
    _scale = 1.0;
    _offset = Offset.zero;
    _selectedFloor = null;
    _selectedRoom = null;
    _isExploded = false;
    _explodeFactor = 0.0;
    notifyListeners();
  }
}

// ============================================================================
// 3D PAINTER
// ============================================================================

class Building3DPainter extends CustomPainter {
  final Building3D building;
  final BuildingInteractionController controller;

  Building3DPainter({
    required this.building,
    required this.controller,
  }) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Apply transformations
    canvas.save();
    canvas.translate(center.dx + controller.offset.dx, center.dy + controller.offset.dy);
    canvas.scale(controller.scale);

    // Draw building
    _drawBuilding(canvas, size);

    canvas.restore();
  }

  void _drawBuilding(Canvas canvas, Size size) {
    // Collect all drawable elements with their Z-depth for sorting
    final List<_DrawableElement> elements = [];

    for (int i = 0; i < building.floors.length; i++) {
      final floor = building.floors[i];
      final floorHeight = i * 3.5;
      final explodeOffset = controller.isExploded 
          ? i * 15.0 * controller.explodeFactor 
          : 0.0;

      // Add floor slab
      elements.addAll(_createFloorElements(floor, floorHeight + explodeOffset));

      // Add rooms
      for (final room in floor.rooms) {
        elements.addAll(_createRoomElements(
          room,
          floor,
          floorHeight + explodeOffset,
        ));
      }
    }

    // Z-sort (painter's algorithm)
    elements.sort((a, b) => a.zDepth.compareTo(b.zDepth));

    // Draw all elements
    for (final element in elements) {
      element.draw(canvas);
    }
  }

  List<_DrawableElement> _createFloorElements(Floor3D floor, double baseZ) {
    final elements = <_DrawableElement>[];
    final isSelected = controller.selectedFloor == floor.floorNumber;

    // Floor corners in 3D space
    final corners = [
      _Point3D(0, 0, baseZ),
      _Point3D(building.baseWidth, 0, baseZ),
      _Point3D(building.baseWidth, building.baseDepth, baseZ),
      _Point3D(0, building.baseDepth, baseZ),
    ];

    final topCorners = corners.map((c) => _Point3D(c.x, c.y, c.z + floor.thickness)).toList();

    // Project points
    final projectedBottom = corners.map((p) => _project3D(p)).toList();
    final projectedTop = topCorners.map((p) => _project3D(p)).toList();

    // Calculate average Z for sorting
    final avgZ = corners.map((c) => c.z).reduce((a, b) => a + b) / corners.length;

    // Top face
    elements.add(_DrawableElement(
      zDepth: avgZ + floor.thickness,
      draw: (canvas) {
        final path = Path()
          ..moveTo(projectedTop[0].dx, projectedTop[0].dy)
          ..lineTo(projectedTop[1].dx, projectedTop[1].dy)
          ..lineTo(projectedTop[2].dx, projectedTop[2].dy)
          ..lineTo(projectedTop[3].dx, projectedTop[3].dy)
          ..close();

        final paint = Paint()
          ..color = isSelected 
              ? Colors.amber.withOpacity(0.3)
              : Colors.grey.shade300.withOpacity(0.8)
          ..style = PaintingStyle.fill;

        canvas.drawPath(path, paint);

        // Grid pattern
        _drawGrid(canvas, projectedTop, 5);

        // Border
        canvas.drawPath(
          path,
          Paint()
            ..color = isSelected ? Colors.amber : Colors.grey.shade600
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 2.0 : 1.0,
        );
      },
    ));

    // Side faces
    for (int i = 0; i < 4; i++) {
      final next = (i + 1) % 4;
      elements.add(_DrawableElement(
        zDepth: avgZ,
        draw: (canvas) {
          final path = Path()
            ..moveTo(projectedBottom[i].dx, projectedBottom[i].dy)
            ..lineTo(projectedTop[i].dx, projectedTop[i].dy)
            ..lineTo(projectedTop[next].dx, projectedTop[next].dy)
            ..lineTo(projectedBottom[next].dx, projectedBottom[next].dy)
            ..close();

          canvas.drawPath(
            path,
            Paint()
              ..color = Colors.grey.shade400.withOpacity(0.6)
              ..style = PaintingStyle.fill,
          );

          canvas.drawPath(
            path,
            Paint()
              ..color = Colors.grey.shade700
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5,
          );
        },
      ));
    }

    return elements;
  }

  List<_DrawableElement> _createRoomElements(Room3D room, Floor3D floor, double baseZ) {
    final elements = <_DrawableElement>[];
    final isSelected = controller.selectedRoom == room.id;

    // Room position in world space
    final x = room.x * building.baseWidth;
    final y = room.y * building.baseDepth;
    final w = room.width * building.baseWidth;
    final d = room.depth * building.baseDepth;
    final h = room.height;
    final z = baseZ + floor.thickness;

    if (room.type == RoomType.stairs) {
      return _createStairsElements(room, x, y, w, d, z, h, isSelected);
    } else if (room.type == RoomType.elevator) {
      return _createElevatorElements(room, x, y, w, d, z, h, isSelected);
    }

    // Regular room box
    final corners = [
      _Point3D(x, y, z),
      _Point3D(x + w, y, z),
      _Point3D(x + w, y + d, z),
      _Point3D(x, y + d, z),
    ];

    final topCorners = corners.map((c) => _Point3D(c.x, c.y, c.z + h)).toList();

    final projectedBottom = corners.map((p) => _project3D(p)).toList();
    final projectedTop = topCorners.map((p) => _project3D(p)).toList();

    final avgZ = z + h / 2;
    final baseColor = room.type.color;

    // Top face
    elements.add(_DrawableElement(
      zDepth: z + h,
      draw: (canvas) {
        final path = Path()
          ..moveTo(projectedTop[0].dx, projectedTop[0].dy)
          ..lineTo(projectedTop[1].dx, projectedTop[1].dy)
          ..lineTo(projectedTop[2].dx, projectedTop[2].dy)
          ..lineTo(projectedTop[3].dx, projectedTop[3].dy)
          ..close();

        canvas.drawPath(
          path,
          Paint()
            ..color = isSelected 
                ? Colors.amber.withOpacity(0.9)
                : baseColor.withOpacity(0.9)
            ..style = PaintingStyle.fill,
        );

        canvas.drawPath(
          path,
          Paint()
            ..color = isSelected ? Colors.amberAccent : baseColor.darken(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 2.5 : 1.5,
        );
      },
    ));

    // Side faces
    for (int i = 0; i < 4; i++) {
      final next = (i + 1) % 4;
      elements.add(_DrawableElement(
        zDepth: avgZ,
        draw: (canvas) {
          final path = Path()
            ..moveTo(projectedBottom[i].dx, projectedBottom[i].dy)
            ..lineTo(projectedTop[i].dx, projectedTop[i].dy)
            ..lineTo(projectedTop[next].dx, projectedTop[next].dy)
            ..lineTo(projectedBottom[next].dx, projectedBottom[next].dy)
            ..close();

          canvas.drawPath(
            path,
            Paint()
              ..color = baseColor.withOpacity(0.7)
              ..style = PaintingStyle.fill,
          );

          canvas.drawPath(
            path,
            Paint()
              ..color = baseColor.darken(0.4)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
          );
        },
      ));
    }

    // Label
    final labelPos = _project3D(_Point3D(x + w / 2, y + d / 2, z + h + 1));
    elements.add(_DrawableElement(
      zDepth: z + h + 1,
      draw: (canvas) => _drawLabel(canvas, room.name, labelPos, baseColor),
    ));

    return elements;
  }

  List<_DrawableElement> _createStairsElements(
    Room3D room, double x, double y, double w, double d, double z, double h, bool isSelected
  ) {
    final elements = <_DrawableElement>[];
    const steps = 8;
    final stepHeight = h / steps;
    final stepDepth = d / steps;

    for (int i = 0; i < steps; i++) {
      final stepZ = z + i * stepHeight;
      final stepY = y + i * stepDepth;
      final stepD = d - i * stepDepth;

      final corners = [
        _Point3D(x, stepY, stepZ),
        _Point3D(x + w, stepY, stepZ),
        _Point3D(x + w, stepY + stepD, stepZ),
        _Point3D(x, stepY + stepD, stepZ),
      ];

      final topCorners = corners.map((c) => _Point3D(c.x, c.y, c.z + stepHeight)).toList();
      final projectedTop = topCorners.map((p) => _project3D(p)).toList();

      elements.add(_DrawableElement(
        zDepth: stepZ + stepHeight,
        draw: (canvas) {
          final path = Path()
            ..moveTo(projectedTop[0].dx, projectedTop[0].dy)
            ..lineTo(projectedTop[1].dx, projectedTop[1].dy)
            ..lineTo(projectedTop[2].dx, projectedTop[2].dy)
            ..lineTo(projectedTop[3].dx, projectedTop[3].dy)
            ..close();

          canvas.drawPath(
            path,
            Paint()
              ..color = isSelected 
                  ? Colors.amber.withOpacity(0.8)
                  : Colors.orange.withOpacity(0.8)
              ..style = PaintingStyle.fill,
          );

          canvas.drawPath(
            path,
            Paint()
              ..color = Colors.orange.shade800
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5,
          );
        },
      ));
    }

    final labelPos = _project3D(_Point3D(x + w / 2, y + d / 2, z + h + 1));
    elements.add(_DrawableElement(
      zDepth: z + h + 1,
      draw: (canvas) => _drawLabel(canvas, room.name, labelPos, Colors.orange),
    ));

    return elements;
  }

  List<_DrawableElement> _createElevatorElements(
    Room3D room, double x, double y, double w, double d, double z, double h, bool isSelected
  ) {
    final elements = <_DrawableElement>[];
    
    // Shaft
    final corners = [
      _Point3D(x, y, z),
      _Point3D(x + w, y, z),
      _Point3D(x + w, y + d, z),
      _Point3D(x, y + d, z),
    ];

    final topCorners = corners.map((c) => _Point3D(c.x, c.y, c.z + h)).toList();
    final projectedTop = topCorners.map((p) => _project3D(p)).toList();

    // Top
    elements.add(_DrawableElement(
      zDepth: z + h,
      draw: (canvas) {
        final path = Path()
          ..moveTo(projectedTop[0].dx, projectedTop[0].dy)
          ..lineTo(projectedTop[1].dx, projectedTop[1].dy)
          ..lineTo(projectedTop[2].dx, projectedTop[2].dy)
          ..lineTo(projectedTop[3].dx, projectedTop[3].dy)
          ..close();

        canvas.drawPath(
          path,
          Paint()
            ..color = isSelected ? Colors.amber : Colors.red.shade700
            ..style = PaintingStyle.fill,
        );

        // Draw arrows
        final center = Offset(
          (projectedTop[0].dx + projectedTop[2].dx) / 2,
          (projectedTop[0].dy + projectedTop[2].dy) / 2,
        );
        _drawArrow(canvas, center, true);
      },
    ));

    final labelPos = _project3D(_Point3D(x + w / 2, y + d / 2, z + h + 1));
    elements.add(_DrawableElement(
      zDepth: z + h + 1,
      draw: (canvas) => _drawLabel(canvas, room.name, labelPos, Colors.red),
    ));

    return elements;
  }

  void _drawLabel(Canvas canvas, String text, Offset position, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padding = 6.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: position,
        width: textPainter.width + padding * 2,
        height: textPainter.height + padding,
      ),
      const Radius.circular(8),
    );

    canvas.drawRRect(
      rect,
      Paint()
        ..color = color.withOpacity(0.9)
        ..style = PaintingStyle.fill,
    );

    canvas.drawRRect(
      rect,
      Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawGrid(Canvas canvas, List<Offset> corners, int divisions) {
    final paint = Paint()
      ..color = Colors.grey.shade400.withOpacity(0.3)
      ..strokeWidth = 0.5;

    for (int i = 1; i < divisions; i++) {
      final t = i / divisions;
      
      // Horizontal lines
      final p1 = Offset.lerp(corners[0], corners[1], t)!;
      final p2 = Offset.lerp(corners[3], corners[2], t)!;
      canvas.drawLine(p1, p2, paint);
      
      // Vertical lines
      final p3 = Offset.lerp(corners[0], corners[3], t)!;
      final p4 = Offset.lerp(corners[1], corners[2], t)!;
      canvas.drawLine(p3, p4, paint);
    }
  }

  void _drawArrow(Canvas canvas, Offset center, bool up) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    const size = 8.0;
    
    if (up) {
      path.moveTo(center.dx, center.dy - size);
      path.lineTo(center.dx - size / 2, center.dy);
      path.lineTo(center.dx + size / 2, center.dy);
    } else {
      path.moveTo(center.dx, center.dy + size);
      path.lineTo(center.dx - size / 2, center.dy);
      path.lineTo(center.dx + size / 2, center.dy);
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  Offset _project3D(_Point3D point) {
    // Apply rotations
    final cosX = cos(controller.rotationX);
    final sinX = sin(controller.rotationX);
    final cosZ = cos(controller.rotationZ);
    final sinZ = sin(controller.rotationZ);

    // Rotate around X axis (tilt)
    final y1 = point.y * cosX - point.z * sinX;
    final z1 = point.y * sinX + point.z * cosX;

    // Rotate around Z axis (spin)
    final x2 = point.x * cosZ - y1 * sinZ;
    final y2 = point.x * sinZ + y1 * cosZ;

    // Orthographic projection (no perspective)
    return Offset(x2 * 4, -y2 * 4 - z1 * 4);
  }

  @override
  bool shouldRepaint(Building3DPainter oldDelegate) => true;
}

// ============================================================================
// HELPER CLASSES
// ============================================================================

class _Point3D {
  final double x, y, z;
  _Point3D(this.x, this.y, this.z);
}

class _DrawableElement {
  final double zDepth;
  final void Function(Canvas) draw;

  _DrawableElement({required this.zDepth, required this.draw});
}

// ============================================================================
// EXTENSIONS
// ============================================================================

extension ColorExtension on Color {
  Color darken(double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}
