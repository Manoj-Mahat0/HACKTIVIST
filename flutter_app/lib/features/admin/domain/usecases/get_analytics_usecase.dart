import 'package:indoor_navigation/features/admin/domain/entities/analytics.dart';
import 'package:indoor_navigation/features/admin/domain/repositories/admin_repository.dart';

class GetAnalyticsUseCase {
  final AdminRepository repository;

  GetAnalyticsUseCase(this.repository);

  Future<Analytics> call() async {
    return await repository.getAnalytics();
  }
}