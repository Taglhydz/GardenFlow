import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:GardenFlow/models/crop.dart';
import 'package:GardenFlow/models/garden.dart';
import 'package:GardenFlow/models/parcel.dart';
import 'package:GardenFlow/models/suggestion.dart';
import 'package:GardenFlow/models/zone.dart';
import 'package:GardenFlow/utils/plan_geometry.dart';
import 'package:GardenFlow/widgets/shape_canvas.dart';
import 'app_harness.dart';
import 'fakes.dart';

List<Offset> rect(double w, double h, [double x = 0, double y = 0]) =>
    [Offset(x, y), Offset(x + w, y), Offset(x + w, y + h), Offset(x, y + h)];

/// Garden plan, parcel plan (zones) and zone screen on the real app.
void main() {
  late FakeServices services;

  setUpAll(initTestApp);

  setUp(() {
    services = FakeServices();
    services.auth.restoreResult = alice;
    services.gardens.gardens = [const Garden(id: 7, userId: 1, name: 'Mon potager')];
  });

  /// Screen position of a point of the plan (meters), like ShapeCanvas computes it.
  Offset toScreen(WidgetTester tester, Offset meters) {
    final canvas = tester.widget<ShapeCanvas>(find.byType(ShapeCanvas));
    final box = tester.getRect(find.byType(ShapeCanvas));
    final world = canvas.world;
    final ppm = math.min(box.width / world.width, box.height / world.height);
    return box.topLeft + (meters - world.topLeft) * ppm;
  }

  Future<void> tapAt(WidgetTester tester, Offset meters) async {
    await tester.tapAt(toScreen(tester, meters));
    await tester.pumpAndSettle();
  }

  Future<void> dragAt(WidgetTester tester, Offset fromMeters, Offset byMeters) async {
    final from = toScreen(tester, fromMeters);
    await tester.dragFrom(from, toScreen(tester, fromMeters + byMeters) - from);
    await tester.pumpAndSettle();
  }

  group('garden plan', () {
    testWidgets('draw a parcel by placing its corners : created with an automatic name and selected', (tester) async {
      await pumpApp(tester, services);

      await tester.tap(find.text('Dessiner une parcelle'));
      await tester.pumpAndSettle();
      expect(find.textContaining('poser chaque coin'), findsOneWidget);

      for (final corner in const [Offset(1, 1), Offset(3, 1), Offset(3, 2), Offset(1, 2)]) {
        await tapAt(tester, corner);
      }
      // tapping the first point closes the shape
      await tapAt(tester, const Offset(1, 1));

      final fields = services.parcels.created.single;
      expect(fields['name'], 'Parcelle 1');
      expect(fields['pos_x'], 1);
      expect(fields['pos_y'], 1);
      expect(shapeFromJson(fields['shape']), rect(2, 1));
      expect(find.text('Ouvrir'), findsOneWidget); // the new parcel is selected
    });

    testWidgets('a self-crossing drawing is refused', (tester) async {
      await pumpApp(tester, services);

      await tester.tap(find.text('Dessiner une parcelle'));
      await tester.pumpAndSettle();
      for (final corner in const [Offset(1, 1), Offset(3, 3), Offset(3, 1), Offset(1, 3)]) {
        await tapAt(tester, corner);
      }
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();

      expect(find.text('Forme invalide : les côtés ne doivent pas se croiser.'), findsOneWidget);
      expect(services.parcels.created, isEmpty);
    });

    testWidgets('move a parcel : only its position changes (its zones follow)', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2))];
      await pumpApp(tester, services);

      await tapAt(tester, const Offset(2, 2)); // select
      await dragAt(tester, const Offset(2, 2), const Offset(1.03, 0.5));

      final (id, changes) = services.parcels.updates.single;
      expect(id, 1);
      expect(changes, {'pos_x': 2.0, 'pos_y': 1.5});
    });

    testWidgets('drag a corner : new shape, same position', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2))];
      await pumpApp(tester, services);

      await tapAt(tester, const Offset(2, 2));
      await dragAt(tester, const Offset(3, 3), const Offset(1, 0)); // bottom-right corner

      final (_, changes) = services.parcels.updates.single;
      expect(changes.keys, ['shape']);
      expect(shapeFromJson(changes['shape']), const [Offset(0, 0), Offset(2, 0), Offset(3, 2), Offset(0, 2)]);
    });

    testWidgets('long press on a corner removes it', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2))];
      await pumpApp(tester, services);

      await tapAt(tester, const Offset(2, 2));
      await tester.longPressAt(toScreen(tester, const Offset(3, 3)));
      await tester.pumpAndSettle();

      final (_, changes) = services.parcels.updates.single;
      expect(shapeFromJson(changes['shape']), const [Offset(0, 0), Offset(2, 0), Offset(0, 2)]);
    });
  });

  group('parcel plan and zones', () {
    setUp(() {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2), soilType: 'humus')];
    });

    Future<void> openParcel(WidgetTester tester) async {
      await pumpApp(tester, services);
      await tapAt(tester, const Offset(2, 2)); // select
      await tapAt(tester, const Offset(2, 2)); // tap again : go inside
      expect(find.text('Dessiner une zone'), findsOneWidget);
    }

    testWidgets('draw a zone inside the parcel', (tester) async {
      await openParcel(tester);

      await tester.tap(find.text('Dessiner une zone'));
      await tester.pumpAndSettle();
      // the parcel plan is relative to the parcel : its shape goes from (0, 0) to (2, 2)
      for (final corner in const [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)]) {
        await tapAt(tester, corner);
      }
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();

      final zone = services.zones.zones.single;
      expect(zone.name, 'Zone 1');
      expect(zone.parcelId, 1);
      expect(zone.shape, rect(1, 1));
    });

    testWidgets('a zone outside the parcel or overlapping another zone is refused', (tester) async {
      services.zones.zones = [Zone(id: 70, parcelId: 1, name: 'Rang 1', shape: rect(1, 2))];
      await openParcel(tester);

      await tester.tap(find.text('Dessiner une zone'));
      await tester.pumpAndSettle();
      for (final corner in const [Offset(1.5, 0), Offset(2.4, 0), Offset(2.4, 1), Offset(1.5, 1)]) {
        await tapAt(tester, corner);
      }
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();
      expect(find.text("La zone doit être à l'intérieur de la parcelle."), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dessiner une zone'));
      await tester.pumpAndSettle();
      for (final corner in const [Offset(0.5, 0), Offset(1.5, 0), Offset(1.5, 1), Offset(0.5, 1)]) {
        await tapAt(tester, corner);
      }
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();
      expect(find.text('La zone chevauche une autre zone.'), findsOneWidget);

      expect(services.zones.zones, hasLength(1));
    });

    testWidgets('open a zone : its crops and its own suggestions, planting goes into the zone', (tester) async {
      services.zones.zones = [
        Zone(id: 70, parcelId: 1, name: 'Rang 1', shape: rect(1, 2), areaM2: 2),
        Zone(id: 71, parcelId: 1, name: 'Rang 2', shape: rect(1, 2, 1, 0), areaM2: 2),
      ];
      services.crops.crops = [const Crop(id: 10, parcelId: 1, zoneId: 70, plantId: 1)];
      services.zones.suggestions = const [
        Suggestion(
          plantId: 2,
          plantCode: 'basil',
          score: 83,
          actions: ['sow_outdoor'],
          reasons: [
            SuggestionReason(code: 'good_in_parcel', impact: 'positive', params: {'plant_code': 'tomato'}),
            SuggestionReason(code: 'capacity', impact: 'info', params: {'count': 32}),
          ],
        ),
      ];
      await openParcel(tester);

      // the plants in the ground are written in their zone
      expect(find.byType(ShapeCanvas), findsOneWidget);

      await tapAt(tester, const Offset(1.5, 1)); // select "Rang 2"
      await tapAt(tester, const Offset(1.5, 1)); // open it
      expect(find.text('Rang 2'), findsOneWidget);
      expect(find.text('Aucune culture ici'), findsOneWidget); // the tomato is in "Rang 1"

      await tester.tap(find.text('Suggestions'));
      await tester.pumpAndSettle();
      expect(services.zones.suggestionsAskedFor, contains(71));
      expect(find.text('Bonne association avec Tomate (ailleurs dans la parcelle)'), findsOneWidget);
      expect(find.text('Environ 32 plants tiennent ici'), findsOneWidget);

      await tester.tap(find.text('Planter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      final planted = services.crops.crops.last;
      expect(planted.plantId, 2);
      expect(planted.zoneId, 71);
    });

    testWidgets('whole parcel : every crop with the name of its zone', (tester) async {
      services.zones.zones = [Zone(id: 70, parcelId: 1, name: 'Rang 1', shape: rect(1, 2))];
      services.crops.crops = [
        const Crop(id: 10, parcelId: 1, zoneId: 70, plantId: 1),
        const Crop(id: 11, parcelId: 1, plantId: 2),
      ];
      await openParcel(tester);

      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toute la parcelle').last);
      await tester.pumpAndSettle();

      expect(find.text('Tomate'), findsOneWidget);
      expect(find.text('Basilic'), findsOneWidget);
      expect(find.textContaining('Rang 1'), findsOneWidget);
      expect(find.textContaining('Sans zone'), findsOneWidget);
    });
  });

  test('the plan starts at 6 x 6 m', () => expect(PlanGeometry.gardenWorld(const []).size, const Size(6, 6)));
}
