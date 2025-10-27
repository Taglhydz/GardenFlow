class Garden {
  final int? id;
  final int userId;
  final String name;
  final String? location;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Garden({
    this.id,
    required this.userId,
    required this.name,
    this.location,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory Garden.fromJson(Map<String, dynamic> json) {
    return Garden(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      location: json['location'],
      description: json['description'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'location': location,
      'description': description,
    };
  }
}
