import 'json_utils.dart';

/// Why a plant is suggested or not. `code` is translated with suggestion_reasons.<code>.
class SuggestionReason {
  final String code;

  /// positive, negative or info
  final String impact;
  final Map<String, dynamic> params;

  const SuggestionReason({required this.code, required this.impact, this.params = const {}});

  bool get isPositive => impact == 'positive';
  bool get isNegative => impact == 'negative';

  factory SuggestionReason.fromJson(Map<String, dynamic> json) {
    return SuggestionReason(
      code: json['code'] as String,
      impact: json['impact'] as String? ?? 'info',
      params: json['params'] is Map ? Map<String, dynamic>.from(json['params'] as Map) : const {},
    );
  }
}

/// A plant suggested for a parcel, computed by the server.
class Suggestion {
  final int plantId;
  final String plantCode;

  /// 0 - 100
  final int score;

  /// What can be done this month : sow_outdoor, plant_out, sow_indoor
  final List<String> actions;
  final List<SuggestionReason> reasons;

  const Suggestion({
    required this.plantId,
    required this.plantCode,
    required this.score,
    this.actions = const [],
    this.reasons = const [],
  });

  /// Can go in the parcel now (not only sown under cover).
  bool get canGoInGroundNow => actions.contains('sow_outdoor') || actions.contains('plant_out');

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      plantId: JsonUtils.toInt(json['plant_id'])!,
      plantCode: json['plant_code'] as String,
      score: JsonUtils.toInt(json['score']) ?? 0,
      actions: (json['actions'] as List? ?? []).cast<String>(),
      reasons: (json['reasons'] as List? ?? [])
          .map((r) => SuggestionReason.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList(),
    );
  }
}

class ParcelSuggestions {
  final int parcelId;
  final int month;
  final List<Suggestion> suggestions;

  const ParcelSuggestions({required this.parcelId, required this.month, required this.suggestions});

  factory ParcelSuggestions.fromJson(Map<String, dynamic> json) {
    return ParcelSuggestions(
      parcelId: JsonUtils.toInt(json['parcel_id'])!,
      month: JsonUtils.toInt(json['month'])!,
      suggestions: (json['suggestions'] as List)
          .map((s) => Suggestion.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }
}
