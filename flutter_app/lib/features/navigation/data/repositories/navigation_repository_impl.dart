import 'package:indoor_navigation/core/network/api_client.dart';
import 'package:indoor_navigation/features/navigation/data/models/navigation_models.dart';
import 'package:indoor_navigation/features/navigation/domain/entities/navigation_request.dart';
import 'package:indoor_navigation/features/navigation/domain/entities/navigation_response.dart';
import 'package:indoor_navigation/features/navigation/domain/entities/ar_marker.dart';
import 'package:indoor_navigation/features/navigation/domain/repositories/navigation_repository.dart';

class NavigationRepositoryImpl implements NavigationRepository {
  final ApiClient apiClient;

  NavigationRepositoryImpl(this.apiClient);

  @override
  Future<NavigationResponse> getNavigation(NavigationRequest request) async {
    try {
      final response = await apiClient.getNavigation(request.toJson());
      return NavigationResponseModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to get navigation: ${e.toString()}');
    }
  }

  @override
  Future<List<ArMarker>> getArMarkers(String buildingId) async {
    try {
      final response = await apiClient.getArMarkers(buildingId);
      final List<dynamic> markersJson = response.data;
      return markersJson
          .map((json) => ArMarkerModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get AR markers: ${e.toString()}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getBuildingLocations(String buildingId) async {
    try {
      // First try the new indoor graph API
      final response = await apiClient.getIndoorGraph(buildingId);
      if (response.data is Map && response.data['nodes'] is List) {
        final nodes = response.data['nodes'] as List;
        return nodes.map((node) => {
          'id': node['id'] ?? '',
          'name': node['label'] ?? '',
          'node_type': node['node_type'] ?? 'waypoint',
          'floor_number': node['floor_number'] ?? 0,
          'latitude': node['latitude'] ?? 0.0,
          'longitude': node['longitude'] ?? 0.0,
          'image_url': node['image_url'],
          'qr_code': node['qr_code'],
          'is_emergency_exit': node['is_emergency_exit'] ?? false,
          'is_accessible': node['is_accessible'] ?? true,
          'landmark_description': node['landmark_description'],
          'neighbors': (node['edges'] as List?)?.map((e) => e['to_node_id']).toList() ?? [],
        }).toList().cast<Map<String, dynamic>>();
      }
      
      // Fallback to old API
      final fallbackResponse = await apiClient.getBuildingLocations(buildingId);
      if (fallbackResponse.data is List) {
        return List<Map<String, dynamic>>.from(fallbackResponse.data);
      }
      return [];
    } catch (e) {
      // Try fallback API
      try {
        final fallbackResponse = await apiClient.getBuildingLocations(buildingId);
        if (fallbackResponse.data is List) {
          return List<Map<String, dynamic>>.from(fallbackResponse.data);
        }
      } catch (_) {}
      throw Exception('Failed to get building locations: ${e.toString()}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> calculateRoute(
    String buildingId,
    String startNodeId,
    String endNodeId, {
    bool accessible = false,
    bool avoidCrowds = false,
    double stepLength = 0.7,
    double walkingSpeed = 1.2,
  }) async {
    try {
      // Use the new indoor graph route API with options
      final response = await apiClient.getIndoorRoute(
        buildingId,
        startNodeId,
        endNodeId,
        accessible: accessible,
        avoidCrowds: avoidCrowds,
        stepLength: stepLength,
        walkingSpeed: walkingSpeed,
      );
      
      if (response.data is Map && response.data['instructions'] is List) {
        final instructions = response.data['instructions'] as List;
        return instructions.map((step) => {
          'id': step['node_id'] ?? '',
          'name': step['label'] ?? '',
          'node_type': step['node_type'] ?? 'waypoint',
          'instruction': step['instruction'] ?? '',
          'floor_number': step['floor'] ?? 0,
          'distance': step['steps_to_next']?.toDouble(),
          'image_url': step['image_url'],
          'direction': step['direction'],
          'steps_to_next': step['steps_to_next'],
          'haptic': step['haptic'],
          'animation': step['animation'],
          'qr_code': step['qr_code'],
          'landmark': step['landmark'],
        }).toList().cast<Map<String, dynamic>>();
      }
      
      // Fallback to old API
      final fallbackResponse = await apiClient.calculateSmartRoute(
        buildingId,
        startNodeId,
        endNodeId,
      );
      if (fallbackResponse.data is Map && fallbackResponse.data['steps'] is List) {
        return List<Map<String, dynamic>>.from(fallbackResponse.data['steps']);
      }
      return [];
    } catch (e) {
      // Try fallback API
      try {
        final fallbackResponse = await apiClient.calculateSmartRoute(
          buildingId,
          startNodeId,
          endNodeId,
        );
        if (fallbackResponse.data is Map && fallbackResponse.data['steps'] is List) {
          return List<Map<String, dynamic>>.from(fallbackResponse.data['steps']);
        }
      } catch (_) {}
      throw Exception('Failed to calculate route: ${e.toString()}');
    }
  }

  /// Get route with accessibility and crowd avoidance options
  Future<Map<String, dynamic>> getIndoorRoute(
    String buildingId,
    String fromNode,
    String toNode, {
    bool accessible = false,
    bool avoidCrowds = false,
    double stepLength = 0.7,
    double walkingSpeed = 1.2,
  }) async {
    try {
      final response = await apiClient.getIndoorRoute(
        buildingId,
        fromNode,
        toNode,
        accessible: accessible,
        avoidCrowds: avoidCrowds,
        stepLength: stepLength,
        walkingSpeed: walkingSpeed,
      );
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception('Failed to get indoor route: ${e.toString()}');
    }
  }

  /// Get nearest emergency exit
  Future<Map<String, dynamic>> getNearestEmergencyExit(
    String buildingId,
    String fromNode, {
    bool accessible = false,
  }) async {
    try {
      final response = await apiClient.getNearestEmergencyExit(
        buildingId,
        fromNode,
        accessible: accessible,
      );
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception('Failed to get emergency exit: ${e.toString()}');
    }
  }

  /// Lookup node by QR code
  Future<Map<String, dynamic>?> lookupNodeByQR(String buildingId, String qrData) async {
    try {
      final response = await apiClient.lookupNodeByQR(buildingId, qrData);
      if (response.data['found'] == true) {
        return Map<String, dynamic>.from(response.data['node']);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to lookup QR: ${e.toString()}');
    }
  }

  /// Get user favorites
  Future<List<Map<String, dynamic>>> getFavorites() async {
    try {
      final response = await apiClient.getFavorites();
      if (response.data['favorites'] is List) {
        return List<Map<String, dynamic>>.from(response.data['favorites']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Add favorite
  Future<void> addFavorite(String nodeId, String label, String buildingId) async {
    await apiClient.addFavorite({
      'node_id': nodeId,
      'label': label,
      'building_id': buildingId,
    });
  }

  /// Get recent routes
  Future<List<Map<String, dynamic>>> getRecentRoutes() async {
    try {
      final response = await apiClient.getRecentRoutes();
      if (response.data['recent_routes'] is List) {
        return List<Map<String, dynamic>>.from(response.data['recent_routes']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Share location
  Future<Map<String, dynamic>> shareLocation(
    String nodeId,
    String buildingId, {
    String? message,
    int expiresInMinutes = 60,
  }) async {
    try {
      final response = await apiClient.shareLocation({
        'node_id': nodeId,
        'building_id': buildingId,
        'message': message,
        'expires_in_minutes': expiresInMinutes,
      });
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception('Failed to share location: ${e.toString()}');
    }
  }
}