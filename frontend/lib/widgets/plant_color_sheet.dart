import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../models/crop.dart';
import '../models/plant.dart';
import '../providers/garden_providers.dart';
import '../providers/plant_providers.dart';
import '../utils/plant_colors.dart';

/// Round sample of a plant color : its light shade inside, its dark shade around.
class PlantColorDot extends StatelessWidget {
  const PlantColorDot({super.key, required this.hue, this.size = 36, this.child});

  final double hue;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PlantColors.lightOf(hue),
        shape: BoxShape.circle,
        border: Border.all(color: PlantColors.darkOf(hue), width: 2),
      ),
      child: IconTheme(data: IconThemeData(color: PlantColors.darkOf(hue), size: size * 0.55), child: child ?? const SizedBox()),
    );
  }
}

/// Chooses the color of a plant on the plans (or back to its automatic color). The change is saved
/// right away ; a message tells when another plant of the garden [gardenId] has the same color.
///   PlantColorSheet.show(context, gardenId: gardenId, plant: plant);
class PlantColorSheet extends ConsumerWidget {
  const PlantColorSheet({super.key, required this.gardenId, required this.plant});

  final int gardenId;
  final Plant plant;

  static Future<void> show(BuildContext context, {required int gardenId, required Plant plant}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlantColorSheet(gardenId: gardenId, plant: plant),
    );
  }

  Future<void> _change(BuildContext context, Future<void> Function() change) async {
    try {
      await change();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.errorMessage(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(plantColorsProvider);
    final notifier = ref.read(plantHuesProvider.notifier);
    final hue = colors.hue(plant);
    final automatic = PlantColors.automaticHue(plant);

    // the plants growing in this garden : the ones that must be told apart on its plan
    final plantsById = ref.watch(plantsByIdProvider);
    final crops = ref.watch(gardenCropsProvider(gardenId)).value ?? const <Crop>[];
    final gardenPlants = {
      for (final c in crops)
        if (c.isInGround && plantsById[c.plantId] != null) plantsById[c.plantId]!,
    };
    final sameColor = colors.sameColorAs(plant, hue, gardenPlants);

    Widget choice({required double hue, required bool selected, required VoidCallback onTap, String? tooltip, Widget? icon}) {
      final dot = InkResponse(
        onTap: onTap,
        radius: 26,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? AppColors.black : Colors.transparent, width: 2),
          ),
          child: PlantColorDot(hue: hue, size: 40, child: selected ? const Icon(Icons.check) : icon),
        ),
      );
      return tooltip == null ? dot : Tooltip(message: tooltip, child: dot);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'plant_color.title'.tr(args: [AppLocalizations.plantName(plant)]),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('plant_color.hint'.tr(), style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              choice(
                hue: automatic,
                selected: !colors.isChosen(plant),
                tooltip: 'plant_color.automatic'.tr(),
                icon: const Icon(Icons.auto_awesome),
                onTap: () => _change(context, () => notifier.reset(plant.id)),
              ),
              for (final h in PlantColors.palette)
                choice(
                  hue: h.toDouble(),
                  selected: colors.isChosen(plant) && hue == h,
                  onTap: () => _change(context, () => notifier.choose(plant.id, h)),
                ),
            ],
          ),
          if (sameColor.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('plant_color.same_as'.tr(args: [sameColor.map(AppLocalizations.plantName).join(', ')])),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => Navigator.pop(context), child: Text('plant_color.done'.tr())),
          ),
        ],
      ),
    );
  }
}
