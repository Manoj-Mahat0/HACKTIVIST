import 'package:indoor_navigation/features/admin/domain/entities/coordinate_gps.dart';
import 'package:indoor_navigation/features/admin/domain/entities/analytics.dart';

abstract class AdminRepository {
  Future<Map<String, dynamic>> generate3DModel(String buildingId, List<CoordinateGPS> coordinates);
  Future<Map<String, dynamic>> getBuildingStructure(String buildingId);
  Future<Analytics> getAnalytics();
}