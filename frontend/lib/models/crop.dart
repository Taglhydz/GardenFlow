import 'json_utils.dart';

class Crop {
  final int id;
  final int parcelId;

  /// Zone of the parcel, null = the whole parcel
  final int? zoneId;
  final int plantId;
  final DateTime? sowDate;
  final DateTime? expectedHarvestDate;
  final DateTime? actualHarvestDate;
  final String? comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Crop({
    required this.id,
    required this.parcelId,
    this.zoneId,
    required this.plantId,
    this.sowDate,
    this.expectedHarvestDate,
    this.actualHarvestDate,
    this.comment,
    this.createdAt,
    this.updatedAt,
  });

  /// Not harvested yet (planned crops included).
  bool get isInGround => actualHarvestDate == null;

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      id: JsonUtils.toInt(json['id'])!,
      parcelId: JsonUtils.toInt(json['parcel_id'])!,
      zoneId: JsonUtils.toInt(json['zone_id']),
      plantId: JsonUtils.toInt(json['plant_id'])!,
      sowDate: JsonUtils.toDate(json['sow_date']),
      expectedHarvestDate: JsonUtils.toDate(json['expected_harvest_date']),
      actualHarvestDate: JsonUtils.toDate(json['actual_harvest_date']),
      comment: json['comment'] as String?,
      createdAt: JsonUtils.toDate(json['created_at']),
      updatedAt: JsonUtils.toDate(json['updated_at']),
    );
  }
}
