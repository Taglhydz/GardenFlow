import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../models/parcel.dart';
import '../models/plant.dart';
import '../utils/plan_geometry.dart';

enum _DragMode { move, resize }

class _Drag {
  _Drag(this.mode, this.start, this.startPoint) : current = start;

  final _DragMode mode;
  final Parcel start;
  final Offset startPoint;
  Parcel current;
}

/// 2D plan of a garden, in meters, starting at the top-left corner (0, 0).
///
/// - no parcel selected : pan and pinch to zoom the plan
/// - tap a parcel to select it, then drag it to move it, or drag the corner handle to resize it
/// - tap the selected parcel again to open it, tap outside to deselect
class GardenPlan extends StatefulWidget {
  const GardenPlan({
    super.key,
    required this.parcels,
    required this.plantsByParcel,
    required this.selectedId,
    required this.onSelect,
    required this.onOpen,
    required this.onGeometryChanged,
  });

  final List<Parcel> parcels;

  /// Plants in the ground, by parcel id (shown in the parcels)
  final Map<int, List<Plant>> plantsByParcel;
  final int? selectedId;
  final ValueChanged<int?> onSelect;
  final ValueChanged<Parcel> onOpen;

  /// Called at the end of a move / resize.
  final void Function(Parcel previous, Parcel updated) onGeometryChanged;

  @override
  State<GardenPlan> createState() => _GardenPlanState();
}

class _GardenPlanState extends State<GardenPlan> {
  /// Radius (px) of the resize handle and of its touch area.
  static const _handleRadius = 12.0;
  static const _handleTouchRadius = 28.0;

  _Drag? _drag;

  /// The plan keeps its size during a drag, so it doesn't move under the finger.
  Size? _frozenWorld;

  List<Parcel> get _displayedParcels {
    final drag = _drag;
    if (drag == null) return widget.parcels;
    return [for (final p in widget.parcels) p.id == drag.current.id ? drag.current : p];
  }

  Parcel? get _selected {
    for (final p in _displayedParcels) {
      if (p.id == widget.selectedId) return p;
    }
    return null;
  }

  void _onTapUp(TapUpDetails details, double pixelsPerMeter) {
    final hit = PlanGeometry.parcelAt(_displayedParcels, details.localPosition / pixelsPerMeter);
    if (hit == null) {
      widget.onSelect(null);
    } else if (hit.id == widget.selectedId) {
      widget.onOpen(hit);
    } else {
      widget.onSelect(hit.id);
    }
  }

  void _onPanStart(DragStartDetails details, double pixelsPerMeter, Size world) {
    final selected = _selected;
    if (selected == null) return;

    final point = details.localPosition;
    final corner = Offset(
      (selected.posX + selected.width) * pixelsPerMeter,
      (selected.posY + selected.length) * pixelsPerMeter,
    );

    _DragMode? mode;
    if ((point - corner).distance <= _handleTouchRadius) {
      mode = _DragMode.resize;
    } else if (PlanGeometry.rectOf(selected).contains(point / pixelsPerMeter)) {
      mode = _DragMode.move;
    }
    if (mode == null) return;

    setState(() {
      _drag = _Drag(mode!, selected, point);
      _frozenWorld = world;
    });
  }

  void _onPanUpdate(DragUpdateDetails details, double pixelsPerMeter) {
    final drag = _drag;
    if (drag == null) return;

    final delta = (details.localPosition - drag.startPoint) / pixelsPerMeter;
    setState(() {
      drag.current = drag.mode == _DragMode.move
          ? PlanGeometry.moved(drag.start, delta)
          : PlanGeometry.resized(drag.start, delta);
    });
  }

  void _onPanEnd() {
    final drag = _drag;
    if (drag == null) return;

    final start = drag.start;
    final end = drag.current;
    final changed = start.posX != end.posX || start.posY != end.posY || start.width != end.width || start.length != end.length;

    // the parent updates its parcels synchronously (optimistic update) : no flicker
    if (changed) widget.onGeometryChanged(start, end);

    setState(() {
      _drag = null;
      _frozenWorld = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final world = _frozenWorld ?? PlanGeometry.worldSize(widget.parcels);
        // the whole width of the plan fits the screen, it scrolls vertically if needed
        final pixelsPerMeter = constraints.maxWidth / world.width;
        final canvasSize = Size(world.width * pixelsPerMeter, world.height * pixelsPerMeter);
        final isEditing = widget.selectedId != null;
        final selected = _selected;

        return InteractiveViewer(
          constrained: false,
          minScale: 0.5,
          maxScale: 5,
          boundaryMargin: const EdgeInsets.all(80),
          // while a parcel is selected, the finger moves the parcel, not the plan
          panEnabled: !isEditing,
          scaleEnabled: !isEditing,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // the drag starts where the finger touched : the parcel follows the finger exactly
            dragStartBehavior: DragStartBehavior.down,
            onTapUp: (details) => _onTapUp(details, pixelsPerMeter),
            onPanStart: isEditing ? (details) => _onPanStart(details, pixelsPerMeter, world) : null,
            onPanUpdate: isEditing ? (details) => _onPanUpdate(details, pixelsPerMeter) : null,
            onPanEnd: isEditing ? (_) => _onPanEnd() : null,
            onPanCancel: isEditing ? _onPanEnd : null,
            child: SizedBox.fromSize(
              size: canvasSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _GridPainter(pixelsPerMeter: pixelsPerMeter, world: world)),
                  ),
                  for (final parcel in _displayedParcels)
                    Positioned(
                      left: parcel.posX * pixelsPerMeter,
                      top: parcel.posY * pixelsPerMeter,
                      width: parcel.width * pixelsPerMeter,
                      height: parcel.length * pixelsPerMeter,
                      child: _ParcelTile(
                        parcel: parcel,
                        plants: widget.plantsByParcel[parcel.id] ?? const [],
                        isSelected: parcel.id == widget.selectedId,
                      ),
                    ),
                  if (selected != null)
                    Positioned(
                      left: (selected.posX + selected.width) * pixelsPerMeter - _handleRadius,
                      top: (selected.posY + selected.length) * pixelsPerMeter - _handleRadius,
                      child: const _ResizeHandle(radius: _handleRadius),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Soil colors of the parcels
const _soilColors = {
  'standard': Color(0xFFD7CCC8),
  'clay'    : Color(0xFFE6B89C),
  'sandy'   : Color(0xFFF3E5AB),
  'loamy'   : Color(0xFFC8B6A6),
  'humus'   : Color(0xFFA1887F),
  'chalky'  : Color(0xFFE0E0E0),
};

class _ParcelTile extends StatelessWidget {
  const _ParcelTile({required this.parcel, required this.plants, required this.isSelected});

  final Parcel parcel;
  final List<Plant> plants;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final names = plants.map(AppLocalizations.plantName).toSet().toList();

    return Container(
      decoration: BoxDecoration(
        color: (_soilColors[parcel.soilType] ?? _soilColors['standard']!).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.parcels,
          width: isSelected ? 3 : 1.5,
        ),
        boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8)] : null,
      ),
      padding: const EdgeInsets.all(4),
      clipBehavior: Clip.hardEdge,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(parcel.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (isSelected)
              Text(AppLocalizations.dimensions(parcel.width, parcel.length), style: const TextStyle(fontSize: 11)),
            for (final name in names.take(3))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.eco, size: 11, color: AppColors.primaryDark),
                  const SizedBox(width: 2),
                  Text(name, style: const TextStyle(fontSize: 11)),
                ],
              ),
            if (names.length > 3) Text('+${names.length - 3}', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'garden_view.resize'.tr(),
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 2),
        ),
        child: const Icon(Icons.open_in_full, size: 12, color: AppColors.white),
      ),
    );
  }
}

/// 1 m grid with the meters written on the top and left edges.
class _GridPainter extends CustomPainter {
  _GridPainter({required this.pixelsPerMeter, required this.world});

  final double pixelsPerMeter;
  final Size world;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF1F8E9));

    final line = Paint()
      ..color = const Color(0x3366BB6A)
      ..strokeWidth = 1;

    for (var x = 0; x <= world.width; x++) {
      canvas.drawLine(Offset(x * pixelsPerMeter, 0), Offset(x * pixelsPerMeter, size.height), line);
      if (x > 0) _label(canvas, '$x', Offset(x * pixelsPerMeter + 2, 2));
    }
    for (var y = 0; y <= world.height; y++) {
      canvas.drawLine(Offset(0, y * pixelsPerMeter), Offset(size.width, y * pixelsPerMeter), line);
      if (y > 0) _label(canvas, '$y', Offset(2, y * pixelsPerMeter + 2));
    }
  }

  void _label(Canvas canvas, String text, Offset position) {
    TextPainter(
      text: TextSpan(text: text, style: const TextStyle(fontSize: 9, color: Color(0x9966BB6A))),
      textDirection: TextDirection.ltr,
    )
      ..layout()
      ..paint(canvas, position);
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.pixelsPerMeter != pixelsPerMeter || oldDelegate.world != world;
}
