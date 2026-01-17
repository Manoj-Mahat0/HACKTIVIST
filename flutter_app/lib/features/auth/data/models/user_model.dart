import 'package:indoor_navigation/features/auth/domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.username,
    required super.email,
    required super.isAdmin,
    required super.role,
    super.profilePicture,
    super.phone,
    super.authMethod = 'password',
    required super.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      isAdmin: json['is_admin'] ?? false,
      role: json['role'] ?? 'user',
      profilePicture: json['profile_picture'],
      phone: json['phone'],
      authMethod: json['auth_method'] ?? 'password',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'is_admin': isAdmin,
      'role': role,
      'profile_picture': profilePicture,
      'phone': phone,
      'auth_method': authMethod,
      'created_at': createdAt.toIso8601String(),
    };
  }
}