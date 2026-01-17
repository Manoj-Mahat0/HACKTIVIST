import 'package:indoor_navigation/features/admin/domain/repositories/admin_repository.dart';

class GetBuildingStructureUseCase {
  final AdminRepository repository;

  GetBuildingStructureUseCase(this.repository);

  Future<Map<String, dynamic>> call(String buildingId) async {
    return await repository.getBuildingStructure(buildingId);
  }
}
