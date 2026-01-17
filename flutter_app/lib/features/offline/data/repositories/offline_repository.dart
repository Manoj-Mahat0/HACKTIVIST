import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../models/building.dart';
import '../../../../models/floor.dart';
import '../../../../models/room.dart';
import '../../../../models/navigation_node.dart';
import '../../../../models/qr_marker.dart';
import '../../../../models/offline_building.dart';
import '../../../../models/sync_log.dart';

class OfflineRepository {
  final ApiClient _apiClient;
  final LocalDatabase _database;
  final Uuid _uuid = const Uuid();
  
  late final ApiService _apiService;
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;
  bool _isAutoSyncing = false;
  
  // Stream controller for sync status updates
  final StreamController<Map<String, dynamic>> _syncStatusController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get syncStatusStream => _syncStatusController.stream;

  OfflineRepository(this._apiClient, this._database) {
    _apiService = getIt<ApiService>();
    _setupAutoSync();
  }
  
  void _setupAutoSync() {
    try {
      final connectivityService = getIt<ConnectivityService>();
      _connectivitySubscription = connectivityService.statusStream.listen((status) {
        if (status == ConnectivityStatus.online && !_isAutoSyncing) {
          _triggerAutoSync();
        }
      });
      
      // Also check on startup if we're online
      if (connectivityService.isOnline) {
        Future.delayed(const Duration(seconds: 3), () => _triggerAutoSync());
      }
      
      print('✅ Auto-sync setup complete');
    } catch (e) {
      print('⚠️ Could not setup auto-sync: $e');
    }
  }
  
  Future<void> _triggerAutoSync() async {
    if (_isAutoSyncing) return;
    
    try {
      final unsyncedBuildings = await getUnsyncedBuildings();
      if (unsyncedBuildings.isEmpty) return;
      
      print('🔄 Auto-sync triggered: ${unsyncedBuildings.length} buildings pending');
      _syncStatusController.add({
        'type': 'auto_sync_started',
        'pending_count': unsyncedBuildings.length,
      });
      
      _isAutoSyncing = true;
      final results = await syncAllOfflineData();
      
      _syncStatusController.add({
        'type': 'auto_sync_completed',
        'results': results,
      });
      
      print('✅ Auto-sync completed: ${results['buildings_synced']} synced, ${results['buildings_failed']} failed');
    } catch (e) {
      print('❌ Auto-sync failed: $e');
      _syncStatusController.add({
        'type': 'auto_sync_failed',
        'error': e.toString(),
      });
    } finally {
      _isAutoSyncing = false;
    }
  }
  
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
  }

  Future<List<Map<String, dynamic>>> getAvailableBuildings() async {
    final response = await _apiService.request<List<Map<String, dynamic>>>(
      method: 'GET',
      endpoint: '/offline/buildings',
      parser: (data) => List<Map<String, dynamic>>.from(data),
      cacheGetter: () async {
        // Return cached buildings list if available
        final buildings = await _database.getAllBuildings();
        return buildings.map((b) => {
          'id': b.id,
          'name': b.name,
          'address': b.address,
          'downloaded_at': b.downloadedAt.toIso8601String(),
          'version': b.version,
        }).toList();
      },
      description: 'Fetch available buildings',
    );
    
    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw Exception('Failed to fetch available buildings: ${response.error}');
    }
  }

  Future<void> downloadBuilding(String buildingId, {
    Function(double)? onProgress,
  }) async {
    try {
      // Check current version
      final existingBuilding = await _database.getBuilding(buildingId);
      final currentVersion = existingBuilding?.version ?? 0;

      // Download building data
      final response = await _apiClient.dio.get(
        '/offline/buildings/$buildingId/download',
        queryParameters: {'client_version': currentVersion},
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      final data = response.data;
      
      // Check if not modified
      if (data is Map && data['status'] == 'not_modified') {
        print('Building $buildingId is up to date (Version ${data['version']})');
        return;
      }

      // Save building
      final building = Building(
        id: data['building']['id'],
        name: data['building']['name'],
        address: data['building']['address'],
        downloadedAt: data['building']['downloaded_at'] != null 
            ? DateTime.parse(data['building']['downloaded_at'])
            : DateTime.now(),
        version: data['building']['version'],
      );
      await _database.saveBuilding(building);

      // Save floors
      for (final floorData in data['floors']) {
        final floor = Floor(
          id: floorData['id'],
          buildingId: floorData['building_id'],
          floorNumber: floorData['floor_number'],
          name: floorData['name'],
          width: floorData['width'].toDouble(),
          height: floorData['height'].toDouble(),
          originX: floorData['origin_x'].toDouble(),
          originY: floorData['origin_y'].toDouble(),
        );
        await _database.saveFloor(floor);
      }

      // Save rooms
      for (final roomData in data['rooms']) {
        final room = Room(
          id: roomData['id'],
          floorId: roomData['floor_id'],
          buildingId: roomData['building_id'],
          name: roomData['name'],
          type: roomData['type'],
          x: roomData['x'].toDouble(),
          y: roomData['y'].toDouble(),
          width: roomData['width'].toDouble(),
          height: roomData['height'].toDouble(),
          entranceNodeId: roomData['entrance_node_id'],
        );
        await _database.saveRoom(room);
      }

      // Save navigation nodes
      for (final nodeData in data['navigation_nodes']) {
        final node = NavigationNode(
          id: nodeData['id'],
          buildingId: nodeData['building_id'],
          floorId: nodeData['floor_id'],
          x: nodeData['x'].toDouble(),
          y: nodeData['y'].toDouble(),
          typeIndex: _parseNodeType(nodeData['type']).index,
          connectedNodeIds: List<String>.from(nodeData['connected_node_ids']),
          distances: Map<String, double>.from(
            nodeData['distances'].map((k, v) => MapEntry(k, v.toDouble())),
          ),
          name: nodeData['name'],
        );
        await _database.saveNavigationNode(node);
      }

      // Save QR markers
      for (final markerData in data['qr_markers']) {
        final marker = QRMarker(
          id: markerData['id'],
          buildingId: markerData['building_id'],
          floorId: markerData['floor_id'],
          x: markerData['x'].toDouble(),
          y: markerData['y'].toDouble(),
          orientationDegrees: markerData['orientation_degrees'].toDouble(),
          qrData: markerData['qr_data'],
          description: markerData['description'],
        );
        await _database.saveQRMarker(marker);
      }
    } catch (e) {
      throw Exception('Failed to download building: $e');
    }
  }

  Future<bool> isBuildingDownloaded(String buildingId) async {
    final building = await _database.getBuilding(buildingId);
    return building != null;
  }

  Future<void> deleteDownloadedBuilding(String buildingId) async {
    await _database.deleteBuilding(buildingId);
  }

  Future<List<Building>> getDownloadedBuildings() async {
    return await _database.getAllBuildings();
  }

  NodeType _parseNodeType(String type) {
    switch (type.toLowerCase()) {
      case 'corridor':
        return NodeType.corridor;
      case 'junction':
        return NodeType.junction;
      case 'entrance':
        return NodeType.entrance;
      case 'stairs':
        return NodeType.stairs;
      case 'elevator':
        return NodeType.elevator;
      case 'exit':
        return NodeType.exit;
      default:
        return NodeType.corridor;
    }
  }

  // Offline Building Creation - NO NETWORK CALLS
  Future<OfflineBuilding> createOfflineBuilding({
    required String name,
    required String description,
    required String address,
    required double latitude,
    required double longitude,
    required List<Map<String, double>> boundaryPoints,
  }) async {
    // Use provided address directly - no network calls for true offline support
    String finalAddress = address;
    if (finalAddress.isEmpty) {
      finalAddress = 'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
    }

    final building = OfflineBuilding(
      id: _uuid.v4(),
      name: name,
      description: description,
      address: finalAddress,
      latitude: latitude,
      longitude: longitude,
      boundaryPoints: boundaryPoints,
      createdAt: DateTime.now(),
    );

    await _database.saveOfflineBuilding(building);
    
    // Log the creation
    await _logSync(
      syncType: SyncType.building,
      itemId: building.id,
      itemName: building.name,
      status: SyncStatus.pending,
      metadata: {
        'action': 'created_offline',
        'address_source': 'user_provided',
      },
    );

    return building;
  }

  Future<List<OfflineBuilding>> getOfflineBuildings() async {
    return await _database.getAllOfflineBuildings();
  }

  Future<List<OfflineBuilding>> getUnsyncedBuildings() async {
    return await _database.getUnsyncedBuildings();
  }

  Future<void> deleteOfflineBuilding(String id) async {
    await _database.deleteOfflineBuilding(id);
  }

  // Sync Operations
  Future<Map<String, dynamic>> syncAllOfflineData() async {
    final results = <String, dynamic>{
      'buildings_synced': 0,
      'buildings_failed': 0,
      'errors': <String>[],
      'sync_logs': <Map<String, dynamic>>[],
    };

    try {
      final unsyncedBuildings = await getUnsyncedBuildings();
      
      for (final building in unsyncedBuildings) {
        try {
          await _syncBuilding(building);
          results['buildings_synced']++;
          results['sync_logs'].add({
            'type': 'building',
            'name': building.name,
            'status': 'success',
            'timestamp': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          results['buildings_failed']++;
          results['errors'].add('Failed to sync building "${building.name}": $e');
          results['sync_logs'].add({
            'type': 'building',
            'name': building.name,
            'status': 'failed',
            'error': e.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          });
          
          // Mark building with sync error
          await _database.markBuildingAsSynced(building.id, syncError: e.toString());
          
          // Log the failure
          await _logSync(
            syncType: SyncType.building,
            itemId: building.id,
            itemName: building.name,
            status: SyncStatus.failed,
            errorMessage: e.toString(),
          );
        }
      }
    } catch (e) {
      results['errors'].add('Sync operation failed: $e');
    }

    return results;
  }

  Future<void> _syncBuilding(OfflineBuilding building) async {
    try {
      // Use ApiService for robust building creation
      // Note: This requires admin privileges. Use /offline/sync/buildings once backend is updated.
      final response = await _apiService.request<Map<String, dynamic>>(
        method: 'POST',
        endpoint: '/buildings/',  // Regular endpoint (requires admin)
        data: building.toJson(),
        parser: (data) => Map<String, dynamic>.from(data),
        description: 'Sync building: ${building.name}',
        queueIfOffline: false, // Don't queue again if already syncing
      );
      
      if (response.success && response.data != null) {
        // Mark as synced
        await _database.markBuildingAsSynced(building.id);
        
        // Log successful sync
        await _logSync(
          syncType: SyncType.building,
          itemId: building.id,
          itemName: building.name,
          status: SyncStatus.success,
          metadata: {
            'server_id': response.data!['id'],
            'synced_at': DateTime.now().toIso8601String(),
            'source': response.source,
          },
        );
      } else {
        throw Exception(response.error ?? 'Unknown sync error');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _logSync({
    required SyncType syncType,
    required String itemId,
    required String itemName,
    required SyncStatus status,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) async {
    final log = SyncLog.withEnums(
      id: _uuid.v4(),
      syncType: syncType,
      itemId: itemId,
      itemName: itemName,
      status: status,
      timestamp: DateTime.now(),
      errorMessage: errorMessage,
      metadata: metadata,
    );

    await _database.saveSyncLog(log);
  }

  // Sync Logs
  Future<List<SyncLog>> getSyncLogs({int limit = 50}) async {
    return await _database.getRecentSyncLogs(limit: limit);
  }

  Future<Map<String, int>> getSyncStatistics() async {
    return await _database.getSyncStatistics();
  }

  Future<void> clearOldSyncLogs({int keepDays = 30}) async {
    await _database.clearOldSyncLogs(keepDays: keepDays);
  }

  // Connectivity check using ApiService
  Future<bool> isOnline() async {
    final status = await _apiService.getServiceStatus();
    return status['connectivity'] == 'online' && status['backend_available'] == true;
  }

  // Auto-sync when online
  Future<void> autoSyncIfOnline() async {
    if (await isOnline()) {
      final unsyncedCount = (await getUnsyncedBuildings()).length;
      if (unsyncedCount > 0) {
        await syncAllOfflineData();
      }
    }
  }

  // ============================================
  // ENHANCED OFFLINE NAVIGATION SUPPORT
  // ============================================

  /// Download complete navigation data for a building
  /// Includes nodes, edges, QR markers, and precomputed paths
  Future<OfflineDownloadResult> downloadBuildingForOffline(
    String buildingId, {
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      onProgress?.call(0.0, 'Starting download...');
      
      // Check if already downloaded
      final existingBuilding = await _database.getBuilding(buildingId);
      final currentVersion = existingBuilding?.version ?? 0;
      
      onProgress?.call(0.1, 'Fetching building data...');
      
      // Download building data
      final response = await _apiClient.dio.get(
        '/offline/buildings/$buildingId/download',
        queryParameters: {'client_version': currentVersion},
      );

      final data = response.data;
      
      // Check if not modified
      if (data is Map && data['status'] == 'not_modified') {
        return OfflineDownloadResult(
          success: true,
          message: 'Building is up to date',
          isUpToDate: true,
          version: data['version'],
        );
      }

      onProgress?.call(0.2, 'Saving building info...');
      
      // Save building
      final building = Building(
        id: data['building']['id'],
        name: data['building']['name'],
        address: data['building']['address'],
        downloadedAt: DateTime.now(),
        version: data['building']['version'] ?? 1,
      );
      await _database.saveBuilding(building);

      onProgress?.call(0.3, 'Saving floor data...');
      
      // Save floors
      for (final floorData in data['floors'] ?? []) {
        final floor = Floor(
          id: floorData['id'],
          buildingId: floorData['building_id'],
          floorNumber: floorData['floor_number'],
          name: floorData['name'],
          width: (floorData['width'] ?? 100).toDouble(),
          height: (floorData['height'] ?? 100).toDouble(),
          originX: (floorData['origin_x'] ?? 0).toDouble(),
          originY: (floorData['origin_y'] ?? 0).toDouble(),
        );
        await _database.saveFloor(floor);
      }

      onProgress?.call(0.4, 'Saving room data...');
      
      // Save rooms
      for (final roomData in data['rooms'] ?? []) {
        final room = Room(
          id: roomData['id'],
          floorId: roomData['floor_id'],
          buildingId: roomData['building_id'],
          name: roomData['name'],
          type: roomData['type'],
          x: (roomData['x'] ?? 0).toDouble(),
          y: (roomData['y'] ?? 0).toDouble(),
          width: (roomData['width'] ?? 10).toDouble(),
          height: (roomData['height'] ?? 10).toDouble(),
          entranceNodeId: roomData['entrance_node_id'],
        );
        await _database.saveRoom(room);
      }

      onProgress?.call(0.6, 'Saving navigation nodes...');
      
      // Save navigation nodes
      final nodes = <NavigationNode>[];
      for (final nodeData in data['navigation_nodes'] ?? []) {
        final node = NavigationNode(
          id: nodeData['id'],
          buildingId: nodeData['building_id'],
          floorId: nodeData['floor_id'],
          x: (nodeData['x'] ?? 0).toDouble(),
          y: (nodeData['y'] ?? 0).toDouble(),
          typeIndex: _parseNodeType(nodeData['type'] ?? 'corridor').index,
          connectedNodeIds: List<String>.from(nodeData['connected_node_ids'] ?? []),
          distances: Map<String, double>.from(
            (nodeData['distances'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
          ),
          name: nodeData['name'] ?? nodeData['label'],
        );
        nodes.add(node);
        await _database.saveNavigationNode(node);
      }

      onProgress?.call(0.8, 'Saving QR markers...');
      
      // Save QR markers
      final markers = <QRMarker>[];
      for (final markerData in data['qr_markers'] ?? []) {
        final marker = QRMarker(
          id: markerData['id'],
          buildingId: markerData['building_id'],
          floorId: markerData['floor_id'],
          x: (markerData['x'] ?? 0).toDouble(),
          y: (markerData['y'] ?? 0).toDouble(),
          orientationDegrees: (markerData['orientation_degrees'] ?? 0).toDouble(),
          qrData: markerData['qr_data'] ?? 'indoor-nav://${buildingId}/${markerData['id']}',
          description: markerData['description'],
        );
        markers.add(marker);
        await _database.saveQRMarker(marker);
      }

      onProgress?.call(1.0, 'Download complete!');
      
      return OfflineDownloadResult(
        success: true,
        message: 'Building downloaded successfully',
        nodeCount: nodes.length,
        markerCount: markers.length,
        version: building.version,
      );
    } catch (e) {
      print('❌ Failed to download building for offline: $e');
      return OfflineDownloadResult(
        success: false,
        message: 'Download failed: $e',
      );
    }
  }

  /// Check if a building is available for offline navigation
  Future<OfflineAvailability> checkOfflineAvailability(String buildingId) async {
    final building = await _database.getBuilding(buildingId);
    if (building == null) {
      return OfflineAvailability(
        isAvailable: false,
        reason: 'Building not downloaded',
        requiresDownload: true,
      );
    }
    
    final nodes = await _database.getNavigationNodes(buildingId);
    if (nodes.isEmpty) {
      return OfflineAvailability(
        isAvailable: false,
        reason: 'No navigation data available',
        requiresDownload: true,
      );
    }
    
    final markers = await _database.getQRMarkersForBuilding(buildingId);
    
    return OfflineAvailability(
      isAvailable: true,
      nodeCount: nodes.length,
      markerCount: markers.length,
      downloadedAt: building.downloadedAt,
      version: building.version,
    );
  }

  /// Get offline storage statistics
  Future<Map<String, dynamic>> getOfflineStats() async {
    return await _database.getOfflineStorageStats();
  }

  /// Delete offline data for a building
  Future<void> deleteOfflineData(String buildingId) async {
    await _database.deleteBuildingNavigationData(buildingId);
  }

  /// Check for updates to downloaded buildings
  Future<List<BuildingUpdateInfo>> checkForUpdates() async {
    final updates = <BuildingUpdateInfo>[];
    
    try {
      final downloadedBuildings = await _database.getAllBuildings();
      
      for (final building in downloadedBuildings) {
        try {
          final response = await _apiClient.dio.get(
            '/offline/buildings/${building.id}/version',
          );
          
          final serverVersion = response.data['version'] ?? 0;
          if (serverVersion > building.version) {
            updates.add(BuildingUpdateInfo(
              buildingId: building.id,
              buildingName: building.name,
              currentVersion: building.version,
              availableVersion: serverVersion,
            ));
          }
        } catch (e) {
          // Skip buildings that fail version check
          print('⚠️ Could not check version for ${building.name}: $e');
        }
      }
    } catch (e) {
      print('❌ Failed to check for updates: $e');
    }
    
    return updates;
  }
}

/// Result of offline download operation
class OfflineDownloadResult {
  final bool success;
  final String message;
  final bool isUpToDate;
  final int? nodeCount;
  final int? markerCount;
  final int? version;

  OfflineDownloadResult({
    required this.success,
    required this.message,
    this.isUpToDate = false,
    this.nodeCount,
    this.markerCount,
    this.version,
  });
}

/// Offline availability status
class OfflineAvailability {
  final bool isAvailable;
  final String? reason;
  final bool requiresDownload;
  final int? nodeCount;
  final int? markerCount;
  final DateTime? downloadedAt;
  final int? version;

  OfflineAvailability({
    required this.isAvailable,
    this.reason,
    this.requiresDownload = false,
    this.nodeCount,
    this.markerCount,
    this.downloadedAt,
    this.version,
  });
}

/// Building update information
class BuildingUpdateInfo {
  final String buildingId;
  final String buildingName;
  final int currentVersion;
  final int availableVersion;

  BuildingUpdateInfo({
    required this.buildingId,
    required this.buildingName,
    required this.currentVersion,
    required this.availableVersion,
  });
}
