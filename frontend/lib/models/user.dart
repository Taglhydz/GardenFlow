import 'json_utils.dart';

class User {
  final int id;
  final String username;
  final String email;
  final DateTime? birthdate;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.username,
    required this.email,
    this.birthdate,
    this.role = 'user',
    this.createdAt,
    this.updatedAt,
  });

  bool get isAdmin => role == 'admin';

  // Convertir JSON en User
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: JsonUtils.toInt(json['id'])!,
      username: json['username'] as String,
      email: json['email'] as String,
      birthdate: JsonUtils.toDate(json['birthdate']),
      role: json['role'] as String? ?? 'user',
      createdAt: JsonUtils.toDate(json['created_at']),
      updatedAt: JsonUtils.toDate(json['updated_at']),
    );
  }
}
