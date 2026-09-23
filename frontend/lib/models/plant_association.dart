import 'json_utils.dart';

/// Symmetric relation between two plants (the API stores plantId1 < plantId2).
class PlantAssociation {
  final int id;
  final int plantId1;
  final int plantId2;
  final String plantCode1;
  final String plantCode2;
  final String relationType;
  final String? comment;

  const PlantAssociation({
    required this.id,
    required this.plantId1,
    required this.plantId2,
    required this.plantCode1,
    required this.plantCode2,
    required this.relationType,
    this.comment,
  });

  bool get isPositive => relationType == 'positive';

  /// The other plant of the pair.
  int otherPlantId(int plantId) => plantId == plantId1 ? plantId2 : plantId1;

  /// Translation key of the comment : codes sorted alphabetically,
  /// e.g. plant_associations.basil__tomato
  String get translationKey {
    final codes = [plantCode1, plantCode2]..sort();
    return 'plant_associations.${codes[0]}__${codes[1]}';
  }

  factory PlantAssociation.fromJson(Map<String, dynamic> json) {
    return PlantAssociation(
      id: JsonUtils.toInt(json['id'])!,
      plantId1: JsonUtils.toInt(json['plant_id_1'])!,
      plantId2: JsonUtils.toInt(json['plant_id_2'])!,
      plantCode1: json['plant_code_1'] as String,
      plantCode2: json['plant_code_2'] as String,
      relationType: json['relation_type'] as String,
      comment: json['comment'] as String?,
    );
  }
}
