import 'json_utils.dart';

/// Plant of the reference catalog.
/// `name` and `description` come from the database in French : use
/// AppLocalizations.plantName / plantDescription to display them in the user's language.
class Plant {
  final int id;
  final String code;
  final String name;
  final String type;
  final String? description;
  final int? sowStartMonth;
  final int? sowEndMonth;
  final int? harvestStartMonth;
  final int? harvestEndMonth;
  final String sunlightNeed;
  final String waterNeed;
  final String preferredSoil;
  final int spacingCm;

  const Plant({
    required this.id,
    required this.code,
    required this.name,
    this.type = 'vegetable',
    this.description,
    this.sowStartMonth,
    this.sowEndMonth,
    this.harvestStartMonth,
    this.harvestEndMonth,
    this.sunlightNeed = 'medium',
    this.waterNeed = 'medium',
    this.preferredSoil = 'standard',
    this.spacingCm = 20,
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: JsonUtils.toInt(json['id'])!,
      code: json['code'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'vegetable',
      description: json['description'] as String?,
      sowStartMonth: JsonUtils.toInt(json['sow_start_month']),
      sowEndMonth: JsonUtils.toInt(json['sow_end_month']),
      harvestStartMonth: JsonUtils.toInt(json['harvest_start_month']),
      harvestEndMonth: JsonUtils.toInt(json['harvest_end_month']),
      sunlightNeed: json['sunlight_need'] as String? ?? 'medium',
      waterNeed: json['water_need'] as String? ?? 'medium',
      preferredSoil: json['preferred_soil'] as String? ?? 'standard',
      spacingCm: JsonUtils.toInt(json['spacing_cm']) ?? 20,
    );
  }

  /// Month ranges may wrap around the year (10 -> 3 = October to March).
  static bool isMonthInRange(int month, int? start, int? end) {
    if (start == null || end == null) return false;
    return start <= end ? month >= start && month <= end : month >= start || month <= end;
  }

  bool canBeSownIn(int month) => isMonthInRange(month, sowStartMonth, sowEndMonth);

  bool canBeHarvestedIn(int month) => isMonthInRange(month, harvestStartMonth, harvestEndMonth);
}
