import 'json_utils.dart';

class Garden {
  final int id;
  final int userId;
  final String name;
  final String? location;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Garden({
    required this.id,
    required this.userId,
    required this.name,
    this.location,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory Garden.fromJson(Map<String, dynamic> json) {
    return Garden(
      id: JsonUtils.toInt(json['id'])!,
      userId: JsonUtils.toInt(json['user_id'])!,
      name: json['name'] as String,
      location: json['location'] as String?,
      description: json['description'] as String?,
      createdAt: JsonUtils.toDate(json['created_at']),
      updatedAt: JsonUtils.toDate(json['updated_at']),
    );
  }
}
