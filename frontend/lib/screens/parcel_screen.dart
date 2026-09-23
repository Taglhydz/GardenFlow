import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../models/crop.dart';
import '../models/parcel.dart';
import '../models/zone.dart';
import '../providers/garden_providers.dart';
import '../providers/plant_providers.dart';
import '../utils/geometry.dart';
import '../utils/plan_geometry.dart';
import '../widgets/drawing_bar.dart';
import '../widgets/parcel_form_sheet.dart';
import '../widgets/shape_canvas.dart';
import 'garden_view.dart' show soilColor;
import 'zone_screen.dart';

enum _ParcelAction { wholeParcel, delete }

/// Zoom on a parcel : its zones are drawn with the finger, a zone is opened to plant in it.
/// Coordinates are relative to the parcel position (like the parcel and zone shapes).
class ParcelScreen extends ConsumerStatefulWidget {
  const ParcelScreen({super.key, required this.gardenId, required this.parcelId});

  final int gardenId;
  final int parcelId;

  @override
  ConsumerState<ParcelScreen> createState() => _ParcelScreenState();
}

class _ParcelScreenState extends ConsumerState<ParcelScreen> {
  int? _selectedZoneId;

  /// Points of the zone being drawn (null = not drawing)
  List<Offset>? _draft;
  bool _isSaving = false;

  int get _gardenId => widget.gardenId;

  Parcel? get _parcel {
    for (final p in ref.read(parcelsProvider(_gardenId)).value ?? const <Parcel>[]) {
      if (p.id == widget.parcelId) return p;
    }
    return null;
  }

  List<Zone> get _zones =>
      (ref.read(zonesProvider(_gardenId)).value ?? const <Zone>[]).where((z) => z.parcelId == widget.parcelId).toList();

  void _showError(Object error) {
    if (!mounted) return;
    // the new message replaces the current one instead of waiting behind it
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error is String ? error : AppLocalizations.errorMessage(error)),
          backgroundColor: AppColors.error,
        ),
      );
  }

  /// Same rules as the server : a valid shape, inside the parcel, not overlapping another zone.
  String? _zoneShapeError(List<Offset> shape, {int? zoneId}) {
    final parcel = _parcel;
    if (parcel == null) return null;
    if (!PlanGeometry.isValidShape(shape)) return 'garden_view.invalid_shape'.tr();
    if (!Geometry.isInside(shape, parcel.shape)) return 'errors.ZONE_OUTSIDE_PARCEL'.tr();
    if (_zones.any((z) => z.id != zoneId && Geometry.overlap(shape, z.shape))) return 'errors.ZONES_OVERLAP'.tr();
    return null;
  }

  // =======
  // Drawing
  // =======
  void _startDrawing() => setState(() {
    _draft = [];
    _selectedZoneId = null;
  });

  Future<void> _finishDrawing() async {
    final points = _draft;
    if (points == null || _isSaving) return;

    final error = _zoneShapeError(points);
    if (error != null) {
      _showError(error);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final zone = await ref
          .read(zonesProvider(_gardenId).notifier)
          .create(widget.parcelId, name: PlanGeometry.nextName('zone'.tr(), _zones.map((z) => z.name)), shape: points);
      if (mounted) {
        setState(() {
          _draft = null;
          _selectedZoneId = zone.id;
        });
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // =======
  // Editing
  // =======
  Future<void> _reshapeZone(int id, List<Offset> shape) async {
    final zone = _zones.where((z) => z.id == id).firstOrNull;
    if (zone == null) return;

    final error = _zoneShapeError(shape, zoneId: id);
    if (error != null) {
      _showError(error);
      return;
    }
    try {
      await ref.read(zonesProvider(_gardenId).notifier).reshape(zone, shape);
    } catch (e) {
      _showError(e);
    }
  }

  void _openZone(int? zoneId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ZoneScreen(gardenId: _gardenId, parcelId: widget.parcelId, zoneId: zoneId),
      ),
    );
  }

  Future<void> _renameZone(Zone zone) async {
    final controller = TextEditingController(text: zone.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('parcel_screen.rename_zone'.tr()),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          decoration: InputDecoration(labelText: 'parcel_screen.zone_name'.tr(), border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text('save'.tr())),
        ],
      ),
    );
    controller.dispose();

    if (name == null || name.isEmpty || name == zone.name) return;
    try {
      await ref.read(zonesProvider(_gardenId).notifier).rename(zone.id, name);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteZone(Zone zone) async {
    final confirm = await _confirm(
      'parcel_screen.delete_zone'.tr(),
      'parcel_screen.delete_zone_confirm'.tr(args: [zone.name]),
    );
    if (!confirm) return;
    try {
      await ref.read(zonesProvider(_gardenId).notifier).delete(zone.id);
      if (mounted) setState(() => _selectedZoneId = null);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _onParcelAction(_ParcelAction action, Parcel parcel) async {
    switch (action) {
      case _ParcelAction.wholeParcel:
        _openZone(null);
      case _ParcelAction.delete:
        final confirm = await _confirm('delete_parcel'.tr(), 'parcel_screen.delete_confirm'.tr(args: [parcel.name]));
        if (!confirm) return;
        try {
          await ref.read(parcelsProvider(_gardenId).notifier).delete(parcel.id);
          if (mounted) Navigator.pop(context);
        } catch (e) {
          _showError(e);
        }
    }
  }

  Future<bool> _confirm(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
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
    return result ?? false;
  }

  // ====
  // View
  // ====
  @override
  Widget build(BuildContext context) {
    Parcel? parcel;
    for (final p in ref.watch(parcelsProvider(_gardenId)).value ?? const <Parcel>[]) {
      if (p.id == widget.parcelId) parcel = p;
    }
    // deleted parcel (or not loaded) : nothing to show
    if (parcel == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final current = parcel;

    final zones = (ref.watch(zonesProvider(_gardenId)).value ?? const <Zone>[])
        .where((z) => z.parcelId == current.id)
        .toList();
    final crops = ref.watch(gardenCropsProvider(_gardenId)).value ?? const <Crop>[];
    final plantsById = ref.watch(plantsByIdProvider);

    List<String> plantsIn(Zone zone) => [
      for (final crop in crops)
        if (crop.zoneId == zone.id && crop.isInGround && plantsById[crop.plantId] != null)
          AppLocalizations.plantName(plantsById[crop.plantId]!),
    ];

    Zone? selected;
    for (final z in zones) {
      if (z.id == _selectedZoneId) selected = z;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(current.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '${AppLocalizations.area(current.areaM2)} · ${AppLocalizations.getSoilTypeLabel(current.soilType)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'edit_parcel'.tr(),
            onPressed: () => ParcelFormSheet.show(context, gardenId: _gardenId, parcel: current),
          ),
          PopupMenuButton<_ParcelAction>(
            onSelected: (action) => _onParcelAction(action, current),
            itemBuilder: (context) => [
              PopupMenuItem(value: _ParcelAction.wholeParcel, child: Text('zone_screen.whole_parcel'.tr())),
              PopupMenuItem(
                value: _ParcelAction.delete,
                child: Text('delete_parcel'.tr(), style: const TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _draft == null && selected == null
          ? FloatingActionButton.extended(
              onPressed: _startDrawing,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              icon: const Icon(Icons.draw_outlined),
              label: Text('parcel_screen.draw_zone'.tr()),
            )
          : null,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.primaryLight.withValues(alpha: 0.5),
            child: Text(
              _draft != null
                  ? 'parcel_screen.draw_hint'.tr()
                  : selected != null
                  ? 'parcel_screen.hint_selected'.tr()
                  : zones.isEmpty
                  ? 'parcel_screen.empty_hint'.tr()
                  : 'parcel_screen.hint'.tr(),
              style: const TextStyle(fontSize: 13, color: AppColors.primaryDark),
            ),
          ),
          Expanded(
            child: ShapeCanvas(
              world: PlanGeometry.parcelWorld(current.shape),
              background: [
                CanvasShape(
                  id: -1,
                  points: current.shape,
                  fill: soilColor(current.soilType),
                  border: AppColors.parcels,
                ),
              ],
              shapes: [
                for (final zone in zones)
                  CanvasShape(
                    id: zone.id,
                    points: zone.shape,
                    fill: AppColors.primaryLight.withValues(alpha: 0.75),
                    border: AppColors.primaryDark,
                    labels: [zone.name, ...plantsIn(zone)],
                  ),
              ],
              selectedId: selected?.id,
              draft: _draft,
              onDraftPoint: (point) => setState(() => _draft = [..._draft!, point]),
              onDraftClose: _finishDrawing,
              onSelect: (id) => setState(() => _selectedZoneId = id),
              onOpen: _openZone,
              onMoved: (id, delta) {
                final zone = zones.firstWhere((z) => z.id == id);
                _reshapeZone(id, Geometry.translate(zone.shape, delta));
              },
              onReshaped: _reshapeZone,
            ),
          ),
        ],
      ),
      // in the bottom bar of the Scaffold, error messages are shown above it instead of hiding it
      bottomNavigationBar: _draft != null
          ? DrawingBar(
              pointCount: _draft!.length,
              isSaving: _isSaving,
              onUndo: () => setState(() => _draft = [..._draft!]..removeLast()),
              onCancel: () => setState(() => _draft = null),
              onFinish: _finishDrawing,
            )
          : selected != null
          ? _buildSelectedBar(selected, plantsIn(selected))
          : null,
    );
  }

  Widget _buildSelectedBar(Zone zone, List<String> plants) {
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
                    Text(zone.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      [AppLocalizations.area(zone.areaM2), ...plants].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'parcel_screen.rename_zone'.tr(),
                onPressed: () => _renameZone(zone),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'parcel_screen.delete_zone'.tr(),
                onPressed: () => _deleteZone(zone),
              ),
              ElevatedButton(
                onPressed: () => _openZone(zone.id),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.white),
                child: Text('garden_view.open_parcel'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
