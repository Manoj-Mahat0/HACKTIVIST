import 'package:hive_flutter/hive_flutter.dart';
import '../../models/building.dart';
import '../../models/floor.dart';
import '../../models/room.dart';
import '../../models/navigation_node.dart';
import '../../models/qr_marker.dart';
import '../../models/offline_building.dart';
import '../../models/sync_log.dart';

class LocalDatabase {
  static const String buildingsBox = 'buildings';
  static const String floorsBox = 'floors';
  static const String roomsBox = 'rooms';
  static const String nodesBox = 'navigation_nodes';
  static const String markersBox = 'qr_markers';
  static const String offlineBuildingsBox = 'offline_buildings';
  static const String syncLogsBox = 'sync_logs';

  late Box<Building> _buildingsBox;
  late Box<Floor> _floorsBox;
  late Box<Room> _roomsBox;
  late Box<NavigationNode> _nodesBox;
  late Box<QRMarker> _markersBox;
  late Box<OfflineBuilding> _offlineBuildingsBox;
  late Box<SyncLog> _syncLogsBox;

  Future<void> init() async {
    try {
      await Hive.initFlutter();
      print('✅ Hive initialized');

      // Register adapters with error handling
      try {
        if (!Hive.isAdapterRegistered(0)) {
          Hive.registerAdapter(BuildingAdapter());
        }
        if (!Hive.isAdapterRegistered(1)) {
          Hive.registerAdapter(FloorAdapter());
        }
        if (!Hive.isAdapterRegistered(2)) {
          Hive.registerAdapter(RoomAdapter());
        }
        if (!Hive.isAdapterRegistered(3)) {
          Hive.registerAdapter(NavigationNodeAdapter());
        }
        if (!Hive.isAdapterRegistered(4)) {
          Hive.registerAdapter(QRMarkerAdapter());
        }
        if (!Hive.isAdapterRegistered(5)) {
          Hive.registerAdapter(OfflineBuildingAdapter());
        }
        if (!Hive.isAdapterRegistered(6)) {
          Hive.registerAdapter(SyncLogAdapter());
        }
        print('✅ All Hive adapters registered');
      } catch (e) {
        print('❌ Error registering Hive adapters: $e');
        rethrow;
      }

      // Open boxes with error handling
      try {
        _buildingsBox = await Hive.openBox<Building>(buildingsBox);
        _floorsBox = await Hive.openBox<Floor>(floorsBox);
        _roomsBox = await Hive.openBox<Room>(roomsBox);
        _nodesBox = await Hive.openBox<NavigationNode>(nodesBox);
        _markersBox = await Hive.openBox<QRMarker>(markersBox);
        _offlineBuildingsBox = await Hive.openBox<OfflineBuilding>(offlineBuildingsBox);
        _syncLogsBox = await Hive.openBox<SyncLog>(syncLogsBox);
        print('✅ All Hive boxes opened successfully');
      } catch (e) {
        print('❌ Error opening Hive boxes: $e');
        rethrow;
      }
    } catch (e) {
      print('❌ Failed to initialize local database: $e');
      rethrow;
    }
  }

  // Buildings
  Future<List<Building>> getAllBuildings() async {
    return _buildingsBox.values.toList();
  }

  Future<void> saveBuilding(Building building) async {
    await _buildingsBox.put(building.id, building);
  }

  Future<Building?> getBuilding(String id) async {
    return _buildingsBox.get(id);
  }

  Future<void> deleteBuilding(String id) async {
    await _buildingsBox.delete(id);
  }

  // Floors
  Future<List<Floor>> getFloors(String buildingId) async {
    return _floorsBox.values
        .where((floor) => floor.buildingId == buildingId)
        .toList();
  }

  Future<void> saveFloor(Floor floor) async {
    await _floorsBox.put(floor.id, floor);
  }

  Future<Floor?> getFloor(String id) async {
    return _floorsBox.get(id);
  }

  // Rooms
  Future<List<Room>> getRooms(String floorId) async {
    return _roomsBox.values.where((room) => room.floorId == floorId).toList();
  }

  Future<void> saveRoom(Room room) async {
    await _roomsBox.put(room.id, room);
  }

  Future<Room?> getRoom(String id) async {
    return _roomsBox.get(id);
  }

  Future<Room?> searchRoom(String buildingId, String roomName) async {
    try {
      return _roomsBox.values.firstWhere(
        (room) =>
            room.buildingId == buildingId &&
            room.name.toLowerCase().contains(roomName.toLowerCase()),
      );
    } catch (e) {
      return null;
    }
  }

  // Navigation Nodes
  Future<List<NavigationNode>> getNavigationNodes(String buildingId) async {
    return _nodesBox.values
        .where((node) => node.buildingId == buildingId)
        .toList();
  }

  Future<List<NavigationNode>> getFloorNodes(String floorId) async {
    return _nodesBox.values.where((node) => node.floorId == floorId).toList();
  }

  Future<void> saveNavigationNode(NavigationNode node) async {
    await _nodesBox.put(node.id, node);
  }

  Future<NavigationNode?> getNavigationNode(String id) async {
    return _nodesBox.get(id);
  }

  // QR Markers
  Future<List<QRMarker>> getQRMarkers(String floorId) async {
    return _markersBox.values.where((marker) => marker.floorId == floorId).toList();
  }

  Future<List<QRMarker>> getAllQRMarkers() async {
    return _markersBox.values.toList();
  }

  Future<void> saveQRMarker(QRMarker marker) async {
    await _markersBox.put(marker.id, marker);
  }

  Future<QRMarker?> getQRMarker(String id) async {
    return _markersBox.get(id);
  }

  // Bulk operations
  Future<void> clearAllData() async {
    await _buildingsBox.clear();
    await _floorsBox.clear();
    await _roomsBox.clear();
    await _nodesBox.clear();
    await _markersBox.clear();
    await _offlineBuildingsBox.clear();
    await _syncLogsBox.clear();
  }

  Future<void> deleteFloorData(String floorId) async {
    // Delete all related data for a floor
    final rooms = await getRooms(floorId);
    for (var room in rooms) {
      await _roomsBox.delete(room.id);
    }

    final nodes = await getFloorNodes(floorId);
    for (var node in nodes) {
      await _nodesBox.delete(node.id);
    }

    final markers = await getQRMarkers(floorId);
    for (var marker in markers) {
      await _markersBox.delete(marker.id);
    }

    await _floorsBox.delete(floorId);
  }

  // Offline Buildings
  Future<List<OfflineBuilding>> getAllOfflineBuildings() async {
    try {
      return _offlineBuildingsBox.values.toList();
    } catch (e) {
      print('❌ Error getting offline buildings: $e');
      return []; // Return empty list instead of crashing
    }
  }

  Future<List<OfflineBuilding>> getUnsyncedBuildings() async {
    try {
      return _offlineBuildingsBox.values.where((building) => !building.isSynced).toList();
    } catch (e) {
      print('❌ Error getting unsynced buildings: $e');
      return []; // Return empty list instead of crashing
    }
  }

  Future<void> saveOfflineBuilding(OfflineBuilding building) async {
    try {
      await _offlineBuildingsBox.put(building.id, building);
      print('✅ Offline building saved: ${building.name}');
    } catch (e) {
      print('❌ Error saving offline building: $e');
      rethrow; // This is important for user feedback
    }
  }

  Future<OfflineBuilding?> getOfflineBuilding(String id) async {
    return _offlineBuildingsBox.get(id);
  }

  Future<void> deleteOfflineBuilding(String id) async {
    await _offlineBuildingsBox.delete(id);
  }

  Future<void> markBuildingAsSynced(String id, {String? syncError}) async {
    final building = await getOfflineBuilding(id);
    if (building != null) {
      final updatedBuilding = building.copyWith(
        isSynced: syncError == null,
        syncedAt: syncError == null ? DateTime.now() : null,
        syncError: syncError,
      );
      await saveOfflineBuilding(updatedBuilding);
    }
  }

  // Sync Logs
  Future<List<SyncLog>> getAllSyncLogs() async {
    try {
      final logs = _syncLogsBox.values.toList();
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Most recent first
      return logs;
    } catch (e) {
      print('❌ Error getting sync logs: $e');
      return []; // Return empty list instead of crashing
    }
  }

  Future<List<SyncLog>> getRecentSyncLogs({int limit = 50}) async {
    try {
      final logs = await getAllSyncLogs();
      return logs.take(limit).toList();
    } catch (e) {
      print('❌ Error getting recent sync logs: $e');
      return []; // Return empty list instead of crashing
    }
  }

  Future<void> saveSyncLog(SyncLog log) async {
    try {
      await _syncLogsBox.put(log.id, log);
      print('✅ Sync log saved: ${log.itemName}');
    } catch (e) {
      print('❌ Error saving sync log: $e');
      // Don't rethrow for sync logs as they're not critical
    }
  }

  Future<void> clearOldSyncLogs({int keepDays = 30}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    final logsToDelete = _syncLogsBox.values
        .where((log) => log.timestamp.isBefore(cutoffDate))
        .toList();
    
    for (var log in logsToDelete) {
      await _syncLogsBox.delete(log.id);
    }
  }

  // Statistics
  Future<Map<String, int>> getSyncStatistics() async {
    final logs = await getAllSyncLogs();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    
    return {
      'total_synced': logs.where((log) => log.status == SyncStatus.success).length,
      'total_failed': logs.where((log) => log.status == SyncStatus.failed).length,
      'today_synced': logs.where((log) => 
        log.status == SyncStatus.success && 
        log.timestamp.isAfter(todayStart)
      ).length,
      'pending_buildings': (await getUnsyncedBuildings()).length,
    };
  }

  // ============================================
  // OFFLINE NAVIGATION SUPPORT
  // ============================================

  /// Get QR markers for a specific building
  Future<List<QRMarker>> getQRMarkersForBuilding(String buildingId) async {
    return _markersBox.values
        .where((marker) => marker.buildingId == buildingId)
        .toList();
  }

  /// Find QR marker by QR data content
  Future<QRMarker?> findQRMarkerByData(String qrData) async {
    try {
      return _markersBox.values.firstWhere(
        (marker) => marker.qrData == qrData || marker.qrData.contains(qrData),
      );
    } catch (e) {
      return null;
    }
  }

  /// Find navigation node by coordinates (approximate match)
  Future<NavigationNode?> findNodeByCoordinates(
    String buildingId, 
    double x, 
    double y, 
    String floorId, 
    {double tolerance = 1.0}
  ) async {
    final nodes = await getNavigationNodes(buildingId);
    
    for (final node in nodes) {
      if (node.floorId != floorId) continue;
      
      final dx = (node.x - x).abs();
      final dy = (node.y - y).abs();
      
      if (dx <= tolerance && dy <= tolerance) {
        return node;
      }
    }
    
    return null;
  }

  /// Get all navigation data for a building (for offline caching)
  Future<Map<String, dynamic>> getBuildingNavigationData(String buildingId) async {
    final building = await getBuilding(buildingId);
    final floors = await getFloors(buildingId);
    final nodes = await getNavigationNodes(buildingId);
    final markers = await getQRMarkersForBuilding(buildingId);
    
    final rooms = <Room>[];
    for (final floor in floors) {
      rooms.addAll(await getRooms(floor.id));
    }
    
    return {
      'building': building,
      'floors': floors,
      'rooms': rooms,
      'nodes': nodes,
      'markers': markers,
      'node_count': nodes.length,
      'marker_count': markers.length,
      'downloaded_at': building?.downloadedAt?.toIso8601String(),
      'version': building?.version,
    };
  }

  /// Save complete navigation graph for a building
  Future<void> saveNavigationGraph({
    required String buildingId,
    required List<NavigationNode> nodes,
    required List<QRMarker> markers,
  }) async {
    // Clear existing nodes and markers for this building
    final existingNodes = await getNavigationNodes(buildingId);
    for (final node in existingNodes) {
      await _nodesBox.delete(node.id);
    }
    
    final existingMarkers = await getQRMarkersForBuilding(buildingId);
    for (final marker in existingMarkers) {
      await _markersBox.delete(marker.id);
    }
    
    // Save new nodes
    for (final node in nodes) {
      await saveNavigationNode(node);
    }
    
    // Save new markers
    for (final marker in markers) {
      await saveQRMarker(marker);
    }
    
    print('✅ Saved navigation graph: ${nodes.length} nodes, ${markers.length} markers');
  }

  /// Check if building has complete navigation data
  Future<bool> hasBuildingNavigationData(String buildingId) async {
    final building = await getBuilding(buildingId);
    if (building == null) return false;
    
    final nodes = await getNavigationNodes(buildingId);
    return nodes.isNotEmpty;
  }

  /// Get offline storage statistics
  Future<Map<String, dynamic>> getOfflineStorageStats() async {
    final buildings = await getAllBuildings();
    final offlineBuildings = await getAllOfflineBuildings();
    
    int totalNodes = 0;
    int totalMarkers = 0;
    
    for (final building in buildings) {
      final nodes = await getNavigationNodes(building.id);
      final markers = await getQRMarkersForBuilding(building.id);
      totalNodes += nodes.length;
      totalMarkers += markers.length;
    }
    
    return {
      'downloaded_buildings': buildings.length,
      'offline_created_buildings': offlineBuildings.length,
      'total_nodes': totalNodes,
      'total_markers': totalMarkers,
      'unsynced_buildings': offlineBuildings.where((b) => !b.isSynced).length,
    };
  }

  /// Delete all navigation data for a building
  Future<void> deleteBuildingNavigationData(String buildingId) async {
    // Delete nodes
    final nodes = await getNavigationNodes(buildingId);
    for (final node in nodes) {
      await _nodesBox.delete(node.id);
    }
    
    // Delete markers
    final markers = await getQRMarkersForBuilding(buildingId);
    for (final marker in markers) {
      await _markersBox.delete(marker.id);
    }
    
    // Delete floors and rooms
    final floors = await getFloors(buildingId);
    for (final floor in floors) {
      await deleteFloorData(floor.id);
    }
    
    // Delete building
    await deleteBuilding(buildingId);
    
    print('✅ Deleted all navigation data for building: $buildingId');
  }
}
