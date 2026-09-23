import 'dart:ui';
import 'json_utils.dart';
import 'parcel.dart';

/// Permanent delimitation drawn inside a parcel (a row, a bed, a corner...).
/// Crops are planted in it season after season, it keeps their history.
/// [shape] is relative to the parcel position, like the parcel shape.
class Zone {
  final int id;
  final int parcelId;
  final String name;
  final List<Offset> shape;
  final double areaM2;

  const Zone({
    required this.id,
    required this.parcelId,
    required this.name,
    required this.shape,
    this.areaM2 = 0,
  });

  /// Shape on the garden plan.
  List<Offset> absoluteShape(Parcel parcel) => [for (final p in shape) p + parcel.position];

  Zone copyWith({List<Offset>? shape}) =>
      Zone(id: id, parcelId: parcelId, name: name, shape: shape ?? this.shape, areaM2: areaM2);

  factory Zone.fromJson(Map<String, dynamic> json) {
    return Zone(
      id: JsonUtils.toInt(json['id'])!,
      parcelId: JsonUtils.toInt(json['parcel_id'])!,
      name: json['name'] as String,
      shape: shapeFromJson(json['shape']),
      areaM2: JsonUtils.toDouble(json['area_m2']) ?? 0,
    );
  }
}
