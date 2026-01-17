import 'dart:math';
import '../entities/ar_node.dart';

class AStar {
  final List<ArNode> graph;

  AStar(this.graph);

  List<ArNode> findPath(String startId, String endId) {
    if (graph.isEmpty) return [];

    final startNode = graph.firstWhere((n) => n.id == startId, orElse: () => throw Exception('Start node not found'));
    final endNode = graph.firstWhere((n) => n.id == endId, orElse: () => throw Exception('End node not found'));

    final openSet = <String>{startId};
    final cameFrom = <String, String>{};
    
    final gScore = <String, double>{};
    for (var n in graph) {
      gScore[n.id] = double.infinity;
    }
    gScore[startId] = 0;

    final fScore = <String, double>{};
    for (var n in graph) {
      fScore[n.id] = double.infinity;
    }
    fScore[startId] = _heuristic(startNode, endNode);

    while (openSet.isNotEmpty) {
      // Get node with lowest fScore
      String currentId = openSet.reduce((a, b) => (fScore[a] ?? double.infinity) < (fScore[b] ?? double.infinity) ? a : b);

      if (currentId == endId) {
        return _reconstructPath(cameFrom, currentId);
      }

      openSet.remove(currentId);
      final currentNode = graph.firstWhere((n) => n.id == currentId);

      for (final neighborId in currentNode.neighbors) {
        // Find neighbor node
        try {
          final neighbor = graph.firstWhere((n) => n.id == neighborId);
          final tentativeGScore = (gScore[currentId] ?? double.infinity) + _distance(currentNode, neighbor);

          if (tentativeGScore < (gScore[neighborId] ?? double.infinity)) {
            cameFrom[neighborId] = currentId;
            gScore[neighborId] = tentativeGScore;
            fScore[neighborId] = tentativeGScore + _heuristic(neighbor, endNode);
            openSet.add(neighborId);
          }
        } catch (e) {
          // Neighbor might be deleted or invalid, skip
          continue;
        }
      }
    }

    return []; // No path found
  }

  List<ArNode> _reconstructPath(Map<String, String> cameFrom, String currentId) {
    final totalPath = <ArNode>[];
    totalPath.add(graph.firstWhere((n) => n.id == currentId));
    
    while (cameFrom.containsKey(currentId)) {
      currentId = cameFrom[currentId]!;
      totalPath.insert(0, graph.firstWhere((n) => n.id == currentId));
    }
    return totalPath;
  }

  double _heuristic(ArNode a, ArNode b) {
    return _distance(a, b);
  }

  double _distance(ArNode a, ArNode b) {
    return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2) + pow(a.z - b.z, 2));
  }
}
