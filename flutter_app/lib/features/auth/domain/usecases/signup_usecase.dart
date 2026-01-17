import 'package:indoor_navigation/features/auth/domain/entities/user.dart';
import 'package:indoor_navigation/features/auth/domain/repositories/auth_repository.dart';

class SignupUseCase {
  final AuthRepository repository;

  SignupUseCase(this.repository);

  // OTPless signup
  Future<User> call({
    required String channel,
    required String otp,
    required String username,
    String? phone,
    String? email,
    String role = 'user',
  }) async {
    return await repository.otplessSignup(
      channel: channel,
      otp: otp,
      username: username,
      phone: phone,
      email: email,
      role: role,
    );
  }
}