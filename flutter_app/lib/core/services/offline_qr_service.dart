import 'dart:convert';
import '../database/local_database.dart';
import '../../models/navigation_node.dart';
import '../../models/qr_marker.dart';

/// Service for offline QR code parsing and location lookup
/// Works entirely offline using locally cached building data
class OfflineQRService {
  final LocalDatabase _database;
  
  // Cache for quick lookups
  Map<String, NavigationNode>? _nodeCache;
  Map<String, QRMarker>? _markerCache;
  String? _cachedBuildingId;

  OfflineQRService(this._database);

  /// Parse QR code and return location data
  /// Supports multiple QR formats:
  /// 1. indoor-nav://building_id/node_id
  /// 2. JSON format with position data
  /// 3. Simple node_id format
  Future<QRLocationResult?> parseQRCode(String qrData, String buildingId) async {
    // Ensure cache is loaded for this building
    await _ensureCacheLoaded(buildingId);
    
    try {
      // Format 1: indoor-nav://building_id/node_id
      if (qrData.startsWith('indoor-nav://')) {
        return _parseIndoorNavFormat(qrData, buildingId);
      }
      
      // Format 2: JSON format
      if (qrData.startsWith('{')) {
        return _parseJsonFormat(qrData, buildingId);
      }
      
      // Format 3: Simple node_id
      return _parseSimpleFormat(qrData, buildingId);
    } catch (e) {
      print('❌ Error parsing QR code: $e');
      return null;
    }
  }

  QRLocationResult? _parseIndoorNavFormat(String qrData, String expectedBuildingId) {
    final parts = qrData.replaceFirst('indoor-nav://', '').split('/');
    if (parts.length < 2) return null;
    
    final buildingId = parts[0];
    final nodeId = parts[1];
    
    // Verify building matches
    if (buildingId != expectedBuildingId) {
      return QRLocationResult(
        success: false,
        errorMessage: 'QR code is for a different building',
        wrongBuilding: true,
        detectedBuildingId: buildingId,
      );
    }
    
    // Look up node in cache
    final node = _nodeCache?[nodeId];
    if (node != null) {
      return QRLocationResult(
        success: true,
        node: node,
        x: node.x,
        y: node.y,
        floor: int.tryParse(node.floorId) ?? 0,
        nodeId: nodeId,
        buildingId: buildingId,
      );
    }
    
    // Try to find in QR markers
    final marker = _markerCache?.values.firstWhere(
      (m) => m.qrData.contains(nodeId),
      orElse: () => QRMarker(
        id: '', buildingId: '', floorId: '', x: 0, y: 0, 
        orientationDegrees: 0, qrData: '',
      ),
    );
    
    if (marker != null && marker.id.isNotEmpty) {
      return QRLocationResult(
        success: true,
        x: marker.x,
        y: marker.y,
        floor: int.tryParse(marker.floorId) ?? 0,
        orientation: marker.orientationDegrees,
        nodeId: nodeId,
        buildingId: buildingId,
        marker: marker,
      );
    }
    
    return QRLocationResult(
      success: false,
      errorMessage: 'Node not found in offline data',
      nodeId: nodeId,
      buildingId: buildingId,
    );
  }

  QRLocationResult? _parseJsonFormat(String qrData, String expectedBuildingId) {
    try {
      final data = jsonDecode(qrData) as Map<String, dynamic>;
      
      final buildingId = data['building_id'] as String?;
      final nodeId = data['node_id'] as String?;
      
      // Verify building matches
      if (buildingId != null && buildingId != expectedBuildingId) {
        return QRLocationResult(
          success: false,
          errorMessage: 'QR code is for a different building',
          wrongBuilding: true,
          detectedBuildingId: buildingId,
        );
      }
      
      // Extract position data directly from QR
      final x = (data['x'] ?? data['latitude'] ?? 0).toDouble();
      final y = (data['y'] ?? data['longitude'] ?? 0).toDouble();
      final floor = (data['floor'] ?? data['floor_number'] ?? 0).toInt();
      final orientation = (data['orientation'] ?? data['heading'] ?? 0).toDouble();
      final label = data['label'] ?? data['name'] ?? 'Scanned Location';
      final nodeType = data['node_type'] ?? data['type'] ?? 'waypoint';
      
      // Try to find matching node
      NavigationNode? node;
      if (nodeId != null) {
        node = _nodeCache?[nodeId];
      }
      
      // If no node found, create a temporary one from QR data
      if (node == null && x != 0 && y != 0) {
        return QRLocationResult(
          success: true,
          x: x,
          y: y,
          floor: floor,
          orientation: orientation,
          nodeId: nodeId,
          buildingId: buildingId ?? expectedBuildingId,
          label: label,
          nodeType: nodeType,
        );
      }
      
      if (node != null) {
        return QRLocationResult(
          success: true,
          node: node,
          x: node.x,
          y: node.y,
          floor: int.tryParse(node.floorId) ?? floor,
          orientation: orientation,
          nodeId: nodeId,
          buildingId: buildingId ?? expectedBuildingId,
        );
      }
      
      return QRLocationResult(
        success: false,
        errorMessage: 'Could not determine location from QR code',
      );
    } catch (e) {
      return QRLocationResult(
        success: false,
        errorMessage: 'Invalid JSON format: $e',
      );
    }
  }

  QRLocationResult? _parseSimpleFormat(String qrData, String buildingId) {
    // Assume qrData is just a node ID
    final node = _nodeCache?[qrData];
    if (node != null) {
      return QRLocationResult(
        success: true,
        node: node,
        x: node.x,
        y: node.y,
        floor: int.tryParse(node.floorId) ?? 0,
        nodeId: qrData,
        buildingId: buildingId,
      );
    }
    
    return QRLocationResult(
      success: false,
      errorMessage: 'Unknown QR code format',
    );
  }

  /// Load and cache building data for quick lookups
  Future<void> _ensureCacheLoaded(String buildingId) async {
    if (_cachedBuildingId == buildingId && _nodeCache != null) {
      return; // Already cached
    }
    
    // Load nodes
    final nodes = await _database.getNavigationNodes(buildingId);
    _nodeCache = {for (var n in nodes) n.id: n};
    
    // Load QR markers
    final markers = await _database.getAllQRMarkers();
    _markerCache = {for (var m in markers) m.id: m};
    
    _cachedBuildingId = buildingId;
    print('✅ Loaded ${nodes.length} nodes and ${markers.length} markers for offline QR lookup');
  }

  /// Clear cache (call when switching buildings)
  void clearCache() {
    _nodeCache = null;
    _markerCache = null;
    _cachedBuildingId = null;
  }

  /// Find node by ID from cache
  NavigationNode? getNodeById(String nodeId) {
    return _nodeCache?[nodeId];
  }

  /// Find nearest node to given coordinates
  NavigationNode? findNearestNode(double x, double y, String floorId) {
    if (_nodeCache == null || _nodeCache!.isEmpty) return null;
    
    NavigationNode? nearest;
    double minDistance = double.infinity;
    
    for (final node in _nodeCache!.values) {
      if (node.floorId != floorId) continue;
      
      final dx = node.x - x;
      final dy = node.y - y;
      final distance = dx * dx + dy * dy; // Skip sqrt for comparison
      
      if (distance < minDistance) {
        minDistance = distance;
        nearest = node;
      }
    }
    
    return nearest;
  }

  /// Generate QR code data for a node (admin use)
  static String generateQRData({
    required String buildingId,
    required String nodeId,
    double? x,
    double? y,
    int? floor,
    double? orientation,
    String? label,
    String? nodeType,
  }) {
    // Simple format for easy scanning
    if (x == null && y == null) {
      return 'indoor-nav://$buildingId/$nodeId';
    }
    
    // Full JSON format with position data
    return jsonEncode({
      'building_id': buildingId,
      'node_id': nodeId,
      'x': x,
      'y': y,
      'floor': floor ?? 0,
      'orientation': orientation ?? 0,
      'label': label,
      'node_type': nodeType ?? 'waypoint',
    });
  }
}

/// Result of QR code parsing
class QRLocationResult {
  final bool success;
  final String? errorMessage;
  final bool wrongBuilding;
  final String? detectedBuildingId;
  
  final NavigationNode? node;
  final QRMarker? marker;
  final double? x;
  final double? y;
  final int? floor;
  final double? orientation;
  final String? nodeId;
  final String? buildingId;
  final String? label;
  final String? nodeType;

  QRLocationResult({
    required this.success,
    this.errorMessage,
    this.wrongBuilding = false,
    this.detectedBuildingId,
    this.node,
    this.marker,
    this.x,
    this.y,
    this.floor,
    this.orientation,
    this.nodeId,
    this.buildingId,
    this.label,
    this.nodeType,
  });

  /// Convert to NavigationNode for use in navigation
  NavigationNode? toNavigationNode() {
    if (node != null) return node;
    
    if (x != null && y != null && nodeId != null) {
      return NavigationNode(
        id: nodeId!,
        buildingId: buildingId ?? '',
        floorId: floor?.toString() ?? '0',
        x: x!,
        y: y!,
        typeIndex: _parseNodeType(nodeType ?? 'waypoint').index,
        connectedNodeIds: [],
        distances: {},
        name: label,
      );
    }
    
    return null;
  }

  NodeType _parseNodeType(String type) {
    switch (type.toLowerCase()) {
      case 'corridor': return NodeType.corridor;
      case 'junction': return NodeType.junction;
      case 'entrance': return NodeType.entrance;
      case 'stairs': return NodeType.stairs;
      case 'elevator': return NodeType.elevator;
      case 'exit': return NodeType.exit;
      default: return NodeType.corridor;
    }
  }
}
