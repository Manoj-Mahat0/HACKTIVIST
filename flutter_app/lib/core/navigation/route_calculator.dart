import 'dart:math';
import '../../models/navigation_node.dart';
import '../positioning/local_position.dart';

enum Direction {
  north,
  northeast,
  east,
  southeast,
  south,
  southwest,
  west,
  northwest,
}

class NavigationStep {
  final NavigationNode fromNode;
  final NavigationNode toNode;
  final double distance;
  final Direction direction;
  final String instruction;
  final bool isFloorChange;

  NavigationStep({
    required this.fromNode,
    required this.toNode,
    required this.distance,
    required this.direction,
    required this.instruction,
    required this.isFloorChange,
  });
}

class Route {
  final List<NavigationStep> steps;
  final double totalDistance;
  final Duration estimatedTime;

  Route({
    required this.steps,
    required this.totalDistance,
    required this.estimatedTime,
  });
}

class RouteCalculator {
  static Route calculateRoute(
    List<NavigationNode> path,
    LocalPosition currentPosition,
  ) {
    if (path.isEmpty) {
      return Route(
        steps: [],
        totalDistance: 0,
        estimatedTime: Duration.zero,
      );
    }

    final steps = <NavigationStep>[];
    double totalDistance = 0;

    for (int i = 0; i < path.length - 1; i++) {
      final current = path[i];
      final next = path[i + 1];

      // Calculate distance
      final distance = _calculateDistance(current, next);
      totalDistance += distance;

      // Calculate direction
      final direction = _calculateDirection(current, next);

      // Generate instruction
      final instruction = _generateInstruction(
        current,
        next,
        direction,
        distance,
      );

      steps.add(NavigationStep(
        fromNode: current,
        toNode: next,
        distance: distance,
        direction: direction,
        instruction: instruction,
        isFloorChange: current.floorId != next.floorId,
      ));
    }

    // Estimate time (1.4 m/s walking speed)
    final estimatedSeconds = (totalDistance / 1.4).round();

    return Route(
      steps: steps,
      totalDistance: totalDistance,
      estimatedTime: Duration(seconds: estimatedSeconds),
    );
  }

  static double _calculateDistance(NavigationNode a, NavigationNode b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  static Direction _calculateDirection(NavigationNode from, NavigationNode to) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final angle = atan2(dy, dx) * 180 / pi;

    // Convert angle to direction
    if (angle >= -22.5 && angle < 22.5) return Direction.east;
    if (angle >= 22.5 && angle < 67.5) return Direction.northeast;
    if (angle >= 67.5 && angle < 112.5) return Direction.north;
    if (angle >= 112.5 && angle < 157.5) return Direction.northwest;
    if (angle >= 157.5 || angle < -157.5) return Direction.west;
    if (angle >= -157.5 && angle < -112.5) return Direction.southwest;
    if (angle >= -112.5 && angle < -67.5) return Direction.south;
    return Direction.southeast;
  }

  static String _generateInstruction(
    NavigationNode current,
    NavigationNode next,
    Direction direction,
    double distance,
  ) {
    // Floor change
    if (current.floorId != next.floorId) {
      if (next.type == NodeType.stairs) {
        return 'Take stairs to Floor ${next.floorId}';
      } else if (next.type == NodeType.elevator) {
        return 'Take elevator to Floor ${next.floorId}';
      }
    }

    // Junction/Turn
    if (current.type == NodeType.junction) {
      return 'Turn ${direction.name} and walk ${distance.round()}m';
    }

    // Entrance
    if (next.type == NodeType.entrance) {
      return 'Enter ${next.name ?? "room"}';
    }

    // Default
    return 'Walk ${direction.name} for ${distance.round()}m';
  }

  static String directionToCompass(Direction direction) {
    const compassMap = {
      Direction.north: '↑ North',
      Direction.northeast: '↗ Northeast',
      Direction.east: '→ East',
      Direction.southeast: '↘ Southeast',
      Direction.south: '↓ South',
      Direction.southwest: '↙ Southwest',
      Direction.west: '← West',
      Direction.northwest: '↖ Northwest',
    };
    return compassMap[direction] ?? 'Unknown';
  }
}
