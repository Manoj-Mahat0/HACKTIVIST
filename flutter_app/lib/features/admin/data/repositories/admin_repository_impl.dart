import 'package:indoor_navigation/core/network/api_client.dart';
import 'package:indoor_navigation/features/admin/domain/entities/coordinate_gps.dart';
import 'package:indoor_navigation/features/admin/domain/entities/analytics.dart';
import 'package:indoor_navigation/features/admin/domain/repositories/admin_repository.dart';
import 'package:indoor_navigation/features/buildings/data/models/building_model.dart';

class AdminRepositoryImpl implements AdminRepository {
  final ApiClient apiClient;

  AdminRepositoryImpl(this.apiClient);

  @override
  Future<Map<String, dynamic>> generate3DModel(String buildingId, List<CoordinateGPS> coordinates) async {
    try {
      final coordinatesJson = coordinates.map((coord) => coord.toJson()).toList();
      final response = await apiClient.generate3DModel(buildingId, coordinatesJson);
      return response.data;
    } catch (e) {
      throw Exception('Failed to generate 3D model: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> getBuildingStructure(String buildingId) async {
    try {
      final response = await apiClient.getBuildingStructure(buildingId);
      return response.data;
    } catch (e) {
      throw Exception('Failed to get building structure: ${e.toString()}');
    }
  }

  @override
  Future<Analytics> getAnalytics() async {
    try {
      final response = await apiClient.getAnalytics();
      final data = response.data;
      
      final buildings = (data['buildings'] as List)
          .map((json) => BuildingModel.fromJson(json))
          .toList();
      
      return Analytics(
        totalBuildings: data['total_buildings'],
        totalFloors: data['total_floors'],
        totalRooms: data['total_rooms'],
        totalWaypoints: data['total_waypoints'],
        buildings: buildings,
      );
    } catch (e) {
      throw Exception('Failed to get analytics: ${e.toString()}');
    }
  }
}