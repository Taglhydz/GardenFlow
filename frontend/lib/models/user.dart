class User {
  final int? id;
  final String username;
  final String email;
  final String? password;
  final DateTime? birthdate;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    this.id,
    required this.username,
    required this.email,
    this.password,
    this.birthdate,
    this.role = 'user',
    this.createdAt,
    this.updatedAt,
  });

  // Convertir JSON en User
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      birthdate: json['birthdate'] != null 
          ? DateTime.parse(json['birthdate']) 
          : null,
      role: json['role'] ?? 'user',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }

  // Convertir User en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      if (password != null) 'password': password,
      'birthdate': birthdate?.toIso8601String(),
      'role': role,
    };
  }
}
