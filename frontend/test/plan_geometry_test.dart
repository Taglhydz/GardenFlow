import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:GardenFlow/models/parcel.dart';
import 'package:GardenFlow/utils/plan_geometry.dart';

Parcel parcel(int id, double x, double y, double w, double l) =>
    Parcel(id: id, gardenId: 1, name: 'P$id', posX: x, posY: y, width: w, length: l);

void main() {
  test('snap to 10 cm without floating point noise', () {
    expect(PlanGeometry.snap(0.34), 0.3);
    expect(PlanGeometry.snap(0.36), 0.4);
    expect(PlanGeometry.snap(1.25), 1.3);
    expect(PlanGeometry.snap(0.1 + 0.2), 0.3);
  });

  test('positions are never negative, sizes never below the minimum', () {
    expect(PlanGeometry.snapPosition(-1.3), 0);
    expect(PlanGeometry.snapSize(0.05), PlanGeometry.minParcelSize);
  });

  test('the plan fits the parcels plus a margin, with a minimum size', () {
    expect(PlanGeometry.worldSize(const []), const Size(PlanGeometry.minWorldSize, PlanGeometry.minWorldSize));

    final size = PlanGeometry.worldSize([parcel(1, 0, 0, 2, 1), parcel(2, 7, 3, 3, 4)]);
    expect(size, const Size(10 + PlanGeometry.margin, 7 + PlanGeometry.margin));
  });

  test('a new parcel goes to the right of the existing ones', () {
    expect(PlanGeometry.newParcelPosition(const []), Offset.zero);
    expect(PlanGeometry.newParcelPosition([parcel(1, 0, 0, 2, 1), parcel(2, 1, 3, 2.3, 1)]), const Offset(3.8, 0));
  });

  test('hit test returns the top-most parcel', () {
    final parcels = [parcel(1, 0, 0, 3, 3), parcel(2, 1, 1, 1, 1)];
    expect(PlanGeometry.parcelAt(parcels, const Offset(1.5, 1.5))?.id, 2);
    expect(PlanGeometry.parcelAt(parcels, const Offset(0.5, 0.5))?.id, 1);
    expect(PlanGeometry.parcelAt(parcels, const Offset(5, 5)), isNull);
  });

  test('move and resize are snapped and keep the other dimensions', () {
    final start = parcel(1, 1, 1, 2, 1.5);

    final moved = PlanGeometry.moved(start, const Offset(0.73, -2));
    expect([moved.posX, moved.posY, moved.width, moved.length], [1.7, 0, 2, 1.5]);

    final resized = PlanGeometry.resized(start, const Offset(-5, 0.26));
    expect([resized.posX, resized.posY, resized.width, resized.length], [1, 1, PlanGeometry.minParcelSize, 1.8]);
    expect(resized.areaM2, closeTo(PlanGeometry.minParcelSize * 1.8, 1e-9));
  });
}
