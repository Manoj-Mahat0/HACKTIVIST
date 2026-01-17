import 'package:indoor_navigation/features/buildings/domain/entities/building.dart';

abstract class BuildingsRepository {
  Future<List<Building>> getBuildings();
  Future<Building> getBuilding(String buildingId);
  Future<Building> createBuilding({
    required String name,
    required String description,
    required String address,
    required double latitude,
    required double longitude,
  });
  Future<Building> createBuildingWithBoundary({
    required String name,
    required String description,
    required String address,
    required double latitude,
    required double longitude,
    required List<Map<String, double>> boundaryPoints,
  });

  Future<Building> updateBuildingBoundary({
    required String buildingId,
    required double latitude,
    required double longitude,
    required List<Map<String, double>> boundaryPoints,
  });
}