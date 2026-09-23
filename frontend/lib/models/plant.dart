import 'json_utils.dart';

/// Period of the plant calendar.
/// type : sow_indoor (under cover), sow_outdoor (in the ground), plant_out, harvest.
/// Ranges may wrap around the year (10 -> 3 = October to March).
class PlantPeriod {
  final String type;
  final int startMonth;
  final int endMonth;

  const PlantPeriod({required this.type, required this.startMonth, required this.endMonth});

  static const sowIndoor  = 'sow_indoor';
  static const sowOutdoor = 'sow_outdoor';
  static const plantOut   = 'plant_out';
  static const harvest    = 'harvest';

  bool contains(int month) => Plant.isMonthInRange(month, startMonth, endMonth);

  factory PlantPeriod.fromJson(Map<String, dynamic> json) {
    return PlantPeriod(
      type: json['type'] as String,
      startMonth: JsonUtils.toInt(json['start_month'])!,
      endMonth: JsonUtils.toInt(json['end_month'])!,
    );
  }
}

/// Plant of the reference catalog.
/// `name` and `description` come from the database in French : use
/// AppLocalizations.plantName / plantDescription to display them in the user's language.
class Plant {
  final int id;
  final String code;
  final String name;
  final String type;
  final String? family;
  final String? description;
  final int? daysToMaturity;
  final String sunlightNeed;
  final String waterNeed;
  final String preferredSoil;
  final int spacingCm;
  final List<PlantPeriod> periods;

  const Plant({
    required this.id,
    required this.code,
    required this.name,
    this.type = 'vegetable',
    this.family,
    this.description,
    this.daysToMaturity,
    this.sunlightNeed = 'medium',
    this.waterNeed = 'medium',
    this.preferredSoil = 'standard',
    this.spacingCm = 20,
    this.periods = const [],
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: JsonUtils.toInt(json['id'])!,
      code: json['code'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'vegetable',
      family: json['family'] as String?,
      description: json['description'] as String?,
      daysToMaturity: JsonUtils.toInt(json['days_to_maturity']),
      sunlightNeed: json['sunlight_need'] as String? ?? 'medium',
      waterNeed: json['water_need'] as String? ?? 'medium',
      preferredSoil: json['preferred_soil'] as String? ?? 'standard',
      spacingCm: JsonUtils.toInt(json['spacing_cm']) ?? 20,
      periods: (json['periods'] as List? ?? [])
          .map((p) => PlantPeriod.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Month ranges may wrap around the year (10 -> 3 = October to March).
  static bool isMonthInRange(int month, int start, int end) {
    return start <= end ? month >= start && month <= end : month >= start || month <= end;
  }

  List<PlantPeriod> periodsOf(String type) => periods.where((p) => p.type == type).toList();

  bool isInPeriod(String type, int month) => periods.any((p) => p.type == type && p.contains(month));

  /// Can be sown in the ground or planted out this month.
  bool canGoInGroundIn(int month) => isInPeriod(PlantPeriod.sowOutdoor, month) || isInPeriod(PlantPeriod.plantOut, month);

  bool canBeHarvestedIn(int month) => isInPeriod(PlantPeriod.harvest, month);

  /// Expected first harvest for a crop sown / planted on [date].
  DateTime? expectedHarvestFrom(DateTime date) {
    if (daysToMaturity == null) return null;
    return DateTime(date.year, date.month, date.day + daysToMaturity!);
  }
}
