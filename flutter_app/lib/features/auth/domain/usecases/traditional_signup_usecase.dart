import 'package:indoor_navigation/features/auth/domain/entities/user.dart';
import 'package:indoor_navigation/features/auth/domain/repositories/auth_repository.dart';

class TraditionalSignupUseCase {
  final AuthRepository repository;

  TraditionalSignupUseCase(this.repository);

  Future<User> call({
    required String username,
    required String email,
    required String password,
    String role = 'user',
  }) async {
    return await repository.signup(
      username: username,
      email: email,
      password: password,
      role: role,
    );
  }
}