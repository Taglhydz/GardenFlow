import 'dart:math' as math;
import 'dart:ui';
import 'geometry.dart';

/// Rules of the plans (garden plan and parcel plan), in meters.
class PlanGeometry {
  PlanGeometry._();

  /// Default grid of the magnet, in cm.
  static const int defaultSnapCm = 10;

  /// Grid steps offered to the user (cm). Without magnet, points are rounded to 1 cm (like the server).
  static const List<int> snapSteps = [5, 10, 25, 50, 100];

  /// Free space around the parcels on the garden plan, to draw new ones.
  static const double margin = 2;

  /// Free space around a parcel on its own plan.
  static const double parcelMargin = 0.5;

  /// Smallest garden plan (empty garden).
  static const double minWorldSize = 6;

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

  /// The garden plan : from (0, 0) to the farthest parcel + [margin], at least [minWorldSize].
  static Rect gardenWorld(Iterable<List<Offset>> shapes) {
    var maxX = 0.0;
    var maxY = 0.0;
    for (final shape in shapes) {
      for (final p in shape) {
        maxX = math.max(maxX, p.dx);
        maxY = math.max(maxY, p.dy);
      }
    }
    return Rect.fromLTWH(0, 0, math.max(minWorldSize, maxX + margin), math.max(minWorldSize, maxY + margin));
  }

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
