import 'package:indoor_navigation/core/network/api_client.dart';
import 'package:indoor_navigation/core/storage/token_storage.dart';
import 'package:indoor_navigation/features/auth/data/models/user_model.dart';
import 'package:indoor_navigation/features/auth/domain/entities/user.dart';
import 'package:indoor_navigation/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  AuthRepositoryImpl(this.apiClient, this.tokenStorage);

  // Traditional authentication methods
  @override
  Future<User> login({required String username, required String password}) async {
    try {
      final response = await apiClient.login(username, password);
      final token = response.data['access_token'];
      await tokenStorage.saveToken(token);
      return UserModel.fromJson(response.data['user']);
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  @override
  Future<User> signup({required String username, required String email, required String password, String role = 'user'}) async {
    try {
      final response = await apiClient.signup(username, email, password, role);
      final token = response.data['access_token'];
      await tokenStorage.saveToken(token);
      return UserModel.fromJson(response.data['user']);
    } catch (e) {
      throw Exception('Signup failed: ${e.toString()}');
    }
  }

  // OTPless methods - unified verify endpoint - unified verify endpoint
  @override
  Future<Map<String, dynamic>> sendOTP({required String channel, String? phone, String? email}) async {
    try {
      final response = await apiClient.sendOTP(
        channel: channel,
        phone: phone,
        email: email,
      );
      return {
        'success': response.data['success'] ?? false,
        'message': response.data['message'] ?? 'OTP sent successfully',
        'request_id': response.data['request_id'],
      };
    } catch (e) {
      throw Exception('Failed to send OTP: ${e.toString()}');
    }
  }

  @override
  Future<String> otplessLogin({required String channel, required String otp, String? phone, String? email}) async {
    try {
      // Use unified verify endpoint without username (for existing users)
      final response = await apiClient.verifyOTP(
        channel: channel,
        otp: otp,
        phone: phone,
        email: email,
      );
      final token = response.data['access_token'];
      await tokenStorage.saveToken(token);
      return token;
    } catch (e) {
      throw Exception('OTPless login failed: ${e.toString()}');
    }
  }

  @override
  Future<User> otplessSignup({required String channel, required String otp, required String username, String? phone, String? email, String role = 'user'}) async {
    try {
      // Use unified verify endpoint with username (for new users)
      final response = await apiClient.verifyOTP(
        channel: channel,
        otp: otp,
        username: username,
        phone: phone,
        email: email,
        role: role,
      );
      
      // Save token from signup response
      final token = response.data['access_token'];
      await tokenStorage.saveToken(token);
      
      // Return user data
      return UserModel.fromJson(response.data['user']);
    } catch (e) {
      throw Exception('OTPless signup failed: ${e.toString()}');
    }
  }

  @override
  Future<String> socialLogin({required String token, String? username, String role = 'user'}) async {
    try {
      final response = await apiClient.socialLogin(
        token: token,
        username: username,
        role: role,
      );
      final authToken = response.data['access_token'];
      await tokenStorage.saveToken(authToken);
      return authToken;
    } catch (e) {
      throw Exception('Social login failed: ${e.toString()}');
    }
  }

  @override
  Future<void> logout() async {
    await tokenStorage.deleteToken();
  }

  @override
  Future<User> getCurrentUser() async {
    try {
      final response = await apiClient.getCurrentUser();
      return UserModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to get current user: ${e.toString()}');
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    return await tokenStorage.hasToken();
  }

  @override
  Future<User> updateProfile({
    String? username,
    String? email,
    String? currentPassword,
    String? newPassword,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (username != null) data['username'] = username;
      if (email != null) data['email'] = email;
      if (currentPassword != null) data['current_password'] = currentPassword;
      if (newPassword != null) data['new_password'] = newPassword;
      
      final response = await apiClient.updateProfile(data);
      return UserModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  @override
  Future<User> uploadProfilePicture(String filePath) async {
    try {
      final response = await apiClient.uploadProfilePicture(filePath);
      return UserModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to upload profile picture: ${e.toString()}');
    }
  }

  @override
  Future<User> deleteProfilePicture() async {
    try {
      final response = await apiClient.deleteProfilePicture();
      return UserModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to delete profile picture: ${e.toString()}');
    }
  }
}