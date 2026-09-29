import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../models/crop.dart';
import '../models/garden.dart';
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
import '../widgets/plan_bottom_slot.dart';
import '../widgets/plan_entrance.dart';
import '../widgets/rename_dialog.dart';
import '../widgets/shape_canvas.dart';
import '../widgets/snap_button.dart';
import 'parcel_screen.dart';

enum _GardenAction { rename, delete }

/// Opened garden : plan of its parcels, drawn with the finger.
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

  /// The plan : a parcel screen opens from the parcel on it
  final _canvasKey = GlobalKey<ShapeCanvasState>();

  /// Points of the parcel being drawn (null = not drawing)
  List<Offset>? _draft;
  bool _isSaving = false;

  int get _gardenId => widget.garden.id;

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

  Parcel? _parcel(int id) {
    for (final p in ref.read(parcelsProvider(_gardenId)).value ?? const <Parcel>[]) {
      if (p.id == id) return p;
    }
    return null;
  }

  // =======
  // Drawing
  // =======
  void _startDrawing() => setState(() {
    _draft = [];
    _selectedParcelId = null;
  });

  Future<void> _finishDrawing() async {
    final points = _draft;
    if (points == null || _isSaving) return;
    if (!PlanGeometry.isValidShape(points)) {
      _showError('garden_view.invalid_shape'.tr());
      return;
    }
    final existing = ref.read(parcelsProvider(_gardenId)).value ?? const <Parcel>[];
    // the corners can't be on a parcel, but the shape could still go around one
    if (existing.any((p) => Geometry.overlap(points, p.absoluteShape))) {
      _showError('garden_view.parcels_overlap'.tr());
      return;
    }

    setState(() => _isSaving = true);
    try {
      // the position is the top-left corner of the drawing, the shape is relative to it
      final origin = Geometry.bounds(points).topLeft;
      final parcel = await ref.read(parcelsProvider(_gardenId).notifier).create({
        'name': PlanGeometry.nextName('parcel'.tr(), existing.map((p) => p.name)),
        'pos_x': origin.dx,
        'pos_y': origin.dy,
        'shape': shapeToJson(Geometry.translate(points, -origin)),
      });
      if (mounted) {
        setState(() {
          _draft = null;
          _selectedParcelId = parcel.id;
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
  Future<void> _onMoved(int id, Offset delta) async {
    final parcel = _parcel(id);
    if (parcel == null) return;
    try {
      await ref.read(parcelsProvider(_gardenId).notifier).move(parcel, parcel.position + delta);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _onReshaped(int id, List<Offset> absolutePoints) async {
    final parcel = _parcel(id);
    if (parcel == null) return;
    if (!PlanGeometry.isValidShape(absolutePoints)) {
      _showError('garden_view.invalid_shape'.tr());
      return;
    }
    try {
      // the position doesn't change (the zones are relative to it), only the shape
      await ref
          .read(parcelsProvider(_gardenId).notifier)
          .reshape(parcel, Geometry.translate(absolutePoints, -parcel.position));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _editDimensions(Parcel parcel) async {
    try {
      await editParcelDimensions(context, ref, parcel);
    } catch (e) {
      _showError(e);
    }
  }

  void _openParcel(int id) {
    // the parcel grows out of its shape on the garden plan, and shrinks back into it when closed
    Navigator.push(
      context,
      PlanEntrance.route(
        from: () => _canvasKey.currentState?.globalRectOf(id),
        builder: (_) => ParcelScreen(gardenId: _gardenId, parcelId: id),
      ),
    );
  }

  // ======
  // Garden
  // ======
  Future<void> _onGardenAction(_GardenAction action) async {
    switch (action) {
      case _GardenAction.rename:
        await _renameGarden();
      case _GardenAction.delete:
        await _deleteGarden();
    }
  }

  Future<void> _renameGarden() async {
    final name = await showRenameDialog(
      context,
      title: 'garden_view.rename_garden'.tr(),
      label: 'garden_name'.tr(),
      name: widget.garden.name,
    );

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

  // ====
  // View
  // ====
  @override
  Widget build(BuildContext context) {
    final parcelsAsync = ref.watch(parcelsProvider(_gardenId));
    final parcels = parcelsAsync.value ?? const <Parcel>[];
    final zones = ref.watch(zonesProvider(_gardenId)).value ?? const <Zone>[];
    final crops = ref.watch(gardenCropsProvider(_gardenId)).value ?? const <Crop>[];
    final plantsById = ref.watch(plantsByIdProvider);
    final plantColors = ref.watch(plantColorsProvider);

    Parcel? selected;
    for (final p in parcels) {
      if (p.id == _selectedParcelId) selected = p;
    }

    final appBar = AppBar(
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
    );

    return Scaffold(
      // transparent : the list of the gardens is seen around the plan while the garden opens (PlanEntrance)
      backgroundColor: Colors.transparent,
      // the header comes down from the top of the screen
      appBar: PreferredSize(
        preferredSize: appBar.preferredSize,
        child: EntranceSlide(offset: const Offset(0, -1), start: 0.35, child: appBar),
      ),
      // the plan goes on behind the bottom bar (no jump when it appears), it is centered above it
      extendBody: true,
      body: !parcelsAsync.hasValue
          ? (parcelsAsync.hasError ? _buildError() : const Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                EntranceSlide(
                  offset: const Offset(0, -2),
                  child: HelpBanner(
                    screen: 'garden',
                    text: _draft != null
                        ? 'garden_view.draw_hint'.tr()
                        : selected != null
                        ? 'garden_view.hint_selected'.tr()
                        : parcels.isEmpty
                        ? 'garden_view.empty_hint'.tr()
                        : 'garden_view.hint'.tr(),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ShapeCanvas(
                          key: _canvasKey,
                          snapCm: ref.watch(snapProvider).effectiveCm,
                          world: PlanGeometry.gardenWorld([
                            for (final p in parcels) p.absoluteShape,
                            if (_draft != null) _draft!,
                          ]),
                          view: PlanGeometry.gardenView([for (final p in parcels) p.absoluteShape]),
                          nonNegative: true,
                          shapes: [
                            for (final p in parcels)
                              CanvasShape(
                                id: p.id,
                                points: p.absoluteShape,
                                fill: soilColor(p.soilType),
                                labels: [p.name],
                              ),
                          ],
                          overlay: _zoneShapes(parcels, zones, crops, plantsById, plantColors),
                          selectedId: selected?.id,
                          draft: _draft,
                          onDraftPoint: (point) => setState(() => _draft = [..._draft!, point]),
                          onDraftClose: _finishDrawing,
                          onDraftRefused: (_) => _showError('garden_view.point_on_parcel'.tr()),
                          onSelect: (id) => setState(() => _selectedParcelId = id),
                          onOpen: _openParcel,
                          onMoved: _onMoved,
                          onReshaped: _onReshaped,
                        ),
                      ),
                      // the small buttons come in from their side of the screen
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: EntranceSlide(offset: Offset(2.5, 0), start: 0.5, child: SnapButton()),
                      ),
                      const Positioned(
                        top: 8,
                        left: 8,
                        child: EntranceSlide(offset: Offset(-2.5, 0), start: 0.5, child: HelpButton(screen: 'garden')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      // in the bottom bar of the Scaffold, error messages are shown above it instead of hiding it.
      // The button, the drawing bar and the bar of the selected parcel come up from the bottom
      bottomNavigationBar: PlanBottomSlot(
        child: _draft != null
            ? DrawingBar(
                key: const ValueKey('drawing'),
                pointCount: _draft!.length,
                isSaving: _isSaving,
                onUndo: () => setState(() => _draft = [..._draft!]..removeLast()),
                onCancel: () => setState(() => _draft = null),
                onFinish: _finishDrawing,
              )
            : selected != null
            ? KeyedSubtree(key: const ValueKey('selected'), child: _buildSelectedBar(selected))
            : parcelsAsync.hasValue
            ? SafeArea(
                key: const ValueKey('buttons'),
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    heightFactor: 1,
                    // when the garden opens, comes up from the bottom of the screen
                    child: EntranceSlide(
                      offset: const Offset(0, 2),
                      start: 0.45,
                      child: FloatingActionButton.extended(
                        heroTag: 'draw_parcel',
                        onPressed: _startDrawing,
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        icon: const Icon(Icons.draw_outlined),
                        label: Text('garden_view.draw_parcel'.tr()),
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('none')),
      ),
    );
  }

  /// Zones drawn inside the parcels, with their plants in the ground.
  List<CanvasShape> _zoneShapes(
    List<Parcel> parcels,
    List<Zone> zones,
    List<Crop> crops,
    Map<int, Plant> plantsById,
    PlantColors colors,
  ) {
    final parcelsById = {for (final p in parcels) p.id: p};
    return [
      for (final zone in zones)
        if (parcelsById[zone.parcelId] != null) _zoneShape(zone, parcelsById[zone.parcelId]!, crops, plantsById, colors),
    ];
  }

  /// A zone in the color of its plant, the name of each plant in its dark shade.
  CanvasShape _zoneShape(Zone zone, Parcel parcel, List<Crop> crops, Map<int, Plant> plantsById, PlantColors colors) {
    final plants = ZoneNames.plantsIn(zone.id, crops, plantsById);
    final (fill, border) = colors.zone(plants);
    return CanvasShape(
      id: zone.id,
      points: zone.absoluteShape(parcel),
      fill: fill.withValues(alpha: 0.6),
      border: border.withValues(alpha: 0.7),
      labels: [for (final p in plants) AppLocalizations.plantName(p)],
      labelColors: [for (final p in plants) colors.dark(p)],
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
                      '${AppLocalizations.area(parcel.areaM2)} · ${AppLocalizations.getSoilTypeLabel(parcel.soilType)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.straighten),
                tooltip: 'dimensions.title'.tr(),
                onPressed: () => _editDimensions(parcel),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'edit_parcel'.tr(),
                onPressed: () => ParcelFormSheet.show(context, gardenId: _gardenId, parcel: parcel),
              ),
              ElevatedButton(
                onPressed: () => _openParcel(parcel.id),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.white),
                child: Text('garden_view.open_parcel'.tr()),
              ),
            ],
          ),
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

/// Dimensions sheet of a parcel (sides in meters, position in the garden), then saves it.
/// Throws if the server refuses the new shape.
Future<void> editParcelDimensions(BuildContext context, WidgetRef ref, Parcel parcel) async {
  final zones = (ref.read(zonesProvider(parcel.gardenId)).value ?? const <Zone>[]).where(
    (z) => z.parcelId == parcel.id,
  );

  final result = await DimensionsSheet.show(
    context,
    title: 'dimensions.title_of'.tr(args: [parcel.name]),
    shape: parcel.absoluteShape,
    positionLabel: 'dimensions.position_in_garden'.tr(),
    validate: (result) {
      if (result.finalShape.any((p) => p.dx < 0 || p.dy < 0)) return 'dimensions.outside_garden'.tr();
      // the zones stay where they are in the parcel : they must still be inside its new shape
      final relative = Geometry.translate(result.shape, -parcel.position);
      if (zones.any((z) => !Geometry.isInside(z.shape, relative))) return 'errors.ZONES_OUTSIDE_PARCEL'.tr();
      return null;
    },
  );
  if (result == null) return;

  await ref
      .read(parcelsProvider(parcel.gardenId).notifier)
      .setGeometry(
        parcel,
        position: PlanGeometry.roundCm(parcel.position + result.move),
        shape: [for (final p in result.shape) PlanGeometry.roundCm(p - parcel.position)],
      );
}

/// Color of a parcel according to its soil.
Color soilColor(String soilType) =>
    const {
      'standard': Color(0xD9D7CCC8),
      'clay': Color(0xD9E6B89C),
      'sandy': Color(0xD9F3E5AB),
      'loamy': Color(0xD9C8B6A6),
      'humus': Color(0xD9A1887F),
      'chalky': Color(0xD9E0E0E0),
    }[soilType] ??
    const Color(0xD9D7CCC8);
