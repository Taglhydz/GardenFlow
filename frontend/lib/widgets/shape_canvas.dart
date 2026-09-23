import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../utils/geometry.dart';
import '../utils/plan_geometry.dart';

/// A shape shown on a [ShapeCanvas], points in meters (canvas coordinates).
class CanvasShape {
  const CanvasShape({
    required this.id,
    required this.points,
    required this.fill,
    this.border = AppColors.parcels,
    this.labels = const [],
  });

  final int id;
  final List<Offset> points;
  final Color fill;
  final Color border;

  /// First line in bold (the name), then smaller lines (e.g. the plants)
  final List<String> labels;
}

enum _DragMode { move, vertex }

class _Drag {
  _Drag({required this.mode, required this.shapeId, required this.startPoint, required this.original, this.vertex = -1})
      : current = original;

  final _DragMode mode;
  final int shapeId;
  final Offset startPoint;
  final List<Offset> original;
  final int vertex;
  List<Offset> current;
  Offset delta = Offset.zero;
}

/// Plan in meters where free shapes (polygons) are drawn and edited with the finger.
///
/// - drawing mode ([draft] not null) : each tap adds a point (snapped to the magnet grid [snapCm]),
///   tapping the first point closes the shape ([onDraftClose])
/// - no shape selected : tap a shape to select it, pan and pinch to move / zoom the plan
/// - a shape selected : drag it to move it, drag a corner to move the corner, drag a "+" (middle
///   of a side) to add a corner, long press a corner to remove it. Tap it again to open it,
///   tap outside to deselect.
///
/// The length of the sides is written along the shape being drawn and the selected shape,
/// whose corners are named A, B, C… (same names as in the dimensions sheet).
///
/// The canvas only shows its inputs : the parent saves the changes ([onMoved], [onReshaped])
/// and passes the new shapes back.
class ShapeCanvas extends StatefulWidget {
  const ShapeCanvas({
    super.key,
    required this.world,
    required this.shapes,
    this.background = const [],
    this.overlay = const [],
    this.selectedId,
    this.draft,
    this.onDraftPoint,
    this.onDraftClose,
    required this.onSelect,
    required this.onOpen,
    required this.onMoved,
    required this.onReshaped,
    this.nonNegative = false,
    this.snapCm = PlanGeometry.defaultSnapCm,
  });

  /// Part of the plan to show (meters)
  final Rect world;

  /// Interactive shapes, the last one is on top
  final List<CanvasShape> shapes;

  /// Drawn below the shapes, not interactive (e.g. the outline of the parcel)
  final List<CanvasShape> background;

  /// Drawn above the shapes, not interactive (e.g. the zones on the garden plan)
  final List<CanvasShape> overlay;

  final int? selectedId;

  /// Points of the shape being drawn : drawing mode when not null
  final List<Offset>? draft;
  final ValueChanged<Offset>? onDraftPoint;
  final VoidCallback? onDraftClose;

  final ValueChanged<int?> onSelect;
  final ValueChanged<int> onOpen;

  /// The whole shape moved by [delta] meters (snapped)
  final void Function(int id, Offset delta) onMoved;

  /// New points of the shape (a corner moved, added or removed)
  final void Function(int id, List<Offset> points) onReshaped;

  /// Points can't go below 0 (the garden plan starts at its top-left corner)
  final bool nonNegative;

  /// Magnet grid (cm) of the points drawn or dragged, 1 = no magnet
  final int snapCm;

  @override
  State<ShapeCanvas> createState() => _ShapeCanvasState();
}

class _ShapeCanvasState extends State<ShapeCanvas> {
  /// Touch areas (px) of the corners and of the "+" in the middle of the sides
  static const _vertexTouch = 24.0;
  static const _midpointTouch = 20.0;
  static const _closeTouch = 24.0;

  _Drag? _drag;

  /// The plan keeps its size during a drag, so it doesn't move under the finger
  (Rect, double)? _frozen;

  bool get _isDrawing => widget.draft != null;

  CanvasShape? get _selected {
    for (final s in widget.shapes) {
      if (s.id == widget.selectedId) return s;
    }
    return null;
  }

  /// Points of the selected shape, with the drag in progress
  List<Offset>? get _selectedPoints {
    final drag = _drag;
    if (drag != null && drag.shapeId == widget.selectedId) return drag.current;
    return _selected?.points;
  }

  Offset _clamp(Offset p) => widget.nonNegative ? Offset(math.max(0, p.dx), math.max(0, p.dy)) : p;

  // ======
  // Taps
  // ======
  void _onTapUp(Offset local, Rect world, double ppm) {
    final point = world.topLeft + local / ppm;

    if (_isDrawing) {
      final draft = widget.draft!;
      final first = draft.isEmpty ? null : (draft.first - world.topLeft) * ppm;
      if (draft.length >= 3 && first != null && (first - local).distance <= _closeTouch) {
        widget.onDraftClose?.call();
      } else {
        widget.onDraftPoint?.call(_clamp(PlanGeometry.snapPoint(point, widget.snapCm)));
      }
      return;
    }

    final hit = PlanGeometry.shapeAt([for (final s in widget.shapes) (s.id, s.points)], point);
    if (hit == null) {
      widget.onSelect(null);
    } else if (hit == widget.selectedId) {
      widget.onOpen(hit);
    } else {
      widget.onSelect(hit);
    }
  }

  /// Index of the corner of the selected shape under the finger, or -1
  int _vertexAt(List<Offset> points, Offset local, Rect world, double ppm) {
    for (var i = 0; i < points.length; i++) {
      if (((points[i] - world.topLeft) * ppm - local).distance <= _vertexTouch) return i;
    }
    return -1;
  }

  void _onLongPress(Offset local, Rect world, double ppm) {
    final selected = _selected;
    if (selected == null || _isDrawing || selected.points.length <= 3) return;

    final index = _vertexAt(selected.points, local, world, ppm);
    if (index >= 0) {
      widget.onReshaped(selected.id, [...selected.points]..removeAt(index));
    }
  }

  // ======
  // Drags
  // ======
  void _onPanStart(Offset local, Rect world, double ppm) {
    final selected = _selected;
    if (selected == null || _isDrawing) return;

    final point = world.topLeft + local / ppm;
    final points = selected.points;
    _Drag? drag;

    final vertex = _vertexAt(points, local, world, ppm);
    if (vertex >= 0) {
      drag = _Drag(mode: _DragMode.vertex, shapeId: selected.id, startPoint: point, original: points, vertex: vertex);
    } else {
      // "+" in the middle of a side : a new corner is inserted there, then dragged
      for (var i = 0; i < points.length && drag == null; i++) {
        final middle = (points[i] + points[(i + 1) % points.length]) / 2;
        if (((middle - world.topLeft) * ppm - local).distance <= _midpointTouch) {
          final withCorner = [...points]..insert(i + 1, PlanGeometry.snapPoint(middle, widget.snapCm));
          drag = _Drag(mode: _DragMode.vertex, shapeId: selected.id, startPoint: point, original: withCorner, vertex: i + 1);
        }
      }
      if (drag == null && Geometry.contains(points, point)) {
        drag = _Drag(mode: _DragMode.move, shapeId: selected.id, startPoint: point, original: points);
      }
    }
    if (drag == null) return;

    setState(() {
      _drag = drag;
      _frozen = (world, ppm);
    });
  }

  void _onPanUpdate(Offset local, Rect world, double ppm) {
    final drag = _drag;
    if (drag == null) return;

    final delta = world.topLeft + local / ppm - drag.startPoint;
    setState(() {
      if (drag.mode == _DragMode.vertex) {
        final moved = _clamp(PlanGeometry.snapPoint(drag.original[drag.vertex] + delta, widget.snapCm));
        drag.current = [...drag.original]..[drag.vertex] = moved;
      } else {
        var snapped = PlanGeometry.snapPoint(delta, widget.snapCm);
        if (widget.nonNegative) {
          // the shape stops at the top and left borders of the plan
          final bounds = Geometry.bounds(drag.original);
          snapped = Offset(math.max(snapped.dx, -bounds.left), math.max(snapped.dy, -bounds.top));
        }
        drag.delta = snapped;
        drag.current = Geometry.translate(drag.original, snapped);
      }
    });
  }

  void _onPanEnd() {
    final drag = _drag;
    if (drag == null) return;

    if (drag.mode == _DragMode.move) {
      if (drag.delta != Offset.zero) widget.onMoved(drag.shapeId, drag.delta);
    } else {
      final original = _selected?.points ?? const [];
      final changed = drag.current.length != original.length ||
          [for (var i = 0; i < original.length; i++) drag.current[i] != original[i]].any((c) => c);
      if (changed) widget.onReshaped(drag.shapeId, drag.current);
    }

    // the parent updates its shapes synchronously (optimistic update) : no flicker
    setState(() {
      _drag = null;
      _frozen = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final (world, ppm) = _frozen ??
            (widget.world, math.min(constraints.maxWidth / widget.world.width, constraints.maxHeight / widget.world.height));
        final editing = widget.selectedId != null && !_isDrawing;

        return InteractiveViewer(
          constrained: false,
          minScale: 0.5,
          maxScale: 6,
          boundaryMargin: const EdgeInsets.all(80),
          // while a shape is selected, the finger edits the shape, not the plan
          panEnabled: !editing,
          scaleEnabled: !editing,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // the drag starts where the finger touched : the shape follows the finger exactly
            dragStartBehavior: DragStartBehavior.down,
            onTapUp: (d) => _onTapUp(d.localPosition, world, ppm),
            onLongPressStart: editing ? (d) => _onLongPress(d.localPosition, world, ppm) : null,
            onPanStart: editing ? (d) => _onPanStart(d.localPosition, world, ppm) : null,
            onPanUpdate: editing ? (d) => _onPanUpdate(d.localPosition, world, ppm) : null,
            onPanEnd: editing ? (_) => _onPanEnd() : null,
            onPanCancel: editing ? _onPanEnd : null,
            child: CustomPaint(
              size: world.size * ppm,
              painter: _PlanPainter(
                world: world,
                ppm: ppm,
                snapCm: widget.snapCm,
                background: widget.background,
                shapes: [
                  for (final s in widget.shapes)
                    s.id == _drag?.shapeId
                        ? CanvasShape(id: s.id, points: _drag!.current, fill: s.fill, border: s.border, labels: s.labels)
                        : s,
                ],
                overlay: _drag?.mode == _DragMode.move || _drag == null ? _movedOverlay() : widget.overlay,
                selectedId: widget.selectedId,
                selectedPoints: editing ? _selectedPoints : null,
                draft: widget.draft,
              ),
            ),
          ),
        );
      },
    );
  }

  /// The overlay (zones of a parcel) follows the parcel during a move.
  List<CanvasShape> _movedOverlay() {
    final drag = _drag;
    if (drag == null || drag.mode != _DragMode.move) return widget.overlay;

    final moving = widget.shapes.firstWhere((s) => s.id == drag.shapeId);
    return [
      for (final o in widget.overlay)
        o.points.every((p) => Geometry.contains(moving.points, p))
            ? CanvasShape(id: o.id, points: Geometry.translate(o.points, drag.delta), fill: o.fill, border: o.border, labels: o.labels)
            : o,
    ];
  }
}

class _PlanPainter extends CustomPainter {
  _PlanPainter({
    required this.world,
    required this.ppm,
    required this.snapCm,
    required this.background,
    required this.shapes,
    required this.overlay,
    required this.selectedId,
    required this.selectedPoints,
    required this.draft,
  });

  final Rect world;
  final double ppm;
  final int snapCm;
  final List<CanvasShape> background;
  final List<CanvasShape> shapes;
  final List<CanvasShape> overlay;
  final int? selectedId;
  final List<Offset>? selectedPoints;
  final List<Offset>? draft;

  Offset _px(Offset meters) => (meters - world.topLeft) * ppm;

  Path _path(List<Offset> points) => Path()..addPolygon([for (final p in points) _px(p)], true);

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);

    for (final s in background) {
      _paintShape(canvas, s, strokeWidth: 2);
    }
    for (final s in shapes) {
      final selected = s.id == selectedId;
      if (selected) {
        canvas.drawPath(_path(s.points), Paint()..color = AppColors.primary.withValues(alpha: 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      }
      _paintShape(canvas, s, strokeWidth: selected ? 3 : 1.5, borderColor: selected ? AppColors.primary : null);
    }
    for (final s in overlay) {
      _paintShape(canvas, s, strokeWidth: 1);
    }
    for (final s in [...shapes, ...overlay]) {
      _paintLabels(canvas, s);
    }

    if (selectedPoints != null) {
      _paintHandles(canvas, selectedPoints!);
      _paintLengths(canvas, selectedPoints!, closed: true);
    }
    if (draft != null) {
      _paintDraft(canvas, draft!);
      _paintLengths(canvas, draft!, closed: false);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF1F8E9));

    // magnet grid, only when its lines are far enough apart to be seen
    final step = snapCm / 100;
    if (snapCm > 1 && snapCm < 100 && step * ppm >= 8) {
      final minor = Paint()
        ..color = const Color(0x1A66BB6A)
        ..strokeWidth = 1;
      for (var i = (world.left / step).ceil(); i * step <= world.right; i++) {
        final px = _px(Offset(i * step, 0)).dx;
        canvas.drawLine(Offset(px, 0), Offset(px, size.height), minor);
      }
      for (var i = (world.top / step).ceil(); i * step <= world.bottom; i++) {
        final py = _px(Offset(0, i * step)).dy;
        canvas.drawLine(Offset(0, py), Offset(size.width, py), minor);
      }
    }

    final line = Paint()
      ..color = const Color(0x3366BB6A)
      ..strokeWidth = 1;

    for (var x = world.left.ceil(); x <= world.right; x++) {
      final px = _px(Offset(x.toDouble(), 0)).dx;
      canvas.drawLine(Offset(px, 0), Offset(px, size.height), line);
      _text(canvas, '$x', Offset(px + 2, 2), 9, const Color(0x9966BB6A));
    }
    for (var y = world.top.ceil(); y <= world.bottom; y++) {
      final py = _px(Offset(0, y.toDouble())).dy;
      canvas.drawLine(Offset(0, py), Offset(size.width, py), line);
      _text(canvas, '$y', Offset(2, py + 2), 9, const Color(0x9966BB6A));
    }
  }

  void _paintShape(Canvas canvas, CanvasShape s, {required double strokeWidth, Color? borderColor}) {
    if (s.points.length < 3) return;
    final path = _path(s.points);
    canvas.drawPath(path, Paint()..color = s.fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor ?? s.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintLabels(Canvas canvas, CanvasShape s) {
    if (s.labels.isEmpty || s.points.length < 3) return;
    final bounds = Geometry.bounds(s.points);
    final maxWidth = bounds.width * ppm - 6;
    if (maxWidth < 20 || bounds.height * ppm < 14) return;

    var position = _px(Geometry.labelPoint(s.points));
    final painters = [
      for (var i = 0; i < s.labels.length && i < 4; i++)
        TextPainter(
          text: TextSpan(
            text: s.labels[i],
            style: TextStyle(fontSize: i == 0 ? 12 : 11, fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal, color: const Color(0xFF3E2723)),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: maxWidth),
    ];
    final total = painters.fold<double>(0, (h, p) => h + p.height);
    position = position.translate(0, -total / 2);
    for (final p in painters) {
      p.paint(canvas, position.translate(-p.width / 2, 0));
      position = position.translate(0, p.height);
    }
  }

  void _paintHandles(Canvas canvas, List<Offset> points) {
    final fill = Paint()..color = AppColors.white;
    final border = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // "+" in the middle of each side
    for (var i = 0; i < points.length; i++) {
      final middle = _px((points[i] + points[(i + 1) % points.length]) / 2);
      canvas.drawCircle(middle, 7, fill);
      canvas.drawCircle(middle, 7, border..strokeWidth = 1.5);
      canvas.drawLine(middle.translate(-3.5, 0), middle.translate(3.5, 0), border);
      canvas.drawLine(middle.translate(0, -3.5), middle.translate(0, 3.5), border);
    }
    // corners, with their name
    for (var i = 0; i < points.length; i++) {
      final center = _px(points[i]);
      canvas.drawCircle(center, 9, Paint()..color = AppColors.primary);
      canvas.drawCircle(center, 9, fill..style = PaintingStyle.stroke..strokeWidth = 2);
      fill.style = PaintingStyle.fill;
      final name = TextPainter(
        text: TextSpan(
          text: PlanGeometry.cornerName(i),
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      name.paint(canvas, center - Offset(name.width / 2, name.height / 2));
    }
  }

  /// Length of each side, written outside the shape next to the middle of the side.
  void _paintLengths(Canvas canvas, List<Offset> points, {required bool closed}) {
    if (points.length < 2) return;
    // orientation of the corners : the outside of a side is on its left or on its right
    var signedArea = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      signedArea += a.dx * b.dy - b.dx * a.dy;
    }
    final outside = signedArea >= 0 ? 1.0 : -1.0;

    final sides = closed ? points.length : points.length - 1;
    for (var i = 0; i < sides; i++) {
      final a = _px(points[i]);
      final b = _px(points[(i + 1) % points.length]);
      final pixels = (b - a).distance;
      if (pixels < 40) continue; // no room for the text

      final normal = Offset(b.dy - a.dy, a.dx - b.dx) / pixels * outside;
      final label = TextPainter(
        text: TextSpan(
          text: AppLocalizations.meters(PlanGeometry.sideLength(points, i)),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final center = (a + b) / 2 + normal * 18;
      final box = Rect.fromCenter(center: center, width: label.width + 8, height: label.height + 2);
      canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(4)), Paint()..color = const Color(0xE6FFFFFF));
      label.paint(canvas, box.topLeft + const Offset(4, 1));
    }
  }

  void _paintDraft(Canvas canvas, List<Offset> points) {
    if (points.isEmpty) return;
    final valid = points.length < 3 || PlanGeometry.isValidShape(points);
    final color = valid ? AppColors.primaryDark : AppColors.error;

    if (points.length >= 3) {
      canvas.drawPath(_path(points), Paint()..color = color.withValues(alpha: 0.12));
    }
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path()..addPolygon([for (final p in points) _px(p)], false);
    canvas.drawPath(path, line);

    for (var i = 0; i < points.length; i++) {
      // the first point is bigger : tap it to close the shape
      final isFirst = i == 0 && points.length >= 3;
      canvas.drawCircle(_px(points[i]), isFirst ? 11 : 6, Paint()..color = color);
      if (isFirst) canvas.drawCircle(_px(points[i]), 5, Paint()..color = AppColors.white);
    }
  }

  void _text(Canvas canvas, String text, Offset position, double size, Color color) {
    TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color)),
      textDirection: TextDirection.ltr,
    )
      ..layout()
      ..paint(canvas, position);
  }

  @override
  bool shouldRepaint(_PlanPainter old) => true;
}
