import 'package:indoor_navigation/features/navigation/domain/entities/navigation_request.dart';
import 'package:indoor_navigation/features/navigation/domain/entities/navigation_response.dart';
import 'package:indoor_navigation/features/navigation/domain/repositories/navigation_repository.dart';

class GetNavigationUseCase {
  final NavigationRepository repository;

  GetNavigationUseCase(this.repository);

  Future<NavigationResponse> call(NavigationRequest request) async {
    return await repository.getNavigation(request);
  }
}