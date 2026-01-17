import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String username;
  final String email;
  final bool isAdmin;
  final String role;  // "user" or "admin"
  final String? profilePicture;
  final String? phone;  // Phone number for OTPless
  final String authMethod;  // "password" or "otpless"
  final DateTime createdAt;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.isAdmin,
    required this.role,
    this.profilePicture,
    this.phone,
    this.authMethod = 'password',
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, username, email, isAdmin, role, profilePicture, phone, authMethod, createdAt];
}