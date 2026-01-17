import '../entities/ar_node.dart';

abstract class ArNavigationRepository {
  Future<void> saveBuildingGraph(String buildingId, List<ArNode> nodes);
  Future<List<ArNode>> getBuildingGraph(String buildingId);
}
