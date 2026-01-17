import 'package:indoor_navigation/features/navigation/domain/entities/ar_marker.dart';
import 'package:indoor_navigation/features/navigation/domain/repositories/navigation_repository.dart';

class GetArMarkersUseCase {
  final NavigationRepository repository;

  GetArMarkersUseCase(this.repository);

  Future<List<ArMarker>> call(String buildingId) async {
    return await repository.getArMarkers(buildingId);
  }
}