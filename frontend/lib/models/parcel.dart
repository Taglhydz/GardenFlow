class Parcel {
  final int? id;
  final int gardenId;
  final String name;
  final double? areaM2;
  final double? posX;
  final double? posY;
  final double? width;
  final double? length;
  final String soilType;
  final String sunlight;
  final String moisture;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Parcel({
    this.id,
    required this.gardenId,
    required this.name,
    this.areaM2,
    this.posX,
    this.posY,
    this.width,
    this.length,
    this.soilType = 'standard',
    this.sunlight = 'medium',
    this.moisture = 'medium',
    this.createdAt,
    this.updatedAt,
  });

  factory Parcel.fromJson(Map<String, dynamic> json) {
    return Parcel(
      id: json['id'],
      gardenId: json['garden_id'],
      name: json['name'],
      areaM2: json['area_m2']?.toDouble(),
      posX: json['pos_x']?.toDouble(),
      posY: json['pos_y']?.toDouble(),
      width: json['width']?.toDouble(),
      length: json['length']?.toDouble(),
      soilType: json['soil_type'] ?? 'standard',
      sunlight: json['sunlight'] ?? 'medium',
      moisture: json['moisture'] ?? 'medium',
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
      'garden_id': gardenId,
      'name': name,
      'area_m2': areaM2,
      'pos_x': posX,
      'pos_y': posY,
      'width': width,
      'length': length,
      'soil_type': soilType,
      'sunlight': sunlight,
      'moisture': moisture,
    };
  }
}
