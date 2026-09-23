import 'dart:ui';
import 'json_utils.dart';

/// Parses a shape from the API : [{"x": 0, "y": 0}, ...] (meters).
List<Offset> shapeFromJson(dynamic json) => [
      for (final p in (json as List? ?? const []))
        Offset(JsonUtils.toDouble((p as Map)['x']) ?? 0, JsonUtils.toDouble(p['y']) ?? 0),
    ];

/// Shape for the API, rounded to the cm.
List<Map<String, double>> shapeToJson(List<Offset> shape) => [
      for (final p in shape) {'x': (p.dx * 100).round() / 100, 'y': (p.dy * 100).round() / 100},
    ];

/// Free shape (polygon) drawn on the garden plan, in meters.
/// [shape] is relative to ([posX], [posY]) : moving the parcel only changes the position,
/// and its zones (relative to the parcel) follow it.
class Parcel {
  final int id;
  final int gardenId;
  final String name;
  final double posX;
  final double posY;
  final List<Offset> shape;
  final double areaM2;
  final String soilType;
  final String sunlight;
  final String moisture;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Parcel({
    required this.id,
    required this.gardenId,
    required this.name,
    this.posX = 0,
    this.posY = 0,
    required this.shape,
    this.areaM2 = 0,
    this.soilType = 'standard',
    this.sunlight = 'medium',
    this.moisture = 'medium',
    this.createdAt,
    this.updatedAt,
  });

  Offset get position => Offset(posX, posY);

  /// Shape on the garden plan.
  List<Offset> get absoluteShape => [for (final p in shape) p + position];

  /// Used to show a move / an edit on the plan before the server answers.
  Parcel copyWith({Offset? position, List<Offset>? shape}) {
    return Parcel(
      id: id,
      gardenId: gardenId,
      name: name,
      posX: position?.dx ?? posX,
      posY: position?.dy ?? posY,
      shape: shape ?? this.shape,
      areaM2: areaM2,
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
      posX: JsonUtils.toDouble(json['pos_x']) ?? 0,
      posY: JsonUtils.toDouble(json['pos_y']) ?? 0,
      shape: shapeFromJson(json['shape']),
      areaM2: JsonUtils.toDouble(json['area_m2']) ?? 0,
      soilType: json['soil_type'] as String? ?? 'standard',
      sunlight: json['sunlight'] as String? ?? 'medium',
      moisture: json['moisture'] as String? ?? 'medium',
      createdAt: JsonUtils.toDate(json['created_at']),
      updatedAt: JsonUtils.toDate(json['updated_at']),
    );
  }
}
