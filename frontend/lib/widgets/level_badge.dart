import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/gardener_level.dart';

/// Icon and color of each rank, from the seed to the master gardener.
class RankStyle {
  RankStyle._();

  static const _icons = [Icons.grain, Icons.eco, Icons.local_florist, Icons.yard, Icons.park, Icons.emoji_events];
  static const _colors = [
    Color(0xFF8D6E63), // seed : brown
    Color(0xFF9CCC65), // sprout : light green
    Color(0xFF66BB6A),
    Color(0xFF43A047),
    Color(0xFF2E7D32), // skilled gardener : dark green
    Color(0xFFF9A825), // master gardener : gold
  ];

  static IconData icon(GardenerLevel level) => _icons[level.rankIndex];
  static Color color(GardenerLevel level) => _colors[level.rankIndex];

  static String name(String rank) => 'level.ranks.$rank'.tr();
}

/// Rank of the gardener in a small pill (home page) : its icon, its name and the progress to the next rank.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level});

  final GardenerLevel level;

  @override
  Widget build(BuildContext context) {
    final color = RankStyle.color(level);

    return Tooltip(
      message: level.isTopRank
          ? 'level.top_rank'.tr()
          : 'level.points_to_next'.tr(args: ['${level.pointsToNext}', RankStyle.name(level.nextRank!)]),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(RankStyle.icon(level), size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              RankStyle.name(level.rank),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.greyDark),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: level.progress,
                  minHeight: 4,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Level of the gardener on the profile : rank, progress to the next one and where the points come from.
class LevelCard extends StatelessWidget {
  const LevelCard({super.key, required this.level});

  final GardenerLevel level;

  @override
  Widget build(BuildContext context) {
    final color = RankStyle.color(level);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('level.title'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(RankStyle.icon(level), color: color, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(RankStyle.name(level.rank), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        'level.points'.plural(level.points),
                        style: const TextStyle(color: AppColors.greyDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: level.progress,
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              level.isTopRank
                  ? 'level.top_rank'.tr()
                  : 'level.points_to_next'.tr(args: ['${level.pointsToNext}', RankStyle.name(level.nextRank!)]),
              style: const TextStyle(fontSize: 13, color: AppColors.greyDark),
            ),
            const Divider(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _stat(Icons.calendar_today, 'level.stats.days'.plural(level.accountDays)),
                _stat(Icons.grass, 'level.stats.planted'.plural(level.planted)),
                _stat(Icons.shopping_basket_outlined, 'level.stats.harvested'.plural(level.harvested)),
                _stat(Icons.local_florist_outlined, 'level.stats.plants'.plural(level.plants)),
                _stat(Icons.wb_sunny_outlined, 'level.stats.seasons'.plural(level.seasons)),
              ],
            ),
            const SizedBox(height: 12),
            Text('level.how'.tr(), style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
