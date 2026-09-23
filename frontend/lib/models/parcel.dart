import 'json_utils.dart';

/// Dimensions and positions are in meters, relative to the garden's top-left corner.
class Parcel {
  final int id;
  final int gardenId;
  final String name;
  final double? areaM2;
  final double posX;
  final double posY;
  final double width;
  final double length;
  final String soilType;
  final String sunlight;
  final String moisture;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Parcel({
    required this.id,
    required this.gardenId,
    required this.name,
    this.areaM2,
    this.posX = 0,
    this.posY = 0,
    this.width = 0,
    this.length = 0,
    this.soilType = 'standard',
    this.sunlight = 'medium',
    this.moisture = 'medium',
    this.createdAt,
    this.updatedAt,
  });

  /// Used to show a move / resize on the plan before the server answers.
  Parcel copyWith({double? posX, double? posY, double? width, double? length}) {
    return Parcel(
      id: id,
      gardenId: gardenId,
      name: name,
      areaM2: width != null || length != null ? (width ?? this.width) * (length ?? this.length) : areaM2,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      width: width ?? this.width,
      length: length ?? this.length,
      soilType: soilType,
      sunlight: sunlight,
      moisture: moisture,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory Parcel.fromJson(Map<String, dynamic> json) {
    return Parcel(
      id: JsonUtils.toInt(json['id'])!,
      gardenId: JsonUtils.toInt(json['garden_id'])!,
      name: json['name'] as String,
      areaM2: JsonUtils.toDouble(json['area_m2']),
      posX: JsonUtils.toDouble(json['pos_x']) ?? 0,
      posY: JsonUtils.toDouble(json['pos_y']) ?? 0,
      width: JsonUtils.toDouble(json['width']) ?? 0,
      length: JsonUtils.toDouble(json['length']) ?? 0,
      soilType: json['soil_type'] as String? ?? 'standard',
      sunlight: json['sunlight'] as String? ?? 'medium',
      moisture: json['moisture'] as String? ?? 'medium',
      createdAt: JsonUtils.toDate(json['created_at']),
      updatedAt: JsonUtils.toDate(json['updated_at']),
    );
  }
}
