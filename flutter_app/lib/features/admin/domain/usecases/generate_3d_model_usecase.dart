import 'package:indoor_navigation/features/admin/domain/entities/coordinate_gps.dart';
import 'package:indoor_navigation/features/admin/domain/repositories/admin_repository.dart';

class Generate3DModelUseCase {
  final AdminRepository repository;

  Generate3DModelUseCase(this.repository);

  Future<Map<String, dynamic>> call(String buildingId, List<CoordinateGPS> coordinates) async {
    return await repository.generate3DModel(buildingId, coordinates);
  }
}