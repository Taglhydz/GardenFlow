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

    test('snap to the chosen step, 1 cm = no magnet', () {
      expect(PlanGeometry.snap(0.34, 5), 0.35);
      expect(PlanGeometry.snap(1.3, 25), 1.25);
      expect(PlanGeometry.snap(1.3, 50), 1.5);
      expect(PlanGeometry.snap(1.7, 100), 2);
      expect(PlanGeometry.snap(1.234, 1), 1.23);
      expect(PlanGeometry.roundCm(const Offset(0.1 + 0.2, 2.005)), const Offset(0.3, 2.01));
    });

    test('corner names', () {
      expect([for (var i = 0; i < 4; i++) PlanGeometry.cornerName(i)], ['A', 'B', 'C', 'D']);
      expect(PlanGeometry.cornerName(25), 'Z');
      expect(PlanGeometry.cornerName(26), 'A2');
    });

    group('side length', () {
      test('a rectangle stays a rectangle : the far side moves with the corner', () {
        // A -> B from 2 m to 3 m : B and C move to the right
        expect(PlanGeometry.setSideLength(rect(2, 1), 0, 3), rect(3, 1));
        // B -> C from 1 m to 1.5 m : C and D move down
        expect(PlanGeometry.setSideLength(rect(2, 1), 1, 1.5), rect(2, 1.5));
        // C -> D goes to the left : shortening it moves D and A to the right, B and C don't move
        expect(PlanGeometry.setSideLength(rect(2, 1), 2, 1.2), rect(1.2, 1, 0.8, 0));
        // D -> A (the closing side) goes up : A and B move
        expect(PlanGeometry.setSideLength(rect(2, 1), 3, 2), rect(2, 2, 0, -1));
      });

      test('L shape : only the corners at the end of the side or beyond move', () {
        // bottom D -> E (3,2)->(3,3) is vertical : from 1 m to 2 m, E and F go down
        final longer = PlanGeometry.setSideLength(lShape, 3, 2);
        expect(longer, const [Offset(0, 0), Offset(1, 0), Offset(1, 2), Offset(3, 2), Offset(3, 4), Offset(0, 4)]);
        expect(PlanGeometry.sideLength(longer, 3), 2);
      });

      test('the edited side gets exactly its length (rounded to the cm), even when slanted', () {
        const triangle = [Offset(0, 0), Offset(2, 0), Offset(1, 1)];
        final result = PlanGeometry.setSideLength(triangle, 0, 2.5);
        expect(result, const [Offset(0, 0), Offset(2.5, 0), Offset(1, 1)]);

        final slanted = PlanGeometry.setSideLength(triangle, 1, 2); // B -> C, 1.41 m
        expect(PlanGeometry.sideLength(slanted, 1), closeTo(2, 0.01));
        expect(slanted[1], const Offset(2, 0)); // the start of the side doesn't move
      });
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
