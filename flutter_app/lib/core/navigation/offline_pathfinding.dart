import 'dart:math';
import 'package:collection/collection.dart';
import '../../models/navigation_node.dart';

/// Enhanced pathfinding algorithms for offline navigation
/// Supports A*, Floyd-Warshall precomputation, and accessibility routing
class OfflinePathfinding {
  final List<NavigationNode> nodes;
  final Map<String, NavigationNode> nodeMap;
  
  // Floyd-Warshall precomputed distances and paths
  Map<String, Map<String, double>>? _precomputedDistances;
  Map<String, Map<String, String?>>? _precomputedNextHop;
  bool _isPrecomputed = false;

  OfflinePathfinding(this.nodes) : nodeMap = {for (var n in nodes) n.id: n};

  /// Check if Floyd-Warshall has been precomputed
  bool get isPrecomputed => _isPrecomputed;

  /// Precompute all-pairs shortest paths using Floyd-Warshall
  /// Call this once when building data is downloaded for instant offline routing
  void precomputeAllPaths() {
    if (nodes.isEmpty) return;
    
    final nodeIds = nodes.map((n) => n.id).toList();
    final n = nodeIds.length;
    
    // Initialize distance and next-hop matrices
    _precomputedDistances = {};
    _precomputedNextHop = {};
    
    for (final id in nodeIds) {
      _precomputedDistances![id] = {};
      _precomputedNextHop![id] = {};
      for (final jd in nodeIds) {
        _precomputedDistances![id]![jd] = id == jd ? 0 : double.infinity;
        _precomputedNextHop![id]![jd] = null;
      }
    }
    
    // Initialize with direct edges
    for (final node in nodes) {
      for (final neighborId in node.connectedNodeIds) {
        final neighbor = nodeMap[neighborId];
        if (neighbor != null) {
          final dist = node.distances[neighborId] ?? _calculateDistance(node, neighbor);
          _precomputedDistances![node.id]![neighborId] = dist;
          _precomputedNextHop![node.id]![neighborId] = neighborId;
        }
      }
    }
    
    // Floyd-Warshall algorithm
    for (final k in nodeIds) {
      for (final i in nodeIds) {
        for (final j in nodeIds) {
          final throughK = _precomputedDistances![i]![k]! + _precomputedDistances![k]![j]!;
          if (throughK < _precomputedDistances![i]![j]!) {
            _precomputedDistances![i]![j] = throughK;
            _precomputedNextHop![i]![j] = _precomputedNextHop![i]![k];
          }
        }
      }
    }
    
    _isPrecomputed = true;
  }

  /// Find path using precomputed Floyd-Warshall (O(n) path reconstruction)
  List<NavigationNode>? findPathPrecomputed(String startId, String endId) {
    if (!_isPrecomputed || _precomputedNextHop == null) {
      return findPathAStar(startId, endId);
    }
    
    if (_precomputedNextHop![startId]?[endId] == null && startId != endId) {
      return null; // No path exists
    }
    
    final path = <NavigationNode>[];
    String? current = startId;
    
    // Prevent infinite loops
    final visited = <String>{};
    
    while (current != null && current != endId) {
      if (visited.contains(current)) break;
      visited.add(current);
      
      final node = nodeMap[current];
      if (node != null) path.add(node);
      current = _precomputedNextHop![current]?[endId];
    }
    
    // Add destination
    final endNode = nodeMap[endId];
    if (endNode != null && (path.isEmpty || path.last.id != endId)) {
      path.add(endNode);
    }
    
    return path.isEmpty ? null : path;
  }

  /// Get precomputed distance between two nodes
  double? getPrecomputedDistance(String startId, String endId) {
    if (!_isPrecomputed || _precomputedDistances == null) return null;
    final dist = _precomputedDistances![startId]?[endId];
    return dist == double.infinity ? null : dist;
  }

  /// Find path using A* algorithm (for when precomputation isn't available)
  List<NavigationNode>? findPathAStar(String startId, String endId, {
    bool accessibleOnly = false,
    bool avoidCrowds = false,
  }) {
    final start = nodeMap[startId];
    final end = nodeMap[endId];
    if (start == null || end == null) return null;

    final openSet = PriorityQueue<_NodeScore>((a, b) => a.fScore.compareTo(b.fScore));
    final openSetIds = <String>{};
    final closedSet = <String>{};
    final cameFrom = <String, String>{};
    final gScore = <String, double>{};
    final fScore = <String, double>{};

    gScore[startId] = 0;
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

        final neighbor = nodeMap[neighborId];
        if (neighbor == null) continue;
        
        // Skip stairs if accessible route required
        if (accessibleOnly && neighbor.type == NodeType.stairs) continue;

        double edgeCost = currentNode.distances[neighborId] ?? 
            _calculateDistance(currentNode, neighbor);
        
        // Add penalty for crowded areas (simulated)
        if (avoidCrowds) {
          edgeCost *= 1.2; // 20% penalty
        }

        final tentativeG = gScore[current.nodeId]! + edgeCost;

        if (!openSetIds.contains(neighborId)) {
          openSetIds.add(neighborId);
          gScore[neighborId] = tentativeG;
          fScore[neighborId] = tentativeG + _heuristic(neighbor, end);
          openSet.add(_NodeScore(neighborId, fScore[neighborId]!));
          cameFrom[neighborId] = current.nodeId;
        } else if (tentativeG < (gScore[neighborId] ?? double.infinity)) {
          cameFrom[neighborId] = current.nodeId;
          gScore[neighborId] = tentativeG;
          fScore[neighborId] = tentativeG + _heuristic(neighbor, end);
        }
      }
    }

    return null;
  }

  /// Find accessible route (avoids stairs, prefers elevators)
  List<NavigationNode>? findAccessiblePath(String startId, String endId) {
    return findPathAStar(startId, endId, accessibleOnly: true);
  }

  /// Find alternative route for A/B testing
  List<NavigationNode>? findAlternativePath(String startId, String endId, 
      List<NavigationNode>? primaryPath) {
    if (primaryPath == null || primaryPath.length < 3) return null;
    
    // Try to find a path that avoids the middle nodes of the primary path
    final middleNodes = primaryPath.sublist(1, primaryPath.length - 1)
        .map((n) => n.id).toSet();
    
    final start = nodeMap[startId];
    final end = nodeMap[endId];
    if (start == null || end == null) return null;

    final openSet = PriorityQueue<_NodeScore>((a, b) => a.fScore.compareTo(b.fScore));
    final openSetIds = <String>{};
    final closedSet = <String>{};
    final cameFrom = <String, String>{};
    final gScore = <String, double>{};
    final fScore = <String, double>{};

    gScore[startId] = 0;
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

        final neighbor = nodeMap[neighborId];
        if (neighbor == null) continue;

        double edgeCost = currentNode.distances[neighborId] ?? 
            _calculateDistance(currentNode, neighbor);
        
        // Add penalty for nodes in primary path
        if (middleNodes.contains(neighborId)) {
          edgeCost *= 2.0; // Double the cost
        }

        final tentativeG = gScore[current.nodeId]! + edgeCost;

        if (!openSetIds.contains(neighborId)) {
          openSetIds.add(neighborId);
          gScore[neighborId] = tentativeG;
          fScore[neighborId] = tentativeG + _heuristic(neighbor, end);
          openSet.add(_NodeScore(neighborId, fScore[neighborId]!));
          cameFrom[neighborId] = current.nodeId;
        } else if (tentativeG < (gScore[neighborId] ?? double.infinity)) {
          cameFrom[neighborId] = current.nodeId;
          gScore[neighborId] = tentativeG;
          fScore[neighborId] = tentativeG + _heuristic(neighbor, end);
        }
      }
    }

    return null;
  }

  /// Find nearest emergency exit from a given node
  List<NavigationNode>? findNearestEmergencyExit(String fromNodeId) {
    final exitNodes = nodes.where((n) => 
        n.type == NodeType.exit || n.type == NodeType.entrance).toList();
    
    if (exitNodes.isEmpty) return null;
    
    List<NavigationNode>? shortestPath;
    double shortestDistance = double.infinity;
    
    for (final exit in exitNodes) {
      final path = _isPrecomputed 
          ? findPathPrecomputed(fromNodeId, exit.id)
          : findPathAStar(fromNodeId, exit.id);
      
      if (path != null) {
        final distance = _calculatePathDistance(path);
        if (distance < shortestDistance) {
          shortestDistance = distance;
          shortestPath = path;
        }
      }
    }
    
    return shortestPath;
  }

  double _heuristic(NavigationNode a, NavigationNode b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final floorDiff = (a.floorId.compareTo(b.floorId)).abs();
    return sqrt(dx * dx + dy * dy) + floorDiff * 3.0;
  }

  double _calculateDistance(NavigationNode a, NavigationNode b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  double _calculatePathDistance(List<NavigationNode> path) {
    double total = 0;
    for (int i = 0; i < path.length - 1; i++) {
      total += path[i].distances[path[i + 1].id] ?? 
          _calculateDistance(path[i], path[i + 1]);
    }
    return total;
  }

  List<NavigationNode> _reconstructPath(Map<String, String> cameFrom, String endId) {
    final path = <NavigationNode>[];
    String? current = endId;

    while (current != null) {
      path.add(nodeMap[current]!);
      current = cameFrom[current];
    }

    return path.reversed.toList();
  }

  /// Calculate ETA based on path distance and walking speed
  Duration calculateETA(List<NavigationNode> path, {double walkingSpeed = 1.2}) {
    final distance = _calculatePathDistance(path);
    final seconds = (distance / walkingSpeed).round();
    return Duration(seconds: seconds);
  }

  /// Calculate total steps based on path distance and step length
  int calculateSteps(List<NavigationNode> path, {double stepLength = 0.7}) {
    final distance = _calculatePathDistance(path);
    return (distance / stepLength).round();
  }
}

class _NodeScore {
  final String nodeId;
  final double fScore;
  _NodeScore(this.nodeId, this.fScore);
}
