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
      expect(PlanGeometry.snap(0.34, 10), 0.3);
      expect(PlanGeometry.snap(1.25, 10), 1.3);
      expect(PlanGeometry.snap(0.1 + 0.2, 10), 0.3);
      expect(PlanGeometry.snapPoint(const Offset(1.04, 2.96), 10), const Offset(1, 3));
    });

    test('the magnet grid is 50 cm by default', () {
      expect(PlanGeometry.defaultSnapCm, 50);
      expect(PlanGeometry.snapPoint(const Offset(1.2, 1.3)), const Offset(1, 1.5));
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

    test('the garden plan opens on the parcels plus a margin, with a minimum size around them', () {
      expect(PlanGeometry.gardenView(const []), const Rect.fromLTWH(0, 0, 6, 6));
      // 2 x 1 m at (7, 3) + 2 m of margin : 6 x 5 m, made 6 m high around its center
      expect(PlanGeometry.gardenView([rect(2, 1, 7, 3)]), const Rect.fromLTRB(5, 0.5, 11, 6.5));
      // far from (0, 0) : only the parcels are shown
      expect(PlanGeometry.gardenView([rect(10, 8, 50, 40)]), const Rect.fromLTRB(48, 38, 62, 50));
    });

    test('the garden plan goes on for hundreds of meters beyond the farthest parcel', () {
      expect(PlanGeometry.gardenWorld(const []).size, const Size(6 + PlanGeometry.gardenExtent, 6 + PlanGeometry.gardenExtent));
      expect(PlanGeometry.gardenWorld([rect(2, 1, 300, 3)]).right, 302 + PlanGeometry.margin + PlanGeometry.gardenExtent);
    });

    group('sides', () {
      test('a point near a side sticks to it, on the grid when the side goes through it', () {
        // 0.1 m from the top side : goes on it, at the 50 cm of the grid
        expect(PlanGeometry.stickToBorder([rect(2, 2)], const Offset(0.6, 0.1), 0.2, 50), const Offset(0.5, 0));
        // near a corner : the corner
        expect(PlanGeometry.stickToBorder([rect(2, 2)], const Offset(1.9, 0.15), 0.2, 50), const Offset(2, 0));
        // too far from every side
        expect(PlanGeometry.stickToBorder([rect(2, 2)], const Offset(1, 1), 0.2, 50), isNull);
        // slanted side : the nearest point, to the cm
        const triangle = [Offset(0, 0), Offset(3, 0), Offset(0, 3)];
        final onSlant = PlanGeometry.stickToBorder([triangle], const Offset(1.3, 1.6), 0.2, 50)!;
        expect(PlanGeometry.isOnBorder([triangle], onSlant), isTrue);
      });

      test('keep inside : rounding just outside a slanted side is fixed, far outside is refused', () {
        const triangle = [Offset(0, 0), Offset(3, 0), Offset(0, 3)];
        final kept = PlanGeometry.keepInside(triangle, const Offset(1.51, 1.5))!;
        expect(Geometry.contains(triangle, kept), isTrue);
        expect((kept - const Offset(1.51, 1.5)).distance, lessThan(0.02));
        expect(PlanGeometry.keepInside(triangle, const Offset(2, 2)), isNull);
        expect(PlanGeometry.keepInside(rect(2, 2), const Offset(1, 1)), const Offset(1, 1));
      });

      test('inside a shape, not on its border', () {
        expect(PlanGeometry.isInsideAny([rect(2, 2)], const Offset(1, 1)), isTrue);
        expect(PlanGeometry.isInsideAny([rect(2, 2)], const Offset(1, 0)), isFalse);
        expect(PlanGeometry.isInsideAny([rect(2, 2)], const Offset(3, 1)), isFalse);
      });
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

    test('the name of a shape goes above its top-left corner, else to the first free place around it', () {
      final bounds = const Rect.fromLTWH(10, 10, 20, 10);
      const size = Size(8, 2);
      Rect place(List<List<Offset>> others, [List<Rect> taken = const []]) =>
          PlanGeometry.tagRect(bounds, size, 1, others, taken);

      expect(place(const []), const Rect.fromLTWH(10, 7, 8, 2));
      // a shape above-left of it : above its top-right corner
      final aboveLeft = rect(10, 5, 2, 3);
      expect(place([aboveLeft]), const Rect.fromLTWH(22, 7, 8, 2));
      // a shape all along its top : below it
      expect(place([rect(30, 5, 5, 3)]), const Rect.fromLTWH(10, 21, 8, 2));
      // the place above-left is taken by another name
      expect(place(const [], [const Rect.fromLTWH(5, 6, 8, 2)]), const Rect.fromLTWH(22, 7, 8, 2));
      // shapes all around : inside its top-left corner
      expect(place([rect(40, 5, 0, 3), rect(40, 5, 0, 22)]), const Rect.fromLTWH(11, 11, 8, 2));
      // a shape only touching the place (shared side) doesn't take it
      expect(place([rect(10, 3, 0, 4)]), const Rect.fromLTWH(10, 7, 8, 2));
    });

    test('a corner on the line between its neighbors is aligned', () {
      const shape = [Offset(0, 0), Offset(1, 0), Offset(2, 0), Offset(2, 2), Offset(0, 2)];
      expect(PlanGeometry.isAligned(shape, 1), isTrue);
      expect(PlanGeometry.isAligned(shape, 2), isFalse); // a real corner
      expect(PlanGeometry.isAligned(shape, 0), isFalse); // neighbors : the last and the second corners
      // on a slanted side, rounded to the cm
      expect(PlanGeometry.isAligned(const [Offset(0, 0), Offset(0.33, 0.67), Offset(1, 2), Offset(-1, 2)], 1), isTrue);
      // 5 cm away from the side : kept
      expect(PlanGeometry.isAligned(const [Offset(0, 0), Offset(1, 0.05), Offset(2, 0), Offset(2, 2)], 1), isFalse);
    });

    test('top-most shape at a point', () {
      final shapes = [(1, rect(3, 3)), (2, rect(1, 1, 1, 1))];
      expect(PlanGeometry.shapeAt(shapes, const Offset(1.5, 1.5)), 2);
      expect(PlanGeometry.shapeAt(shapes, const Offset(0.5, 0.5)), 1);
      expect(PlanGeometry.shapeAt(shapes, const Offset(5, 5)), isNull);
    });
  });
}
