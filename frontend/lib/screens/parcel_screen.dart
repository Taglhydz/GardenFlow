import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../models/crop.dart';
import '../models/parcel.dart';
import '../models/plant.dart';
import '../models/suggestion.dart';
import '../providers/garden_providers.dart';
import '../providers/plant_providers.dart';
import '../widgets/crop_form_sheet.dart';
import '../widgets/parcel_form_sheet.dart';

/// A parcel : its characteristics, its crops and the plants suggested for it.
class ParcelScreen extends ConsumerWidget {
  const ParcelScreen({super.key, required this.gardenId, required this.parcelId});

  final int gardenId;
  final int parcelId;

  Future<void> _delete(BuildContext context, WidgetRef ref, Parcel parcel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_parcel'.tr()),
        content: Text('parcel_screen.delete_confirm'.tr(args: [parcel.name])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      await ref.read(parcelsProvider(gardenId).notifier).delete(parcel.id);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Parcel? parcel;
    for (final p in ref.watch(parcelsProvider(gardenId)).value ?? const <Parcel>[]) {
      if (p.id == parcelId) parcel = p;
    }

    // deleted parcel (or not loaded) : nothing to show
    if (parcel == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final current = parcel;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.primary,
          title: Text(current.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'edit_parcel'.tr(),
              onPressed: () => ParcelFormSheet.show(context, gardenId: gardenId, parcel: current),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'delete_parcel'.tr(),
              onPressed: () => _delete(context, ref, current),
            ),
          ],
          bottom: TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'parcel_screen.tab_crops'.tr()),
              Tab(text: 'parcel_screen.tab_suggestions'.tr()),
            ],
          ),
        ),
        body: Column(
          children: [
            _ParcelHeader(parcel: current),
            Expanded(
              child: TabBarView(
                children: [
                  _CropsTab(gardenId: gardenId, parcelId: parcelId),
                  _SuggestionsTab(gardenId: gardenId, parcelId: parcelId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppLocalizations.errorMessage(error)), backgroundColor: AppColors.error),
  );
}

String _formatDate(BuildContext context, DateTime date) => MaterialLocalizations.of(context).formatMediumDate(date);

// ======
// Header
// ======
class _ParcelHeader extends StatelessWidget {
  const _ParcelHeader({required this.parcel});

  final Parcel parcel;

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String text) => Chip(
          avatar: Icon(icon, size: 16, color: AppColors.primaryDark),
          label: Text(text, style: const TextStyle(fontSize: 12)),
          visualDensity: VisualDensity.compact,
          backgroundColor: AppColors.white,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          chip(Icons.straighten, AppLocalizations.dimensions(parcel.width, parcel.length)),
          if (parcel.areaM2 != null) chip(Icons.crop_square, '${NumberFormat('0.##').format(parcel.areaM2)} m²'),
          chip(Icons.landscape, AppLocalizations.getSoilTypeLabel(parcel.soilType)),
          chip(Icons.wb_sunny_outlined, '${'sunlight'.tr()} : ${AppLocalizations.getSunlightLabel(parcel.sunlight).toLowerCase()}'),
          chip(Icons.water_drop_outlined, '${'moisture'.tr()} : ${AppLocalizations.getMoistureLabel(parcel.moisture).toLowerCase()}'),
        ],
      ),
    );
  }
}

// =====
// Crops
// =====
enum _CropAction { harvest, edit, delete }

class _CropsTab extends ConsumerWidget {
  const _CropsTab({required this.gardenId, required this.parcelId});

  final int gardenId;
  final int parcelId;

  Future<void> _onAction(BuildContext context, WidgetRef ref, Crop crop, _CropAction action) async {
    final notifier = ref.read(gardenCropsProvider(gardenId).notifier);
    try {
      switch (action) {
        case _CropAction.harvest:
          await notifier.harvest(crop.id, DateUtils.dateOnly(DateTime.now()));
        case _CropAction.edit:
          await CropFormSheet.show(context, gardenId: gardenId, parcelId: parcelId, crop: crop);
        case _CropAction.delete:
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('delete_crop'.tr()),
              content: Text('parcel_screen.delete_crop_confirm'.tr()),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: Text('delete'.tr()),
                ),
              ],
            ),
          );
          if (confirm == true) await notifier.delete(crop.id);
      }
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cropsAsync = ref.watch(gardenCropsProvider(gardenId));
    final plantsById = ref.watch(plantsByIdProvider);

    if (!cropsAsync.hasValue) {
      return cropsAsync.hasError
          ? Center(child: Text(AppLocalizations.errorMessage(cropsAsync.error!)))
          : const Center(child: CircularProgressIndicator());
    }

    final crops = cropsAsync.value!.where((c) => c.parcelId == parcelId).toList();
    final inGround = crops.where((c) => c.isInGround).toList();
    final harvested = crops.where((c) => !c.isInGround).toList()
      ..sort((a, b) => b.actualHarvestDate!.compareTo(a.actualHarvestDate!));

    Widget tile(Crop crop) {
      final plant = plantsById[crop.plantId];
      final details = [
        if (crop.sowDate != null) 'parcel_screen.sown_on'.tr(args: [_formatDate(context, crop.sowDate!)]),
        if (crop.isInGround && crop.expectedHarvestDate != null)
          'parcel_screen.harvest_expected'.tr(args: [_formatDate(context, crop.expectedHarvestDate!)]),
        if (!crop.isInGround) 'parcel_screen.harvested_on'.tr(args: [_formatDate(context, crop.actualHarvestDate!)]),
        if (crop.comment != null) crop.comment!,
      ];

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(
            crop.isInGround ? Icons.eco : Icons.check_circle_outline,
            color: crop.isInGround ? AppColors.primary : AppColors.grey,
          ),
          title: Text(plant != null ? AppLocalizations.plantName(plant) : '…'),
          subtitle: details.isEmpty ? null : Text(details.join('\n')),
          trailing: PopupMenuButton<_CropAction>(
            onSelected: (action) => _onAction(context, ref, crop, action),
            itemBuilder: (context) => [
              if (crop.isInGround)
                PopupMenuItem(value: _CropAction.harvest, child: Text('parcel_screen.harvest_action'.tr())),
              PopupMenuItem(value: _CropAction.edit, child: Text('edit'.tr())),
              PopupMenuItem(
                value: _CropAction.delete,
                child: Text('delete'.tr(), style: const TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ),
      );
    }

    Widget sectionTitle(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(
          onPressed: () => CropFormSheet.show(context, gardenId: gardenId, parcelId: parcelId),
          icon: const Icon(Icons.add),
          label: Text('add_crop'.tr()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        if (crops.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Column(
              children: [
                Icon(Icons.eco_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('parcel_screen.no_crops'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('parcel_screen.no_crops_hint'.tr(), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        if (inGround.isNotEmpty) ...[
          sectionTitle('parcel_screen.in_ground'.tr()),
          ...inGround.map(tile),
        ],
        if (harvested.isNotEmpty) ...[
          sectionTitle('parcel_screen.harvested'.tr()),
          ...harvested.map(tile),
        ],
      ],
    );
  }
}

// ===========
// Suggestions
// ===========
class _SuggestionsTab extends ConsumerStatefulWidget {
  const _SuggestionsTab({required this.gardenId, required this.parcelId});

  final int gardenId;
  final int parcelId;

  @override
  ConsumerState<_SuggestionsTab> createState() => _SuggestionsTabState();
}

class _SuggestionsTabState extends ConsumerState<_SuggestionsTab> {
  int _month = DateTime.now().month;

  /// Sowing date proposed when planting a suggestion : today for the current month,
  /// otherwise the 1st of the chosen month (next year if the month is already passed).
  DateTime get _plantingDate {
    final now = DateTime.now();
    if (_month == now.month) return DateUtils.dateOnly(now);
    return DateTime(_month < now.month ? now.year + 1 : now.year, _month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final key = (parcelId: widget.parcelId, month: _month);
    final suggestionsAsync = ref.watch(suggestionsProvider(key));
    final plants = ref.watch(plantsProvider).value ?? const <Plant>[];
    final plantsById = {for (final p in plants) p.id: p};
    final plantsByCode = {for (final p in plants) p.code: p};

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Text('suggestions.month'.tr()),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _month,
                items: [
                  for (final m in AppLocalizations.months)
                    DropdownMenuItem(value: m['value'] as int, child: Text(m['label'] as String)),
                ],
                onChanged: (value) => value != null ? setState(() => _month = value) : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(suggestionsProvider(key).future),
            child: suggestionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                children: [
                  const SizedBox(height: 64),
                  Center(child: Text('suggestions.load_error'.tr())),
                  Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(suggestionsProvider(key)),
                      child: Text('retry'.tr()),
                    ),
                  ),
                ],
              ),
              data: (result) {
                if (result.suggestions.isEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 64),
                      Center(child: Text('suggestions.empty'.tr(), textAlign: TextAlign.center)),
                    ],
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: result.suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = result.suggestions[index];
                    return _SuggestionCard(
                      suggestion: suggestion,
                      plant: plantsById[suggestion.plantId],
                      plantsByCode: plantsByCode,
                      onPlant: () => CropFormSheet.show(
                        context,
                        gardenId: widget.gardenId,
                        parcelId: widget.parcelId,
                        plant: plantsById[suggestion.plantId],
                        sowDate: _plantingDate,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.plant,
    required this.plantsByCode,
    required this.onPlant,
  });

  final Suggestion suggestion;
  final Plant? plant;
  final Map<String, Plant> plantsByCode;
  final VoidCallback onPlant;

  Color get _scoreColor {
    if (suggestion.score >= 70) return AppColors.success;
    if (suggestion.score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final name = plant != null ? AppLocalizations.plantName(plant!) : suggestion.plantCode;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // score
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _scoreColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Text(
                    '${suggestion.score}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: _scoreColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Wrap(
                        spacing: 4,
                        children: [
                          for (final action in suggestion.actions)
                            Text(
                              AppLocalizations.getPeriodLabel(action),
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (suggestion.canGoInGroundNow)
                  TextButton.icon(
                    onPressed: onPlant,
                    icon: const Icon(Icons.add),
                    label: Text('suggestions.plant_action'.tr()),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final reason in suggestion.reasons)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      reason.isPositive ? Icons.check : (reason.isNegative ? Icons.close : Icons.info_outline),
                      size: 16,
                      color: reason.isPositive ? AppColors.success : (reason.isNegative ? AppColors.error : AppColors.info),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        AppLocalizations.suggestionReason(reason, plantsByCode),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
