class Plant {
  final int? id;
  final String name;
  final String? type;
  final String? description;
  final int? sowStartMonth;
  final int? sowEndMonth;
  final int? harvestStartMonth;
  final int? harvestEndMonth;
  final String? sunlightNeed;
  final String? waterNeed;
  final String? preferredSoil;
  final int? spacingCm;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Plant({
    this.id,
    required this.name,
    this.type,
    this.description,
    this.sowStartMonth,
    this.sowEndMonth,
    this.harvestStartMonth,
    this.harvestEndMonth,
    this.sunlightNeed,
    this.waterNeed,
    this.preferredSoil,
    this.spacingCm,
    this.createdAt,
    this.updatedAt,
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      description: json['description'],
      sowStartMonth: json['sow_start_month'],
      sowEndMonth: json['sow_end_month'],
      harvestStartMonth: json['harvest_start_month'],
      harvestEndMonth: json['harvest_end_month'],
      sunlightNeed: json['sunlight_need'],
      waterNeed: json['water_need'],
      preferredSoil: json['preferred_soil'],
      spacingCm: json['spacing_cm'],
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
      'name': name,
      'type': type,
      'description': description,
      'sow_start_month': sowStartMonth,
      'sow_end_month': sowEndMonth,
      'harvest_start_month': harvestStartMonth,
      'harvest_end_month': harvestEndMonth,
      'sunlight_need': sunlightNeed,
      'water_need': waterNeed,
      'preferred_soil': preferredSoil,
      'spacing_cm': spacingCm,
    };
  }
}
