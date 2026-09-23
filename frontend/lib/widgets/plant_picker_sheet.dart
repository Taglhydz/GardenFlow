import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../models/plant.dart';
import '../providers/plant_providers.dart';

/// Searchable list of the catalog. Returns the chosen plant, or null.
///   final plant = await PlantPickerSheet.show(context);
class PlantPickerSheet extends ConsumerStatefulWidget {
  const PlantPickerSheet({super.key});

  static Future<Plant?> show(BuildContext context) {
    return showModalBottomSheet<Plant>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FractionallySizedBox(heightFactor: 0.85, child: PlantPickerSheet()),
    );
  }

  @override
  ConsumerState<PlantPickerSheet> createState() => _PlantPickerSheetState();
}

class _PlantPickerSheetState extends ConsumerState<PlantPickerSheet> {
  String _search = '';

  /// The translated name, the French name of the database and the code are searched.
  bool _matches(Plant plant) {
    if (_search.isEmpty) return true;
    final query = _search.toLowerCase();
    return AppLocalizations.plantName(plant).toLowerCase().contains(query) ||
        plant.name.toLowerCase().contains(query) ||
        plant.code.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final plantsAsync = ref.watch(plantsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'crop_form.search_plant'.tr(),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _search = value.trim()),
          ),
        ),
        Expanded(
          child: plantsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(AppLocalizations.errorMessage(e))),
            data: (plants) {
              final filtered = plants.where(_matches).toList()
                ..sort((a, b) => AppLocalizations.plantName(a).compareTo(AppLocalizations.plantName(b)));

              if (filtered.isEmpty) return Center(child: Text('no_data'.tr()));

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final plant = filtered[index];
                  return ListTile(
                    leading: const Icon(Icons.eco, color: AppColors.primary),
                    title: Text(AppLocalizations.plantName(plant)),
                    subtitle: Text(AppLocalizations.getPlantTypeLabel(plant.type)),
                    onTap: () => Navigator.pop(context, plant),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
