import 'package:flutter/material.dart';

class FloorPlanPainter extends CustomPainter {
  final List<RoomModel> rooms;
  final List<WallModel> walls;
  final PathModel? navigationPath;
  final Offset? userPosition;

  FloorPlanPainter({
    required this.rooms,
    required this.walls,
    this.navigationPath,
    this.userPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.black;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.grey.withOpacity(0.1);

    // Draw Rooms
    for (var room in rooms) {
      final rect = Rect.fromLTWH(
        room.x,
        room.y,
        room.width,
        room.height,
      );
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, paint);
      
      // Draw Room Name
      final textSpan = TextSpan(
        text: room.name,
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(minWidth: 0, maxWidth: room.width);
      textPainter.paint(canvas, Offset(room.x + 2, room.y + 2));
    }
    
    // Draw Walls
    final wallPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..color = Colors.black;
      
    for (var wall in walls) {
       canvas.drawLine(
         Offset(wall.startX, wall.startY), 
         Offset(wall.endX, wall.endY), 
         wallPaint
       );
    }

    // Draw Navigation Path
    if (navigationPath != null && navigationPath!.points.isNotEmpty) {
      final pathPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.blue
        ..strokeCap = StrokeCap.round;

      final path = Path();
      path.moveTo(navigationPath!.points.first.x, navigationPath!.points.first.y);
      for (var i = 1; i < navigationPath!.points.length; i++) {
        path.lineTo(navigationPath!.points[i].x, navigationPath!.points[i].y);
      }
      canvas.drawPath(path, pathPaint);
    }

    // Draw User Position
    if (userPosition != null) {
      final userPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.blue;
        
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.white;

      canvas.drawCircle(userPosition!, 6.0, userPaint);
      canvas.drawCircle(userPosition!, 6.0, borderPaint);
      
      // Draw accuracy circle
      final accuracyPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.blue.withOpacity(0.2);
        
      canvas.drawCircle(userPosition!, 15.0, accuracyPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Simple invalidation for dynamics
  }
}

// Minimal models for the painter to work independently
class RoomModel {
  final String name;
  final double x, y, width, height;
  RoomModel({required this.name, required this.x, required this.y, required this.width, required this.height});
}

class WallModel {
  final double startX, startY, endX, endY;
  WallModel({required this.startX, required this.startY, required this.endX, required this.endY});
}

class PathModel {
  final List<Point> points;
  PathModel({required this.points});
}

class Point {
  final double x, y;
  Point(this.x, this.y);
}
