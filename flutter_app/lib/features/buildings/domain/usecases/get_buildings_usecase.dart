import 'package:indoor_navigation/features/buildings/domain/entities/building.dart';
import 'package:indoor_navigation/features/buildings/domain/repositories/buildings_repository.dart';

class GetBuildingsUseCase {
  final BuildingsRepository repository;

  GetBuildingsUseCase(this.repository);

  Future<List<Building>> call() async {
    return await repository.getBuildings();
  }
}