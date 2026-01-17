import 'package:indoor_navigation/features/auth/domain/entities/user.dart';
import 'package:indoor_navigation/features/auth/domain/repositories/auth_repository.dart';

class TraditionalLoginUseCase {
  final AuthRepository repository;

  TraditionalLoginUseCase(this.repository);

  Future<User> call({
    required String username,
    required String password,
  }) async {
    return await repository.login(
      username: username,
      password: password,
    );
  }
}