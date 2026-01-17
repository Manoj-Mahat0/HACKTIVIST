import 'package:indoor_navigation/core/network/api_client.dart';
import 'package:indoor_navigation/features/buildings/data/models/building_model.dart';
import 'package:indoor_navigation/features/buildings/domain/entities/building.dart';
import 'package:indoor_navigation/features/buildings/domain/repositories/buildings_repository.dart';

class BuildingsRepositoryImpl implements BuildingsRepository {
  final ApiClient apiClient;

  BuildingsRepositoryImpl(this.apiClient);

  @override
  Future<List<Building>> getBuildings() async {
    try {
      final response = await apiClient.getBuildings();
      final List<dynamic> buildingsJson = response.data;
      return buildingsJson
          .map((json) => BuildingModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get buildings: ${e.toString()}');
    }
  }

  @override
  Future<Building> getBuilding(String buildingId) async {
    try {
      final response = await apiClient.getBuilding(buildingId);
      return BuildingModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to get building: ${e.toString()}');
    }
  }

  @override
  Future<Building> createBuilding({
    required String name,
    required String description,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final buildingData = {
        'name': name,
        'description': description,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      };
      final response = await apiClient.createBuilding(buildingData);
      return BuildingModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create building: ${e.toString()}');
    }
  }

  @override
  Future<Building> createBuildingWithBoundary({
    required String name,
    required String description,
    required String address,
    required double latitude,
    required double longitude,
    required List<Map<String, double>> boundaryPoints,
  }) async {
    try {
      final buildingData = {
        'name': name,
        'description': description,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'boundary_points': boundaryPoints,
      };
      final response = await apiClient.createBuilding(buildingData);
      return BuildingModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create building: ${e.toString()}');
    }
  }

  @override
  Future<Building> updateBuildingBoundary({
    required String buildingId,
    required double latitude,
    required double longitude,
    required List<Map<String, double>> boundaryPoints,
  }) async {
    try {
      final updateData = {
        'latitude': latitude,
        'longitude': longitude,
        'boundary_points': boundaryPoints,
      };
      final response = await apiClient.updateBuildingBoundary(buildingId, updateData);
      return BuildingModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update building boundary: ${e.toString()}');
    }
  }
}