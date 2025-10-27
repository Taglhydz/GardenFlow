class Crop {
  final int? id;
  final int parcelId;
  final int plantId;
  final DateTime? sowDate;
  final DateTime? expectedHarvestDate;
  final DateTime? actualHarvestDate;
  final String? comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Crop({
    this.id,
    required this.parcelId,
    required this.plantId,
    this.sowDate,
    this.expectedHarvestDate,
    this.actualHarvestDate,
    this.comment,
    this.createdAt,
    this.updatedAt,
  });

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      id: json['id'],
      parcelId: json['parcel_id'],
      plantId: json['plant_id'],
      sowDate: json['sow_date'] != null 
          ? DateTime.parse(json['sow_date']) 
          : null,
      expectedHarvestDate: json['expected_harvest_date'] != null 
          ? DateTime.parse(json['expected_harvest_date']) 
          : null,
      actualHarvestDate: json['actual_harvest_date'] != null 
          ? DateTime.parse(json['actual_harvest_date']) 
          : null,
      comment: json['comment'],
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
      'parcel_id': parcelId,
      'plant_id': plantId,
      'sow_date': sowDate?.toIso8601String(),
      'expected_harvest_date': expectedHarvestDate?.toIso8601String(),
      'actual_harvest_date': actualHarvestDate?.toIso8601String(),
      'comment': comment,
    };
  }
}
