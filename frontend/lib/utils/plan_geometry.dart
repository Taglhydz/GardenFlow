import 'dart:math' as math;
import 'dart:ui';
import 'geometry.dart';

/// Rules of the plans (garden plan and parcel plan), in meters.
class PlanGeometry {
  PlanGeometry._();

  /// Default grid of the magnet, in cm.
  static const int defaultSnapCm = 50;

  /// Grid steps offered to the user (cm). Without magnet, points are rounded to 1 cm (like the server).
  static const List<int> snapSteps = [5, 10, 25, 50, 100];

  /// Free space around the parcels on the garden plan, to draw new ones.
  static const double margin = 2;

  /// Free space around a parcel on its own plan.
  static const double parcelMargin = 0.5;

  /// Smallest part of the garden plan shown when it opens (empty garden).
  static const double minWorldSize = 6;

  /// Free space of the garden plan beyond the farthest parcel : the plan is "infinite" to the right and to the bottom.
  static const double gardenExtent = 500;

  /// Distance (px on the screen) under which a point sticks to a nearby side.
  static const double borderMagnetPx = 16;

  /// Points closer than that (m) to a side are on it (the cm rounding moves the points of slanted sides a bit).
  static const double onBorderTolerance = 0.01;

  /// Smallest shape accepted (same as the backend).
  static const double minShapeArea = 0.01;

  /// Nearest multiple of [stepCm]. Computed in cm then divided by 100 to avoid values like 0.30000000000000004.
  static double snap(double value, [int stepCm = defaultSnapCm]) => (value * 100 / stepCm).round() * stepCm / 100;

  static Offset snapPoint(Offset point, [int stepCm = defaultSnapCm]) =>
      Offset(snap(point.dx, stepCm), snap(point.dy, stepCm));

  /// Rounded to the cm, like the server stores the points.
  static Offset roundCm(Offset point) => snapPoint(point, 1);

  /// Name of the corner [index] on the plan and in the dimensions : A, B, … Z, A2, B2, …
  static String cornerName(int index) =>
      String.fromCharCode(65 + index % 26) + (index >= 26 ? '${index ~/ 26 + 1}' : '');

  /// Length of the side from the corner [index] to the next one.
  static double sideLength(List<Offset> points, int index) =>
      (points[(index + 1) % points.length] - points[index]).distance;

  /// Gives the side [index] (corner [index] -> next corner) the length [length] by stretching the shape
  /// in the direction of that side : the first corner doesn't move, the corners that are at the end of
  /// the side or beyond (in that direction) move with it. A rectangle stays a rectangle.
  static List<Offset> setSideLength(List<Offset> points, int index, double length) {
    final start = points[index];
    final end = points[(index + 1) % points.length];
    final current = (end - start).distance;
    if (current == 0) return points;

    final direction = (end - start) / current;
    final shift = direction * (length - current);
    // position of each corner along the side, the end of the side is at `current`
    double along(Offset p) => (p - start).dx * direction.dx + (p - start).dy * direction.dy;
    const tolerance = 0.001;

    return [for (final p in points) roundCm(along(p) >= current - tolerance ? p + shift : p)];
  }

  /// Part of the garden plan shown when it opens and by the recenter button : the parcels + [margin],
  /// at least [minWorldSize] around their center ; from (0, 0) when the garden is empty.
  static Rect gardenView(Iterable<List<Offset>> shapes) {
    final points = [for (final shape in shapes) ...shape];
    if (points.isEmpty) return const Rect.fromLTWH(0, 0, minWorldSize, minWorldSize);

    final bounds = Geometry.bounds(points).inflate(margin);
    return Rect.fromCenter(
      center: bounds.center,
      width: math.max(minWorldSize, bounds.width),
      height: math.max(minWorldSize, bounds.height),
    );
  }

  /// The whole garden plan : from (0, 0) to [gardenExtent] meters beyond the farthest parcel.
  static Rect gardenWorld(Iterable<List<Offset>> shapes) {
    final view = gardenView(shapes);
    return Rect.fromLTWH(0, 0, view.right + gardenExtent, view.bottom + gardenExtent);
  }

  /// Point of a side of [shapes] near [point] (closer than [maxDistance] m), or null : a corner when one is
  /// close enough, else the nearest point of the side, on the magnet grid [stepCm] when the side goes through it.
  static Offset? stickToBorder(Iterable<List<Offset>> shapes, Offset point, double maxDistance, int stepCm) {
    Offset? corner;
    Offset? onSide;
    var cornerDistance = maxDistance;
    var sideDistance = maxDistance;
    for (final shape in shapes) {
      for (var i = 0; i < shape.length; i++) {
        final a = shape[i];
        final b = shape[(i + 1) % shape.length];
        if ((a - point).distance <= cornerDistance) {
          corner = a;
          cornerDistance = (a - point).distance;
        }
        final closest = Geometry.closestOnSegment(point, a, b);
        if ((closest - point).distance <= sideDistance) {
          final onGrid = snapPoint(closest, stepCm);
          onSide = Geometry.distanceToSegment(onGrid, a, b) < 1e-6 ? onGrid : roundCm(closest);
          sideDistance = (closest - point).distance;
        }
      }
    }
    return corner ?? onSide;
  }

  /// [point] is on a side of one of the [shapes].
  static bool isOnBorder(Iterable<List<Offset>> shapes, Offset point) =>
      shapes.any((s) => s.length >= 2 && Geometry.distanceToBorder(s, point) <= onBorderTolerance);

  /// [point] (rounded to the cm) inside or on the border of [area] : the point itself, or the nearest
  /// cm around it when the rounding put it just outside a slanted side. Null when it is really outside.
  static Offset? keepInside(List<Offset> area, Offset point) {
    if (Geometry.contains(area, point)) return point;
    if (Geometry.distanceToBorder(area, point) > onBorderTolerance) return null;
    final candidates = [
      for (final dx in const [-0.01, 0.0, 0.01])
        for (final dy in const [-0.01, 0.0, 0.01]) roundCm(point + Offset(dx, dy)),
    ].where((p) => Geometry.contains(area, p)).toList()
      ..sort((p, q) => (p - point).distance.compareTo((q - point).distance));
    return candidates.firstOrNull;
  }

  /// [point] is inside one of the [shapes], not only on its border (within [onBorderTolerance]).
  static bool isInsideAny(Iterable<List<Offset>> shapes, Offset point) => shapes.any(
    (s) => Geometry.containsStrictly(s, point) && Geometry.distanceToBorder(s, point) > onBorderTolerance,
  );

  /// The plan of a parcel : its shape + [parcelMargin] around.
  static Rect parcelWorld(List<Offset> shape) => Geometry.bounds(shape).inflate(parcelMargin);

  /// A drawn shape can be saved : no crossing edges, big enough.
  static bool isValidShape(List<Offset> points) =>
      points.length >= 3 && Geometry.isSimple(points) && Geometry.area(points) >= minShapeArea;

  /// "Parcelle 3" : the first free number after the existing names.
  static String nextName(String prefix, Iterable<String> existing) {
    final names = existing.toSet();
    var n = names.length + 1;
    while (names.contains('$prefix $n')) {
      n++;
    }
    return '$prefix $n';
  }

  /// Top-most shape containing [point] : the last one drawn wins.
  static int? shapeAt(List<(int, List<Offset>)> shapes, Offset point) {
    for (final (id, points) in shapes.reversed) {
      if (Geometry.contains(points, point)) return id;
    }
    return null;
  }
}
