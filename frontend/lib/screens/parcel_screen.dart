import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../models/crop.dart';
import '../models/parcel.dart';
import '../models/plant.dart';
import '../models/zone.dart';
import '../providers/garden_providers.dart';
import '../providers/plant_providers.dart';
import '../providers/snap_provider.dart';
import '../utils/geometry.dart';
import '../utils/plan_geometry.dart';
import '../utils/plant_colors.dart';
import '../utils/zone_names.dart';
import '../widgets/dimensions_sheet.dart';
import '../widgets/drawing_bar.dart';
import '../widgets/help_banner.dart';
import '../widgets/parcel_form_sheet.dart';
import '../widgets/rename_dialog.dart';
import '../widgets/shape_canvas.dart';
import '../widgets/snap_button.dart';
import 'garden_view.dart' show editParcelDimensions, soilColor;
import 'zone_screen.dart';

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

  /// Name shown for the zone : given by the user, or automatic from its plants
  String _nameOf(Zone zone) =>
      ZoneNames.of(_zones, ref.read(gardenCropsProvider(_gardenId)).value ?? const [], ref.read(plantsByIdProvider))[zone.id] ?? '';

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
          .create(widget.parcelId, shape: points); // automatic name : "Add a plant" until a plant goes in
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

  Future<void> _editZoneDimensions(Zone zone) async {
    final result = await DimensionsSheet.show(
      context,
      title: 'dimensions.title_of'.tr(args: [_nameOf(zone)]),
      shape: zone.shape,
      positionLabel: 'dimensions.position_in_parcel'.tr(),
      validate: (result) => _zoneShapeError(result.finalShape, zoneId: zone.id),
    );
    if (result == null) return;
    await _reshapeZone(zone.id, [for (final p in result.finalShape) PlanGeometry.roundCm(p)]);
  }

  Future<void> _editParcelDimensions(Parcel parcel) async {
    try {
      await editParcelDimensions(context, ref, parcel);
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

  /// A name typed by the user is kept as it is ; an empty name brings the automatic one back.
  Future<void> _renameZone(Zone zone) async {
    final shown = _nameOf(zone);
    final name = await showRenameDialog(
      context,
      title: 'parcel_screen.rename_zone'.tr(),
      label: 'parcel_screen.zone_name'.tr(),
      helper: 'parcel_screen.zone_name_helper'.tr(),
      name: shown,
    );

    // cancelled, or not changed (an automatic name stays automatic)
    if (name == null || name == shown || (name.isEmpty && zone.name == null)) return;
    try {
      await ref.read(zonesProvider(_gardenId).notifier).rename(zone.id, name.isEmpty ? null : name);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteZone(Zone zone) async {
    final confirm = await _confirm(
      'parcel_screen.delete_zone'.tr(),
      'parcel_screen.delete_zone_confirm'.tr(args: [_nameOf(zone)]),
    );
    if (!confirm) return;
    try {
      await ref.read(zonesProvider(_gardenId).notifier).delete(zone.id);
      if (mounted) setState(() => _selectedZoneId = null);
    } catch (e) {
      _showError(e);
    }
  }

  /// After a confirmation : the parcel, its zones and its crops are deleted, back to the garden plan.
  Future<void> _deleteParcel(Parcel parcel) async {
    final confirm = await _confirm('delete_parcel'.tr(), 'parcel_screen.delete_confirm'.tr(args: [parcel.name]));
    if (!confirm) return;
    try {
      await ref.read(parcelsProvider(_gardenId).notifier).delete(parcel.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError(e);
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
    final plantColors = ref.watch(plantColorsProvider);

    List<Plant> plantsIn(Zone zone) => ZoneNames.plantsIn(zone.id, crops, plantsById);
    final names = ZoneNames.of(zones, crops, plantsById);

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
            icon: const Icon(Icons.straighten),
            tooltip: 'dimensions.of_parcel'.tr(),
            onPressed: () => _editParcelDimensions(current),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'edit_parcel'.tr(),
            onPressed: () => ParcelFormSheet.show(context, gardenId: _gardenId, parcel: current),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'delete_parcel'.tr(),
            onPressed: () => _deleteParcel(current),
          ),
        ],
      ),
      // all the plants of the parcel at the bottom left, draw a zone at the bottom right
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _draft == null && selected == null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'all_plants',
                    onPressed: () => _openZone(null),
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    icon: const Icon(Icons.local_florist_outlined),
                    label: Text('zone_screen.whole_parcel'.tr()),
                  ),
                  FloatingActionButton.extended(
                    heroTag: 'draw_zone',
                    onPressed: _startDrawing,
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    icon: const Icon(Icons.draw_outlined),
                    label: Text('parcel_screen.draw_zone'.tr()),
                  ),
                ],
              ),
            )
          : null,
      body: Column(
        children: [
          HelpBanner(
            screen: 'parcel',
            text: _draft != null
                ? 'parcel_screen.draw_hint'.tr()
                : selected != null
                ? 'parcel_screen.hint_selected'.tr()
                : zones.isEmpty
                ? 'parcel_screen.empty_hint'.tr()
                : 'parcel_screen.hint'.tr(),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ShapeCanvas(
                    snapCm: ref.watch(snapProvider).effectiveCm,
                    world: PlanGeometry.parcelWorld(current.shape),
                    // plain infinite grid : the meters are given by the lengths of the sides
                    rulers: false,
                    // the corners of the zones stay in the parcel and stick to its sides
                    area: current.shape,
                    background: [
                      CanvasShape(
                        id: -1,
                        points: current.shape,
                        fill: soilColor(current.soilType),
                        border: AppColors.parcels,
                      ),
                    ],
                    shapes: [
                      for (final zone in zones) _zoneShape(zone, names[zone.id] ?? '', plantsIn(zone), plantColors),
                    ],
                    selectedId: selected?.id,
                    draft: _draft,
                    onDraftPoint: (point) => setState(() => _draft = [..._draft!, point]),
                    onDraftClose: _finishDrawing,
                    onDraftRefused: (refusal) => _showError(
                      refusal == DraftRefusal.outside
                          ? 'parcel_screen.point_outside'.tr()
                          : 'parcel_screen.point_on_zone'.tr(),
                    ),
                    onSelect: (id) => setState(() => _selectedZoneId = id),
                    onOpen: _openZone,
                    onMoved: (id, delta) {
                      final zone = zones.firstWhere((z) => z.id == id);
                      _reshapeZone(id, Geometry.translate(zone.shape, delta));
                    },
                    onReshaped: _reshapeZone,
                  ),
                ),
                const Positioned(top: 8, right: 8, child: SnapButton()),
                const Positioned(top: 8, left: 8, child: HelpButton(screen: 'parcel')),
              ],
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
          ? _buildSelectedBar(selected, names[selected.id] ?? '', [for (final p in plantsIn(selected)) AppLocalizations.plantName(p)])
          : null,
    );
  }

  /// The zone in the color of its plant, the name of each plant in its dark shade.
  CanvasShape _zoneShape(Zone zone, String name, List<Plant> plants, PlantColors colors) {
    final (fill, border) = colors.zone(plants);
    return CanvasShape(
      id: zone.id,
      points: zone.shape,
      fill: fill.withValues(alpha: 0.75),
      border: border,
      labels: [name, for (final p in plants) AppLocalizations.plantName(p)],
      labelColors: [border, for (final p in plants) colors.dark(p)],
    );
  }

  Widget _buildSelectedBar(Zone zone, String name, List<String> plants) {
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
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                icon: const Icon(Icons.straighten),
                tooltip: 'dimensions.title'.tr(),
                onPressed: () => _editZoneDimensions(zone),
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
