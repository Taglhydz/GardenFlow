import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../models/garden.dart';
import '../models/parcel.dart';
import '../models/plant.dart';
import '../providers/garden_providers.dart';
import '../providers/plant_providers.dart';
import '../widgets/garden_plan.dart';
import '../widgets/parcel_form_sheet.dart';
import 'parcel_screen.dart';

enum _GardenAction { rename, delete }

/// Opened garden : 2D plan of its parcels.
class GardenView extends ConsumerStatefulWidget {
  const GardenView({super.key, required this.garden, required this.onHome, required this.onProfile});

  final Garden garden;

  /// Back to the garden list
  final VoidCallback onHome;
  final VoidCallback onProfile;

  @override
  ConsumerState<GardenView> createState() => _GardenViewState();
}

class _GardenViewState extends ConsumerState<GardenView> {
  int? _selectedParcelId;

  int get _gardenId => widget.garden.id;

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.errorMessage(error)), backgroundColor: AppColors.error),
    );
  }

  Future<void> _addParcel() async {
    final parcel = await ParcelFormSheet.show(context, gardenId: _gardenId);
    // the new parcel is selected so it can be moved right away
    if (parcel != null && mounted) setState(() => _selectedParcelId = parcel.id);
  }

  Future<void> _editParcel(Parcel parcel) async {
    await ParcelFormSheet.show(context, gardenId: _gardenId, parcel: parcel);
  }

  void _openParcel(Parcel parcel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ParcelScreen(gardenId: _gardenId, parcelId: parcel.id)),
    );
  }

  Future<void> _onGeometryChanged(Parcel previous, Parcel updated) async {
    try {
      await ref.read(parcelsProvider(_gardenId).notifier).updateGeometry(previous, updated);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _onGardenAction(_GardenAction action) async {
    switch (action) {
      case _GardenAction.rename:
        await _renameGarden();
      case _GardenAction.delete:
        await _deleteGarden();
    }
  }

  Future<void> _renameGarden() async {
    final controller = TextEditingController(text: widget.garden.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('garden_view.rename_garden'.tr()),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          decoration: InputDecoration(labelText: 'garden_name'.tr(), border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text('save'.tr())),
        ],
      ),
    );
    controller.dispose();

    if (name == null || name.isEmpty || name == widget.garden.name) return;
    try {
      await ref.read(gardensProvider.notifier).updateGarden(_gardenId, name: name);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteGarden() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_garden'.tr()),
        content: Text('garden_view.delete_garden_confirm'.tr(args: [widget.garden.name])),
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
    if (confirm != true) return;

    try {
      // the home screen goes back to the garden list by itself
      await ref.read(gardensProvider.notifier).delete(_gardenId);
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcelsAsync = ref.watch(parcelsProvider(_gardenId));
    final crops = ref.watch(gardenCropsProvider(_gardenId)).value ?? const [];
    final plantsById = ref.watch(plantsByIdProvider);

    // plants in the ground, by parcel
    final plantsByParcel = <int, List<Plant>>{};
    for (final crop in crops.where((c) => c.isInGround)) {
      final plant = plantsById[crop.plantId];
      if (plant != null) plantsByParcel.putIfAbsent(crop.parcelId, () => []).add(plant);
    }

    final parcels = parcelsAsync.value ?? const <Parcel>[];
    Parcel? selected;
    for (final p in parcels) {
      if (p.id == _selectedParcelId) selected = p;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.home_outlined, size: 28),
          onPressed: widget.onHome,
          tooltip: 'my_gardens'.tr(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.garden.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (widget.garden.location != null)
              Text(widget.garden.location!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        actions: [
          PopupMenuButton<_GardenAction>(
            onSelected: _onGardenAction,
            itemBuilder: (context) => [
              PopupMenuItem(value: _GardenAction.rename, child: Text('garden_view.rename_garden'.tr())),
              PopupMenuItem(
                value: _GardenAction.delete,
                child: Text('delete_garden'.tr(), style: const TextStyle(color: AppColors.error)),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: widget.onProfile,
            tooltip: 'profile.title'.tr(),
          ),
        ],
      ),
      floatingActionButton: parcelsAsync.hasValue && selected == null
          ? FloatingActionButton.extended(
              onPressed: _addParcel,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              icon: const Icon(Icons.add),
              label: Text('add_parcel'.tr()),
            )
          : null,
      body: !parcelsAsync.hasValue
          ? (parcelsAsync.hasError ? _buildError() : const Center(child: CircularProgressIndicator()))
          : parcels.isEmpty
              ? _buildEmpty()
              : Column(
                  children: [
                    _buildHint(selected != null),
                    Expanded(
                      child: GardenPlan(
                        parcels: parcels,
                        plantsByParcel: plantsByParcel,
                        selectedId: selected?.id,
                        onSelect: (id) => setState(() => _selectedParcelId = id),
                        onOpen: _openParcel,
                        onGeometryChanged: _onGeometryChanged,
                      ),
                    ),
                    if (selected != null) _buildSelectedBar(selected),
                  ],
                ),
    );
  }

  Widget _buildHint(bool hasSelection) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primaryLight.withValues(alpha: 0.5),
      child: Row(
        children: [
          const Icon(Icons.touch_app, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasSelection ? 'garden_view.hint_selected'.tr() : 'garden_view.hint'.tr(),
              style: const TextStyle(fontSize: 13, color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedBar(Parcel parcel) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(parcel.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      '${AppLocalizations.dimensions(parcel.width, parcel.length)} · ${AppLocalizations.getSoilTypeLabel(parcel.soilType)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'edit_parcel'.tr(),
                onPressed: () => _editParcel(parcel),
              ),
              ElevatedButton(
                onPressed: () => _openParcel(parcel),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.white),
                child: Text('garden_view.open_parcel'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'garden_view.empty_title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'garden_view.empty_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('garden_view.load_error'.tr()),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(parcelsProvider(_gardenId)),
            icon: const Icon(Icons.refresh),
            label: Text('retry'.tr()),
          ),
        ],
      ),
    );
  }
}
