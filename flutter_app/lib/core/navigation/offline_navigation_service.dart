import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../services/offline_qr_service.dart';
import '../services/connectivity_service.dart';
import '../positioning/pdr_engine.dart';
import '../positioning/local_position.dart';
import '../../models/navigation_node.dart';
import '../../models/building.dart';
import 'offline_pathfinding.dart';

/// Main orchestrator for offline navigation
/// Handles offline mode detection, local pathfinding, QR scanning, and PDR integration
class OfflineNavigationService {
  final LocalDatabase _database;
  final ConnectivityService? _connectivityService;
  final PDREngine _pdrEngine;
  
  // Services
  late final OfflineQRService _qrService;
  OfflinePathfinding? _pathfinding;
  
  // State
  String? _currentBuildingId;
  List<NavigationNode> _cachedNodes = [];
  bool _isOfflineMode = false;
  bool _isInitialized = false;
  
  // Current navigation state
  List<NavigationNode>? _currentPath;
  int _currentPathIndex = 0;
  NavigationNode? _currentPosition;
  NavigationNode? _destination;
  
  // Stream controllers
  final StreamController<OfflineNavigationState> _stateController = 
      StreamController<OfflineNavigationState>.broadcast();
  final StreamController<NavigationUpdate> _navigationController = 
      StreamController<NavigationUpdate>.broadcast();

  Stream<OfflineNavigationState> get stateStream => _stateController.stream;
  Stream<NavigationUpdate> get navigationStream => _navigationController.stream;

  OfflineNavigationService(
    this._database, 
    this._pdrEngine, 
    [this._connectivityService]
  ) {
    _qrService = OfflineQRService(_database);
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    _connectivityService?.statusStream.listen((status) {
      final wasOffline = _isOfflineMode;
      _isOfflineMode = status == ConnectivityStatus.offline;
      
      if (wasOffline != _isOfflineMode) {
        _stateController.add(OfflineNavigationState(
          isOffline: _isOfflineMode,
          buildingId: _currentBuildingId,
          isReady: _isInitialized,
          message: _isOfflineMode 
              ? 'Switched to offline mode' 
              : 'Online mode restored',
        ));
      }
    });
  }

  /// Check if offline navigation is available for a building
  Future<bool> isBuildingAvailableOffline(String buildingId) async {
    final building = await _database.getBuilding(buildingId);
    if (building == null) return false;
    
    final nodes = await _database.getNavigationNodes(buildingId);
    return nodes.isNotEmpty;
  }

  /// Initialize offline navigation for a building
  Future<OfflineInitResult> initializeForBuilding(String buildingId) async {
    try {
      // Check if building data exists
      final building = await _database.getBuilding(buildingId);
      if (building == null) {
        return OfflineInitResult(
          success: false,
          errorMessage: 'Building not downloaded for offline use',
          requiresDownload: true,
        );
      }
      
      // Load navigation nodes
      _cachedNodes = await _database.getNavigationNodes(buildingId);
      if (_cachedNodes.isEmpty) {
        return OfflineInitResult(
          success: false,
          errorMessage: 'No navigation data available for this building',
          requiresDownload: true,
        );
      }
      
      // Initialize pathfinding
      _pathfinding = OfflinePathfinding(_cachedNodes);
      
      // Precompute all paths for instant routing
      debugPrint('🔄 Precomputing paths for ${_cachedNodes.length} nodes...');
      _pathfinding!.precomputeAllPaths();
      debugPrint('✅ Path precomputation complete');
      
      _currentBuildingId = buildingId;
      _isInitialized = true;
      
      _stateController.add(OfflineNavigationState(
        isOffline: _isOfflineMode,
        buildingId: buildingId,
        isReady: true,
        nodeCount: _cachedNodes.length,
        message: 'Offline navigation ready',
      ));
      
      return OfflineInitResult(
        success: true,
        nodeCount: _cachedNodes.length,
        building: building,
      );
    } catch (e) {
      debugPrint('❌ Failed to initialize offline navigation: $e');
      return OfflineInitResult(
        success: false,
        errorMessage: 'Failed to initialize: $e',
      );
    }
  }

  /// Calculate route offline
  Future<OfflineRouteResult> calculateRoute({
    required String startNodeId,
    required String endNodeId,
    bool accessibleOnly = false,
    bool avoidCrowds = false,
    double stepLength = 0.7,
    double walkingSpeed = 1.2,
  }) async {
    if (!_isInitialized || _pathfinding == null) {
      return OfflineRouteResult(
        success: false,
        errorMessage: 'Offline navigation not initialized',
      );
    }
    
    try {
      // Use precomputed paths if available, otherwise A*
      List<NavigationNode>? path;
      
      if (accessibleOnly) {
        path = _pathfinding!.findAccessiblePath(startNodeId, endNodeId);
      } else if (_pathfinding!.isPrecomputed) {
        path = _pathfinding!.findPathPrecomputed(startNodeId, endNodeId);
      } else {
        path = _pathfinding!.findPathAStar(
          startNodeId, 
          endNodeId,
          accessibleOnly: accessibleOnly,
          avoidCrowds: avoidCrowds,
        );
      }
      
      if (path == null || path.isEmpty) {
        return OfflineRouteResult(
          success: false,
          errorMessage: 'No route found between these locations',
        );
      }
      
      // Calculate ETA and steps
      final eta = _pathfinding!.calculateETA(path, walkingSpeed: walkingSpeed);
      final steps = _pathfinding!.calculateSteps(path, stepLength: stepLength);
      
      // Generate turn-by-turn instructions
      final instructions = _generateInstructions(path);
      
      // Find alternative route for A/B testing
      List<NavigationNode>? alternativePath;
      if (path.length > 3) {
        alternativePath = _pathfinding!.findAlternativePath(
          startNodeId, endNodeId, path);
      }
      
      // Store current navigation state
      _currentPath = path;
      _currentPathIndex = 0;
      _currentPosition = path.first;
      _destination = path.last;
      
      return OfflineRouteResult(
        success: true,
        path: path,
        instructions: instructions,
        estimatedTime: eta,
        totalSteps: steps,
        alternativePath: alternativePath,
      );
    } catch (e) {
      debugPrint('❌ Route calculation failed: $e');
      return OfflineRouteResult(
        success: false,
        errorMessage: 'Route calculation failed: $e',
      );
    }
  }

  /// Process QR code scan for position reset
  Future<QRScanResult> processQRScan(String qrData) async {
    if (_currentBuildingId == null) {
      return QRScanResult(
        success: false,
        errorMessage: 'No building selected',
      );
    }
    
    final result = await _qrService.parseQRCode(qrData, _currentBuildingId!);
    
    if (result == null || !result.success) {
      return QRScanResult(
        success: false,
        errorMessage: result?.errorMessage ?? 'Failed to parse QR code',
        wrongBuilding: result?.wrongBuilding ?? false,
      );
    }
    
    // Update PDR engine position
    if (result.x != null && result.y != null) {
      _pdrEngine.resetPosition(
        result.x!,
        result.y!,
        result.floor ?? 0,
        result.orientation ?? 0,
      );
    }
    
    // Update current position
    final node = result.toNavigationNode();
    if (node != null) {
      _currentPosition = node;
      
      // Check if on current route
      if (_currentPath != null) {
        final pathIndex = _currentPath!.indexWhere((n) => n.id == node.id);
        if (pathIndex >= 0) {
          _currentPathIndex = pathIndex;
          _navigationController.add(NavigationUpdate(
            type: NavigationUpdateType.positionUpdated,
            currentNode: node,
            pathIndex: pathIndex,
            message: 'Position updated to ${node.name ?? node.id}',
          ));
        } else {
          // Off route - need to recalculate
          _navigationController.add(NavigationUpdate(
            type: NavigationUpdateType.offRoute,
            currentNode: node,
            message: 'You are off the planned route',
          ));
        }
      }
    }
    
    return QRScanResult(
      success: true,
      node: node,
      x: result.x,
      y: result.y,
      floor: result.floor,
      orientation: result.orientation,
    );
  }

  /// Find nearest emergency exit
  Future<OfflineRouteResult> findEmergencyExit() async {
    if (!_isInitialized || _pathfinding == null || _currentPosition == null) {
      return OfflineRouteResult(
        success: false,
        errorMessage: 'Cannot find emergency exit - position unknown',
      );
    }
    
    final path = _pathfinding!.findNearestEmergencyExit(_currentPosition!.id);
    
    if (path == null || path.isEmpty) {
      return OfflineRouteResult(
        success: false,
        errorMessage: 'No emergency exit found',
      );
    }
    
    final instructions = _generateInstructions(path);
    final eta = _pathfinding!.calculateETA(path);
    
    return OfflineRouteResult(
      success: true,
      path: path,
      instructions: instructions,
      estimatedTime: eta,
      isEmergencyRoute: true,
    );
  }

  /// Get all available locations for a building
  List<NavigationNode> getAvailableLocations() {
    return List.unmodifiable(_cachedNodes);
  }

  /// Get locations filtered by floor
  List<NavigationNode> getLocationsByFloor(String floorId) {
    return _cachedNodes.where((n) => n.floorId == floorId).toList();
  }

  /// Get node by ID
  NavigationNode? getNodeById(String nodeId) {
    try {
      return _cachedNodes.firstWhere((n) => n.id == nodeId);
    } catch (e) {
      return null;
    }
  }

  /// Generate turn-by-turn instructions from path
  List<RouteInstruction> _generateInstructions(List<NavigationNode> path) {
    final instructions = <RouteInstruction>[];
    
    for (int i = 0; i < path.length; i++) {
      final node = path[i];
      final prevNode = i > 0 ? path[i - 1] : null;
      final nextNode = i < path.length - 1 ? path[i + 1] : null;
      
      String instruction;
      String direction = '';
      double? distance;
      
      if (i == 0) {
        instruction = 'Start at ${node.name ?? 'your location'}';
      } else if (i == path.length - 1) {
        instruction = 'Arrive at ${node.name ?? 'destination'}';
      } else {
        // Calculate direction
        if (prevNode != null && nextNode != null) {
          direction = _calculateDirection(prevNode, node, nextNode);
          instruction = _generateTurnInstruction(node, direction);
        } else {
          instruction = 'Continue to ${node.name ?? 'next point'}';
        }
      }
      
      // Calculate distance to next node
      if (nextNode != null) {
        distance = node.distances[nextNode.id] ?? 
            _calculateDistanceBetween(node, nextNode);
      }
      
      instructions.add(RouteInstruction(
        nodeId: node.id,
        nodeName: node.name ?? 'Point ${i + 1}',
        nodeType: node.type.name,
        instruction: instruction,
        direction: direction,
        distance: distance,
        floor: int.tryParse(node.floorId) ?? 0,
        x: node.x,
        y: node.y,
      ));
    }
    
    return instructions;
  }

  String _calculateDirection(NavigationNode prev, NavigationNode current, NavigationNode next) {
    // Calculate vectors
    final v1x = current.x - prev.x;
    final v1y = current.y - prev.y;
    final v2x = next.x - current.x;
    final v2y = next.y - current.y;
    
    // Calculate cross product for turn direction
    final cross = v1x * v2y - v1y * v2x;
    
    // Calculate angle
    final dot = v1x * v2x + v1y * v2y;
    final mag1 = (v1x * v1x + v1y * v1y);
    final mag2 = (v2x * v2x + v2y * v2y);
    
    if (mag1 == 0 || mag2 == 0) return 'STRAIGHT';
    
    final angle = dot / (mag1 * mag2);
    
    if (angle > 0.9) return 'STRAIGHT';
    if (cross > 0) return angle > 0.5 ? 'SLIGHT_LEFT' : 'LEFT';
    if (cross < 0) return angle > 0.5 ? 'SLIGHT_RIGHT' : 'RIGHT';
    return 'STRAIGHT';
  }

  String _generateTurnInstruction(NavigationNode node, String direction) {
    final locationName = node.name ?? 'the next point';
    
    switch (direction) {
      case 'LEFT':
        return 'Turn left at $locationName';
      case 'RIGHT':
        return 'Turn right at $locationName';
      case 'SLIGHT_LEFT':
        return 'Bear left at $locationName';
      case 'SLIGHT_RIGHT':
        return 'Bear right at $locationName';
      case 'STRAIGHT':
      default:
        if (node.type == NodeType.stairs) {
          return 'Take the stairs at $locationName';
        } else if (node.type == NodeType.elevator) {
          return 'Take the elevator at $locationName';
        }
        return 'Continue straight past $locationName';
    }
  }

  double _calculateDistanceBetween(NavigationNode a, NavigationNode b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return (dx * dx + dy * dy);
  }

  /// Check if currently in offline mode
  bool get isOfflineMode => _isOfflineMode;

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Get current building ID
  String? get currentBuildingId => _currentBuildingId;

  /// Dispose resources
  void dispose() {
    _stateController.close();
    _navigationController.close();
    _qrService.clearCache();
  }
}

// Result classes
class OfflineInitResult {
  final bool success;
  final String? errorMessage;
  final bool requiresDownload;
  final int? nodeCount;
  final Building? building;

  OfflineInitResult({
    required this.success,
    this.errorMessage,
    this.requiresDownload = false,
    this.nodeCount,
    this.building,
  });
}

class OfflineRouteResult {
  final bool success;
  final String? errorMessage;
  final List<NavigationNode>? path;
  final List<RouteInstruction>? instructions;
  final Duration? estimatedTime;
  final int? totalSteps;
  final List<NavigationNode>? alternativePath;
  final bool isEmergencyRoute;

  OfflineRouteResult({
    required this.success,
    this.errorMessage,
    this.path,
    this.instructions,
    this.estimatedTime,
    this.totalSteps,
    this.alternativePath,
    this.isEmergencyRoute = false,
  });
}

class QRScanResult {
  final bool success;
  final String? errorMessage;
  final bool wrongBuilding;
  final NavigationNode? node;
  final double? x;
  final double? y;
  final int? floor;
  final double? orientation;

  QRScanResult({
    required this.success,
    this.errorMessage,
    this.wrongBuilding = false,
    this.node,
    this.x,
    this.y,
    this.floor,
    this.orientation,
  });
}

class RouteInstruction {
  final String nodeId;
  final String nodeName;
  final String nodeType;
  final String instruction;
  final String direction;
  final double? distance;
  final int floor;
  final double x;
  final double y;

  RouteInstruction({
    required this.nodeId,
    required this.nodeName,
    required this.nodeType,
    required this.instruction,
    required this.direction,
    this.distance,
    required this.floor,
    required this.x,
    required this.y,
  });
}

class OfflineNavigationState {
  final bool isOffline;
  final String? buildingId;
  final bool isReady;
  final int? nodeCount;
  final String? message;

  OfflineNavigationState({
    required this.isOffline,
    this.buildingId,
    required this.isReady,
    this.nodeCount,
    this.message,
  });
}

enum NavigationUpdateType {
  positionUpdated,
  offRoute,
  arrivedAtWaypoint,
  arrivedAtDestination,
  routeRecalculated,
}

class NavigationUpdate {
  final NavigationUpdateType type;
  final NavigationNode? currentNode;
  final int? pathIndex;
  final String? message;

  NavigationUpdate({
    required this.type,
    this.currentNode,
    this.pathIndex,
    this.message,
  });
}
