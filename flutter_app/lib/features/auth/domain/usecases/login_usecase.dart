import 'package:indoor_navigation/features/auth/domain/repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  // OTPless login
  Future<String> call({
    required String channel,
    required String otp,
    String? phone,
    String? email,
  }) async {
    return await repository.otplessLogin(
      channel: channel,
      otp: otp,
      phone: phone,
      email: email,
    );
  }
}