import '../../domain/repositories/ar_navigation_repository.dart';
import '../../domain/entities/ar_node.dart';
import '../../data/models/ar_node_model.dart';
import '../../../../core/services/api_service.dart';

class ArNavigationRepositoryImpl implements ArNavigationRepository {
  final ApiService apiService;

  ArNavigationRepositoryImpl(this.apiService);

  @override
  Future<void> saveBuildingGraph(String buildingId, List<ArNode> nodes) async {
    final nodeModels = nodes.map((n) => ArNodeModel.fromEntity(n).toJson()).toList();
    
    final response = await apiService.request(
      method: 'POST',
      endpoint: '/buildings/$buildingId/nav-graph',
      data: {'nodes': nodeModels},
    );

    if (!response.success) {
      throw Exception(response.error ?? 'Failed to save graph');
    }
  }

  @override
  Future<List<ArNode>> getBuildingGraph(String buildingId) async {
    final response = await apiService.request(
      method: 'GET',
      endpoint: '/buildings/$buildingId/nav-graph',
    );

    if (!response.success || response.data == null) {
      throw Exception(response.error ?? 'Failed to load graph');
    }

    final data = response.data as Map<String, dynamic>;
    final nodesList = data['nodes'] as List<dynamic>;
    
    return nodesList.map((json) => ArNodeModel.fromJson(json)).toList();
  }
}
