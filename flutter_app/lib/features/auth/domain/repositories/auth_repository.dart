import 'package:indoor_navigation/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  // Traditional authentication methods
  Future<User> login({required String username, required String password});
  Future<User> signup({required String username, required String email, required String password, String role = 'user'});
  
  // OTPless authentication methods
  Future<Map<String, dynamic>> sendOTP({required String channel, String? phone, String? email});
  Future<String> otplessLogin({required String channel, required String otp, String? phone, String? email});
  Future<User> otplessSignup({required String channel, required String otp, required String username, String? phone, String? email, String role = 'user'});
  Future<String> socialLogin({required String token, String? username, String role = 'user'});
  
  // User management
  Future<void> logout();
  Future<User> getCurrentUser();
  Future<bool> isLoggedIn();
  Future<User> updateProfile({
    String? username,
    String? email,
    String? currentPassword,
    String? newPassword,
  });
  Future<User> uploadProfilePicture(String filePath);
  Future<User> deleteProfilePicture();
}