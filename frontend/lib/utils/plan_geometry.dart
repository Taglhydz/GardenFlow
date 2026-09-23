import 'dart:math' as math;
import 'dart:ui';
import '../models/parcel.dart';

/// Pure geometry of the garden plan (meters). The plan starts at (0, 0) = top-left corner
/// and grows to the right and to the bottom with the parcels.
class PlanGeometry {
  PlanGeometry._();

  /// Positions and sizes are snapped to 10 cm.
  static const double snapStep = 0.1;

  /// Smallest parcel side.
  static const double minParcelSize = 0.2;

  /// Free space around the parcels, to be able to move them outward.
  static const double margin = 2;

  /// Smallest plan (empty garden).
  static const double minWorldSize = 6;

  /// Gap between a new parcel and the existing ones.
  static const double newParcelGap = 0.5;

  /// Divides instead of multiplying by 0.1 to avoid values like 0.30000000000000004.
  static double snap(double value) => (value / snapStep).round() / (1 / snapStep);

  /// Snapped position, never negative.
  static double snapPosition(double value) => math.max(0, snap(value));

  /// Snapped size, never below [minParcelSize].
  static double snapSize(double value) => math.max(minParcelSize, snap(value));

  /// Size of the plan : all the parcels + [margin], at least [minWorldSize].
  static Size worldSize(Iterable<Parcel> parcels) {
    var maxX = 0.0;
    var maxY = 0.0;
    for (final p in parcels) {
      maxX = math.max(maxX, p.posX + p.width);
      maxY = math.max(maxY, p.posY + p.length);
    }
    return Size(math.max(minWorldSize, maxX + margin), math.max(minWorldSize, maxY + margin));
  }

  /// Position of a new parcel : to the right of the existing ones, on the top line.
  static Offset newParcelPosition(Iterable<Parcel> parcels) {
    if (parcels.isEmpty) return Offset.zero;
    final maxX = parcels.map((p) => p.posX + p.width).reduce(math.max);
    return Offset(snap(maxX + newParcelGap), 0);
  }

  static Rect rectOf(Parcel parcel) => Rect.fromLTWH(parcel.posX, parcel.posY, parcel.width, parcel.length);

  /// Top-most parcel at [point] (meters) : the last one drawn wins.
  static Parcel? parcelAt(List<Parcel> parcels, Offset point) {
    for (final parcel in parcels.reversed) {
      if (rectOf(parcel).contains(point)) return parcel;
    }
    return null;
  }

  /// Parcel moved by [delta] meters from its [start] position.
  static Parcel moved(Parcel start, Offset delta) {
    return start.copyWith(
      posX: snapPosition(start.posX + delta.dx),
      posY: snapPosition(start.posY + delta.dy),
    );
  }

  /// Parcel resized from its bottom-right corner by [delta] meters.
  static Parcel resized(Parcel start, Offset delta) {
    return start.copyWith(
      width: snapSize(start.width + delta.dx),
      length: snapSize(start.length + delta.dy),
    );
  }
}
