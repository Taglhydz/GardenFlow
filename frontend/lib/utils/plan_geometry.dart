import 'dart:math' as math;
import 'dart:ui';
import 'geometry.dart';

/// Rules of the plans (garden plan and parcel plan), in meters.
class PlanGeometry {
  PlanGeometry._();

  /// Points are snapped to 10 cm.
  static const double snapStep = 0.1;

  /// Free space around the parcels on the garden plan, to draw new ones.
  static const double margin = 2;

  /// Free space around a parcel on its own plan.
  static const double parcelMargin = 0.5;

  /// Smallest garden plan (empty garden).
  static const double minWorldSize = 6;

  /// Smallest shape accepted (same as the backend).
  static const double minShapeArea = 0.01;

  /// Divides instead of multiplying by 0.1 to avoid values like 0.30000000000000004.
  static double snap(double value) => (value / snapStep).round() / (1 / snapStep);

  static Offset snapPoint(Offset point) => Offset(snap(point.dx), snap(point.dy));

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
