import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:GardenFlow/utils/geometry.dart';
import 'package:GardenFlow/utils/plan_geometry.dart';

List<Offset> rect(double w, double h, [double x = 0, double y = 0]) =>
    [Offset(x, y), Offset(x + w, y), Offset(x + w, y + h), Offset(x, y + h)];

// L shape : 3 x 3 square without its top-right 2 x 2 corner
const lShape = [Offset(0, 0), Offset(1, 0), Offset(1, 2), Offset(3, 2), Offset(3, 3), Offset(0, 3)];

void main() {
  group('geometry (same rules as the backend)', () {
    test('area', () {
      expect(Geometry.area(rect(2, 1.5)), closeTo(3, 1e-9));
      expect(Geometry.area(lShape), closeTo(5, 1e-9));
      expect(Geometry.area(rect(2, 1.5).reversed.toList()), closeTo(3, 1e-9));
    });

    test('simple polygon', () {
      expect(Geometry.isSimple(lShape), isTrue);
      expect(Geometry.isSimple(const [Offset(0, 0), Offset(2, 2), Offset(2, 0), Offset(0, 2)]), isFalse); // bow tie
      expect(Geometry.isSimple(const [Offset(0, 0), Offset(1, 0), Offset(2, 0)]), isFalse); // flat
      expect(Geometry.isSimple(const [Offset(0, 0), Offset(2, 0), Offset(1, 0), Offset(1, 1)]), isFalse); // back on the line
    });

    test('contains, inside, overlap', () {
      expect(Geometry.contains(lShape, const Offset(0.5, 0.5)), isTrue);
      expect(Geometry.contains(lShape, const Offset(2, 1)), isFalse);
      expect(Geometry.isInside(rect(3, 1, 0, 2), lShape), isTrue);
      expect(Geometry.isInside(rect(3, 1.5, 0, 1.5), lShape), isFalse);
      expect(Geometry.overlap(rect(1, 1), rect(1, 1, 1, 0)), isFalse); // shared border
      expect(Geometry.overlap(rect(2, 2), rect(2, 2, 1, 1)), isTrue);
      expect(Geometry.overlap(rect(3, 3), rect(1, 1, 1, 1)), isTrue);
    });

    test('the label of an L shape is inside the L', () {
      expect(Geometry.contains(lShape, Geometry.labelPoint(lShape)), isTrue);
      expect(Geometry.labelPoint(rect(2, 2)), const Offset(1, 1));
    });
  });

  group('plan rules', () {
    test('snap to 10 cm without floating point noise', () {
      expect(PlanGeometry.snap(0.34), 0.3);
      expect(PlanGeometry.snap(1.25), 1.3);
      expect(PlanGeometry.snap(0.1 + 0.2), 0.3);
      expect(PlanGeometry.snapPoint(const Offset(1.04, 2.96)), const Offset(1, 3));
    });

    test('the garden plan fits the parcels plus a margin, with a minimum size', () {
      expect(PlanGeometry.gardenWorld(const []), const Rect.fromLTWH(0, 0, 6, 6));
      expect(PlanGeometry.gardenWorld([rect(2, 1, 7, 3)]), const Rect.fromLTWH(0, 0, 9 + PlanGeometry.margin, 6));
    });

    test('valid shapes', () {
      expect(PlanGeometry.isValidShape(rect(1, 1)), isTrue);
      expect(PlanGeometry.isValidShape(rect(0.05, 0.05)), isFalse); // too small
      expect(PlanGeometry.isValidShape(const [Offset(0, 0), Offset(1, 1)]), isFalse);
    });

    test('automatic names take the first free number', () {
      expect(PlanGeometry.nextName('Parcelle', const []), 'Parcelle 1');
      expect(PlanGeometry.nextName('Parcelle', const ['Parcelle 1', 'Potager']), 'Parcelle 3');
      expect(PlanGeometry.nextName('Zone', const ['Zone 2']), 'Zone 3');
    });

    test('top-most shape at a point', () {
      final shapes = [(1, rect(3, 3)), (2, rect(1, 1, 1, 1))];
      expect(PlanGeometry.shapeAt(shapes, const Offset(1.5, 1.5)), 2);
      expect(PlanGeometry.shapeAt(shapes, const Offset(0.5, 0.5)), 1);
      expect(PlanGeometry.shapeAt(shapes, const Offset(5, 5)), isNull);
    });
  });
}
