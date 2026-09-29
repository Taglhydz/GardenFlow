import 'json_utils.dart';

/// Level of the gardener (GET /users/me/level) : it proves their seniority and their mastery of the garden.
/// Computed by the server from the account age and the crops ; [rank] is translated with `level.ranks.RANK`.
class GardenerLevel {
  const GardenerLevel({
    required this.rank,
    required this.points,
    required this.rankMin,
    this.nextRank,
    this.nextRankMin,
    this.planted = 0,
    this.harvested = 0,
    this.plants = 0,
    this.seasons = 0,
    this.accountDays = 0,
  });

  /// Ranks from the lowest, like the server (services/levelService.js)
  static const ranks = ['seed', 'sprout', 'seedling', 'gardener', 'skilled_gardener', 'master_gardener'];

  final String rank;
  final int points;

  /// Points where the current rank starts
  final int rankMin;

  /// Null at the top rank
  final String? nextRank;
  final int? nextRankMin;

  // what the points come from
  final int planted;
  final int harvested;
  final int plants;
  final int seasons;
  final int accountDays;

  bool get isTopRank => nextRank == null;

  /// Progress to the next rank, 0 -> 1 (1 at the top rank)
  double get progress {
    final next = nextRankMin;
    if (next == null || next <= rankMin) return 1;
    return ((points - rankMin) / (next - rankMin)).clamp(0.0, 1.0);
  }

  /// Points still needed for the next rank (0 at the top rank)
  int get pointsToNext => nextRankMin == null ? 0 : (nextRankMin! - points).clamp(0, nextRankMin!);

  /// 0 for the first rank : its badge gets bigger with it
  int get rankIndex => ranks.indexOf(rank).clamp(0, ranks.length - 1);

  factory GardenerLevel.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? const {};
    return GardenerLevel(
      rank: json['rank'] as String,
      points: JsonUtils.toInt(json['points']) ?? 0,
      rankMin: JsonUtils.toInt(json['rank_min']) ?? 0,
      nextRank: json['next_rank'] as String?,
      nextRankMin: JsonUtils.toInt(json['next_rank_min']),
      planted: JsonUtils.toInt(stats['planted']) ?? 0,
      harvested: JsonUtils.toInt(stats['harvested']) ?? 0,
      plants: JsonUtils.toInt(stats['plants']) ?? 0,
      seasons: JsonUtils.toInt(stats['seasons']) ?? 0,
      accountDays: JsonUtils.toInt(stats['account_days']) ?? 0,
    );
  }
}
