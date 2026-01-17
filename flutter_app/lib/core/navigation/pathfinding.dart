import 'dart:math';
import 'package:collection/collection.dart';
import '../../models/navigation_node.dart';

class AStarPathfinding {
  final List<NavigationNode> nodes;
  final Map<String, NavigationNode> nodeMap;

  AStarPathfinding(this.nodes) : nodeMap = {for (var n in nodes) n.id: n};

  List<NavigationNode>? findPath(String startId, String endId) {
    final start = nodeMap[startId];
    final end = nodeMap[endId];
    if (start == null || end == null) return null;

    // Priority queue: (f_score, node_id)
    final openSet = PriorityQueue<_NodeScore>(
      (a, b) => a.fScore.compareTo(b.fScore),
    );
    final openSetIds = <String>{};

    // Track visited nodes
    final closedSet = <String>{};

    // Track path
    final cameFrom = <String, String>{};

    // g_score: cost from start to node
    final gScore = <String, double>{};
    gScore[startId] = 0;

    // f_score: g_score + heuristic
    final fScore = <String, double>{};
    fScore[startId] = _heuristic(start, end);

    openSet.add(_NodeScore(startId, fScore[startId]!));
    openSetIds.add(startId);

    while (openSet.isNotEmpty) {
      final current = openSet.removeFirst();
      openSetIds.remove(current.nodeId);

      if (current.nodeId == endId) {
        return _reconstructPath(cameFrom, endId);
      }

      closedSet.add(current.nodeId);

      final currentNode = nodeMap[current.nodeId]!;

      for (final neighborId in currentNode.connectedNodeIds) {
        if (closedSet.contains(neighborId)) continue;

        final neighbor = nodeMap[neighborId]!;
        final tentativeG = gScore[current.nodeId]! +
            (currentNode.distances[neighborId] ?? _calculateDistance(currentNode, neighbor));

        if (!openSetIds.contains(neighborId)) {
          openSetIds.add(neighborId);
          gScore[neighborId] = tentativeG;
          fScore[neighborId] = tentativeG + _heuristic(neighbor, end);
          openSet.add(_NodeScore(neighborId, fScore[neighborId]!));
          cameFrom[neighborId] = current.nodeId;
        } else if (tentativeG < gScore[neighborId]!) {
          cameFrom[neighborId] = current.nodeId;
          gScore[neighborId] = tentativeG;
          fScore[neighborId] = tentativeG + _heuristic(neighbor, end);
        }
      }
    }

    return null; // No path found
  }

  double _heuristic(NavigationNode a, NavigationNode b) {
    // Euclidean distance
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final floorDiff = (a.floorId.compareTo(b.floorId)).abs();

    // Add penalty for floor changes (3 meters per floor)
    return sqrt(dx * dx + dy * dy) + floorDiff * 3.0;
  }

  double _calculateDistance(NavigationNode a, NavigationNode b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  List<NavigationNode> _reconstructPath(
    Map<String, String> cameFrom,
    String endId,
  ) {
    final path = <NavigationNode>[];
    String? current = endId;

    while (current != null) {
      path.add(nodeMap[current]!);
      current = cameFrom[current];
    }

    return path.reversed.toList();
  }
}

class _NodeScore {
  final String nodeId;
  final double fScore;

  _NodeScore(this.nodeId, this.fScore);
}
