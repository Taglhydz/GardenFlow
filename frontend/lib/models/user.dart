import '../config/constants.dart';
import 'json_utils.dart';

class User {
  final int id;
  final String username;
  final String email;

  /// New email waiting for the link sent to it : [email] stays the login email until it is opened
  final String? pendingEmail;

  /// false for an account created with Google : no password, its email can't be changed
  final bool hasPassword;
  final DateTime? birthdate;
  final String role;

  /// Plant avatar (Avatars.codes) or photo (file name on the server) : one or the other, or none
  final String? avatar;
  final String? photo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.username,
    required this.email,
    this.pendingEmail,
    this.hasPassword = true,
    this.birthdate,
    this.role = 'user',
    this.avatar,
    this.photo,
    this.createdAt,
    this.updatedAt,
  });

  bool get isAdmin => role == 'admin';

  /// Address of the profile photo, served by the API
  String? get photoUrl => photo == null ? null : '${AppConstants.baseUrl}/uploads/photos/$photo';

  /// Username as displayed : stored in lowercase, first letter in uppercase ('tom le plus beau' -> 'Tom le plus beau')
  String get displayName =>
      username.isEmpty ? username : username[0].toUpperCase() + username.substring(1).toLowerCase();

  // Convertir JSON en User
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: JsonUtils.toInt(json['id'])!,
      username: json['username'] as String,
      email: json['email'] as String,
      pendingEmail: json['pending_email'] as String?,
      // MySQL sends 1 / 0
      hasPassword: json['has_password'] == true || json['has_password'] == 1,
      birthdate: JsonUtils.toDate(json['birthdate']),
      role: json['role'] as String? ?? 'user',
      avatar: json['avatar'] as String?,
      photo: json['photo'] as String?,
      createdAt: JsonUtils.toDate(json['created_at']),
      updatedAt: JsonUtils.toDate(json['updated_at']),
    );
  }
}
