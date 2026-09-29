import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:GardenFlow/models/crop.dart';
import 'package:GardenFlow/models/garden.dart';
import 'package:GardenFlow/models/parcel.dart';
import 'package:GardenFlow/models/suggestion.dart';
import 'package:GardenFlow/models/zone.dart';
import 'package:GardenFlow/utils/plan_geometry.dart';
import 'package:GardenFlow/utils/plant_colors.dart';
import 'package:GardenFlow/widgets/plan_bottom_slot.dart';
import 'package:GardenFlow/widgets/plant_color_sheet.dart';
import 'package:GardenFlow/widgets/shape_canvas.dart';
import 'package:GardenFlow/widgets/snap_button.dart';
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

  /// Screen position of a point of the plan (meters), computed by the plan on the screen.
  Offset toScreen(WidgetTester tester, Offset meters) =>
      tester.state<ShapeCanvasState>(find.byType(ShapeCanvas)).toGlobal(meters)!;

  Future<void> tapAt(WidgetTester tester, Offset meters) async {
    await tester.tapAt(toScreen(tester, meters));
    await tester.pumpAndSettle();
  }

  Future<void> chooseSnap(WidgetTester tester, String label) async {
    await tester.tap(find.byType(SnapButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<int>, label));
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

      // the plan glided to the new parcel : centered above its bar
      final box = tester.getRect(find.byType(ShapeCanvas));
      final bottom = tester.getRect(find.byType(PlanBottomSlot));
      final center = toScreen(tester, const Offset(2, 1.5));
      expect(center.dx, closeTo(box.center.dx, 1));
      expect(center.dy, closeTo((box.top + bottom.top) / 2, 1));
    });

    testWidgets('a parcel drawn far from the others : the plan doesn\'t jump, then glides to it', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2))];
      await pumpApp(tester, services);

      await tester.tap(find.text('Dessiner une parcelle'));
      await tester.pumpAndSettle();
      // beyond the view of the garden : the new parcel makes it grow
      final corners = const [Offset(5.5, 2), Offset(6.5, 2), Offset(6.5, 3), Offset(5.5, 3)];
      for (final corner in corners) {
        await tapAt(tester, corner);
      }
      final before = toScreen(tester, const Offset(1, 1));
      await tester.tap(find.text('Terminer'));
      await tester.pump();
      expect(toScreen(tester, const Offset(1, 1)), before); // same zoom, same place

      await tester.pumpAndSettle();
      final box = tester.getRect(find.byType(ShapeCanvas));
      final bottom = tester.getRect(find.byType(PlanBottomSlot));
      final center = toScreen(tester, const Offset(6, 2.5));
      expect(center.dx, closeTo(box.center.dx, 1));
      expect(center.dy, closeTo((box.top + bottom.top) / 2, 1));
    });

    testWidgets('the name of a parcel is written above its top-left corner', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2))];
      await pumpApp(tester, services);

      final shape = tester.widget<ShapeCanvas>(find.byType(ShapeCanvas)).shapes.single;
      expect(shape.tag, 'Carré A');
      expect(shape.labels, isEmpty); // the inside is left to the plants of the zones
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

    testWidgets('no corner on an existing parcel, no parcel around another one', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2))];
      await pumpApp(tester, services);

      await tester.tap(find.text('Dessiner une parcelle'));
      await tester.pumpAndSettle();
      await tapAt(tester, const Offset(2, 2)); // inside "Carré A"
      expect(find.text('Ce point est sur une parcelle existante.'), findsOneWidget);
      expect(find.text('Terminer'), findsOneWidget);

      // around "Carré A" : every corner is outside, but the shape covers it
      for (final corner in const [Offset(0.5, 0.5), Offset(4, 0.5), Offset(4, 4), Offset(0.5, 4)]) {
        await tapAt(tester, corner);
      }
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();
      expect(find.text('La parcelle chevauche une autre parcelle.'), findsOneWidget);
      expect(services.parcels.created, isEmpty);
    });

    testWidgets('a parcel drawn next to another one shares its side', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2))];
      await pumpApp(tester, services);

      await chooseSnap(tester, '5 cm'); // the grid alone would put the corners at x = 3.05
      await tester.tap(find.text('Dessiner une parcelle'));
      await tester.pumpAndSettle();
      // a few cm from the right side of "Carré A" (x = 3) : the corners stick to it
      for (final corner in const [Offset(3.04, 1), Offset(4, 1), Offset(4, 2), Offset(3.04, 2)]) {
        await tapAt(tester, corner);
      }
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();

      expect(services.parcels.created.single['pos_x'], 3);
    });

    testWidgets('the plan opens centered on the parcels (above the bottom button), even far from the corner', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 40, posY: 30, shape: rect(4, 2))];
      await pumpApp(tester, services);

      final box = tester.getRect(find.byType(ShapeCanvas));
      final bottom = tester.getRect(find.byType(PlanBottomSlot));
      final center = toScreen(tester, const Offset(42, 31));
      expect(center.dx, closeTo(box.center.dx, 1));
      expect(center.dy, closeTo((box.top + bottom.top) / 2, 1));
    });

    testWidgets('selecting a parcel : its bar comes up from the bottom, the plan doesn\'t move when the parcel is still seen', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2))];
      await pumpApp(tester, services);
      final before = toScreen(tester, const Offset(2, 2));
      final plan = tester.getRect(find.byType(ShapeCanvas));

      await tester.tapAt(before);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      // the bar is on its way up, over the plan : the plan still goes to the bottom of the screen
      final bar = tester.getRect(find.text('Ouvrir'));
      expect(tester.getRect(find.byType(ShapeCanvas)).bottom, plan.bottom);

      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Ouvrir')).top, lessThan(bar.top)); // it came up
      // the parcel is above the bar : same place on the plan (the help, now on two lines, only pushed the plan down)
      final after = toScreen(tester, const Offset(2, 2));
      expect(after - tester.getRect(find.byType(ShapeCanvas)).topLeft, before - plan.topLeft);

      // unselected : the button comes back up from the bottom
      await tester.tapAt(toScreen(tester, const Offset(4.5, 0)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final button = tester.getRect(find.text('Dessiner une parcelle'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Dessiner une parcelle')).top, lessThan(button.top));
    });

    testWidgets('selecting a parcel partly hidden by its bar : the plan glides to show it', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2))];
      await pumpApp(tester, services);

      // the plan moved down : the bottom of the parcel is where the bar will be
      final barTop = tester.getRect(find.byType(PlanBottomSlot)).top;
      await tester.dragFrom(toScreen(tester, const Offset(4.5, 0.5)), Offset(0, barTop + 40 - toScreen(tester, const Offset(2, 3)).dy));
      await tester.pumpAndSettle();
      expect(toScreen(tester, const Offset(2, 3)).dy, greaterThan(barTop));

      await tapAt(tester, const Offset(2, 1.5));
      final bottom = tester.getRect(find.byType(PlanBottomSlot));
      expect(toScreen(tester, const Offset(2, 3)).dy, lessThanOrEqualTo(bottom.top));
      expect(toScreen(tester, const Offset(2, 1)).dy, greaterThanOrEqualTo(tester.getRect(find.byType(ShapeCanvas)).top));
    });

    testWidgets('a parcel selected : a drag outside of it moves the plan, not the parcel', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2))];
      await pumpApp(tester, services);
      await tapAt(tester, const Offset(2, 2)); // select

      final before = toScreen(tester, const Offset(2, 2));
      await tester.dragFrom(toScreen(tester, const Offset(4.5, 0.5)), const Offset(-80, 60));
      await tester.pumpAndSettle();

      // the start of the drag (slop) doesn't move the plan : the rest does
      final moved = toScreen(tester, const Offset(2, 2)) - before;
      expect(moved.dx, lessThan(-40));
      expect(moved.dy, greaterThan(30));
      expect(services.parcels.updates, isEmpty);
      expect(find.text('Ouvrir'), findsOneWidget); // still selected
    });

    testWidgets('delete a parcel from its edit sheet, after a confirmation', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2))];
      await pumpApp(tester, services);
      await tapAt(tester, const Offset(2, 2)); // select

      await tester.tap(find.byTooltip('Modifier la parcelle'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Annuler'))); // changed my mind
      await tester.pumpAndSettle();
      expect(services.parcels.parcels, hasLength(1));
      expect(find.text('Enregistrer'), findsOneWidget); // the sheet is still open

      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Supprimer la parcelle « Carré A »'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Supprimer')));
      await tester.pumpAndSettle();

      expect(services.parcels.parcels, isEmpty);
      expect(find.text('Enregistrer'), findsNothing); // the sheet closed
      expect(find.text('Dessiner une parcelle'), findsOneWidget); // nothing selected any more
    });

    testWidgets('opening a parcel : it grows out of its shape on the garden plan, and back when closing', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2))];
      await pumpApp(tester, services);
      await tapAt(tester, const Offset(2, 2));

      await tester.tap(find.text('Ouvrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      // early : the parcel plan is still around the parcel, the garden is seen around it
      expect(find.byType(ShapeCanvas), findsNWidgets(2));
      final earlyButton = tester.getRect(find.text('Dessiner une zone'));
      await tester.pumpAndSettle();
      expect(earlyButton.top, greaterThan(tester.getRect(find.text('Dessiner une zone')).top)); // it came up

      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      expect(find.text('Dessiner une zone'), findsNothing);
      expect(find.byType(ShapeCanvas), findsOneWidget);
    });

    testWidgets('the plan moved far away comes back with the recenter button', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2))];
      await pumpApp(tester, services);

      final parcel = toScreen(tester, const Offset(2, 2));
      await tester.dragFrom(toScreen(tester, const Offset(4, 4)), const Offset(-600, -400));
      await tester.pumpAndSettle();
      final moved = toScreen(tester, const Offset(2, 2));
      expect(moved, isNot(parcel)); // the plan moved

      // the plan glides back : halfway through, it is between where it was and the center
      await tester.tap(find.byTooltip('Recentrer le plan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final halfway = toScreen(tester, const Offset(2, 2));
      expect(halfway, isNot(moved));
      expect(halfway, isNot(parcel));
      await tester.pumpAndSettle();
      expect(toScreen(tester, const Offset(2, 2)), parcel); // back exactly where it opened
      final box = tester.getRect(find.byType(ShapeCanvas));
      expect(box.contains(toScreen(tester, const Offset(2, 2))), isTrue);

      await tapAt(tester, const Offset(2, 2)); // the parcel can be selected again
      expect(find.text('Ouvrir'), findsOneWidget);
    });

    testWidgets('the help can be closed and shown again with the "i"', (tester) async {
      await pumpApp(tester, services);
      expect(find.textContaining('Dessiner une parcelle »'), findsOneWidget);

      await tester.tap(find.byTooltip("Masquer l'aide"));
      await tester.pumpAndSettle();
      expect(find.textContaining('Dessiner une parcelle »'), findsNothing);
      expect((await SharedPreferences.getInstance()).getStringList('hidden_help'), ['garden']);

      await tester.tap(find.byTooltip("Afficher l'aide"));
      await tester.pumpAndSettle();
      expect(find.textContaining('Dessiner une parcelle »'), findsOneWidget);
      expect(find.byTooltip("Afficher l'aide"), findsNothing);
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
      expect(zone.name, isNull); // automatic name
      expect(find.text('Ajouter une plante'), findsOneWidget); // no plant yet (bar of the selected zone)
      expect(zone.parcelId, 1);
      expect(zone.shape, rect(1, 1));
    });

    testWidgets('a tap snapped onto a placed point : closes on the first one, ignored on another one', (tester) async {
      await openParcel(tester);

      await tester.tap(find.text('Dessiner une zone'));
      await tester.pumpAndSettle();
      await tapAt(tester, const Offset(0, 0));
      await tapAt(tester, const Offset(1, 0));
      await tapAt(tester, const Offset(1.1, 0.1)); // snapped onto (1, 0) again : nothing added
      await tapAt(tester, const Offset(1, 1));
      await tapAt(tester, const Offset(0, 1));
      // too far from the first point to close it, but the 50 cm grid snaps it there : the zone is closed
      await tapAt(tester, const Offset(0.2, 0.2));

      expect(find.textContaining('se croiser'), findsNothing);
      expect(services.zones.zones.single.shape, rect(1, 1));
    });

    testWidgets('a zone outside the parcel or overlapping another zone is refused', (tester) async {
      services.zones.zones = [Zone(id: 70, parcelId: 1, name: 'Rang 1', shape: rect(1, 2))];
      await openParcel(tester);

      await tester.tap(find.text('Dessiner une zone'));
      await tester.pumpAndSettle();
      // the parcel goes from (0, 0) to (2, 2) : a point outside is refused
      await tapAt(tester, const Offset(2.4, 0.5));
      expect(find.text("Placez les points à l'intérieur de la parcelle."), findsOneWidget);
      expect(tester.widget<ShapeCanvas>(find.byType(ShapeCanvas)).draft, isEmpty);

      // (0.5, 1) is inside "Rang 1" : refused, the 3 other corners make a triangle over "Rang 1"
      for (final corner in const [Offset(0.5, 0), Offset(1.5, 0), Offset(1.5, 1), Offset(0.5, 1)]) {
        await tapAt(tester, corner);
      }
      expect(tester.widget<ShapeCanvas>(find.byType(ShapeCanvas)).draft, hasLength(3));
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();
      expect(find.text('La zone chevauche une autre zone.'), findsOneWidget);

      expect(services.zones.zones, hasLength(1));
    });

    testWidgets('near a side of the parcel, a corner of the zone sticks to it ; not with the magnet off', (tester) async {
      await openParcel(tester);

      await chooseSnap(tester, '5 cm'); // the grid alone would give (1.85, 0.05)
      await tester.tap(find.text('Dessiner une zone'));
      await tester.pumpAndSettle();
      await tapAt(tester, const Offset(1.83, 0.03)); // 3 cm from the top side
      expect(tester.widget<ShapeCanvas>(find.byType(ShapeCanvas)).draft, const [Offset(1.85, 0)]);

      await chooseSnap(tester, 'Désactivé (au cm près)');
      await tapAt(tester, const Offset(1.97, 1.03));
      expect(tester.widget<ShapeCanvas>(find.byType(ShapeCanvas)).draft, const [Offset(1.85, 0), Offset(1.97, 1.03)]);
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

    testWidgets('automatic zone names from their plant, numbered ; a name typed is kept, an empty one brings it back', (tester) async {
      services.zones.zones = [
        Zone(id: 70, parcelId: 1, shape: rect(1, 2)),
        Zone(id: 71, parcelId: 1, shape: rect(1, 1, 1, 0)),
        Zone(id: 72, parcelId: 1, shape: rect(1, 1, 1, 1)),
      ];
      services.crops.crops = [
        const Crop(id: 10, parcelId: 1, zoneId: 70, plantId: 1),
        const Crop(id: 11, parcelId: 1, zoneId: 71, plantId: 1),
      ];
      await openParcel(tester);

      await tapAt(tester, const Offset(0.5, 1));
      expect(find.text('Zone Tomate'), findsOneWidget);
      await tapAt(tester, const Offset(1.5, 0.5));
      expect(find.text('Zone Tomate 2'), findsOneWidget);
      await tapAt(tester, const Offset(1.5, 1.5));
      expect(find.text('Ajouter une plante'), findsOneWidget);

      Future<void> rename(String name) async {
        await tester.tap(find.byTooltip('Renommer la zone'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), name);
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();
      }

      await rename('Carottes');
      expect(services.zones.zones.last.name, 'Carottes');
      expect(find.text('Carottes'), findsOneWidget);

      await rename('');
      expect(services.zones.zones.last.name, isNull);
      expect(find.text('Ajouter une plante'), findsOneWidget);
    });

    testWidgets('the red bin deletes the parcel after a confirmation', (tester) async {
      await openParcel(tester);

      await tester.tap(find.byTooltip('Supprimer la parcelle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler')); // changed my mind
      await tester.pumpAndSettle();
      expect(services.parcels.parcels, hasLength(1));

      await tester.tap(find.byTooltip('Supprimer la parcelle'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Supprimer la parcelle « Carré A »'), findsOneWidget);
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(services.parcels.parcels, isEmpty);
      expect(find.text('Dessiner une parcelle'), findsOneWidget); // back to the garden plan
    });

    testWidgets('delete the parcel from its edit sheet : back to the garden plan', (tester) async {
      await openParcel(tester);

      await tester.tap(find.byTooltip('Modifier la parcelle'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Supprimer')));
      await tester.pumpAndSettle();

      expect(services.parcels.parcels, isEmpty);
      expect(find.text('Dessiner une zone'), findsNothing);
      expect(find.text('Dessiner une parcelle'), findsOneWidget);
    });

    testWidgets('rename a zone, then close the dialog by tapping outside : no crash, nothing saved', (tester) async {
      services.zones.zones = [Zone(id: 70, parcelId: 1, name: 'Rang 1', shape: rect(1, 2))];
      await openParcel(tester);
      await tapAt(tester, const Offset(0.5, 1)); // select the zone

      await tester.tap(find.byTooltip('Renommer la zone'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5)); // outside the dialog
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(services.zones.zones.single.name, 'Rang 1');
    });

    testWidgets('all the plants of the parcel : button at the bottom left, every crop with the name of its zone', (tester) async {
      services.zones.zones = [Zone(id: 70, parcelId: 1, name: 'Rang 1', shape: rect(1, 2))];
      services.crops.crops = [
        const Crop(id: 10, parcelId: 1, zoneId: 70, plantId: 1),
        const Crop(id: 11, parcelId: 1, plantId: 2),
      ];
      await openParcel(tester);

      final button = find.widgetWithText(FloatingActionButton, 'Toutes les plantes');
      // at the bottom left, the "draw a zone" button at the bottom right
      expect(tester.getCenter(button).dx, lessThan(tester.getCenter(find.text('Dessiner une zone')).dx));
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Toutes les plantes'), findsOneWidget); // title of the screen

      expect(find.text('Tomate'), findsOneWidget);
      expect(find.text('Basilic'), findsOneWidget);
      expect(find.textContaining('Rang 1'), findsOneWidget);
      expect(find.textContaining('Sans zone'), findsOneWidget);
    });

    testWidgets('all the plants : the color of a plant can be changed, a message tells when another plant has it', (tester) async {
      services.zones.zones = [Zone(id: 70, parcelId: 1, name: 'Rang 1', shape: rect(1, 2))];
      services.crops.crops = [
        const Crop(id: 10, parcelId: 1, zoneId: 70, plantId: 1),
        const Crop(id: 11, parcelId: 1, plantId: 2),
      ];
      await openParcel(tester);
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Toutes les plantes'));
      await tester.pumpAndSettle();

      // each plant in its color of the plan
      final dots = tester.widgetList<PlantColorDot>(find.byType(PlantColorDot)).map((d) => d.hue).toList();
      expect(dots, containsAll([PlantColors.automaticHue(services.plants.plants[0]), PlantColors.automaticHue(services.plants.plants[1])]));

      // the tomato takes a color close to the one of the basil (automatic, ~275 degrees)
      await tester.tap(find.byTooltip('Changer la couleur').first);
      await tester.pumpAndSettle();
      expect(find.text('Couleur : Tomate'), findsOneWidget);
      expect(find.textContaining('Même couleur que'), findsNothing);

      await tester.tap(find.byWidgetPredicate((w) => w is PlantColorDot && w.hue == 280 && w.size == 40));
      await tester.pumpAndSettle();
      expect(services.plants.colors, {1: 280});
      expect(find.textContaining('Même couleur que Basilic'), findsOneWidget);

      // back to its automatic color
      await tester.tap(find.byTooltip('Automatique'));
      await tester.pumpAndSettle();
      expect(services.plants.colors, isEmpty);
      expect(find.textContaining('Même couleur que'), findsNothing);
    });
  });

  group('magnet and dimensions', () {
    Future<void> drawRectangle(WidgetTester tester, List<Offset> corners) async {
      await tester.tap(find.text('Dessiner une parcelle'));
      await tester.pumpAndSettle();
      for (final corner in corners) {
        await tapAt(tester, corner);
      }
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();
    }

    /// Types [value] in the field of the dimensions sheet with the key [key] (side_0, position_x…).
    Future<void> type(WidgetTester tester, String key, String value) async {
      final field = find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
    }

    testWidgets('magnet off : the corners go where the finger is (to the cm), the choice is remembered', (tester) async {
      await pumpApp(tester, services);
      expect(find.text('50 cm'), findsOneWidget); // default grid

      await chooseSnap(tester, 'Désactivé (au cm près)');
      expect(find.text('Libre'), findsOneWidget);
      await drawRectangle(tester, const [Offset(1.03, 1.07), Offset(3.02, 1.07), Offset(3.02, 2.04), Offset(1.03, 2.04)]);

      final fields = services.parcels.created.single;
      expect(fields['pos_x'], 1.03);
      expect(fields['pos_y'], 1.07);
      expect(shapeFromJson(fields['shape']), rect(1.99, 0.97));
      expect((await SharedPreferences.getInstance()).getInt('snap_cm'), -50); // off, the 50 cm step is kept
    });

    testWidgets('50 cm grid : the corners go to the nearest 50 cm', (tester) async {
      await pumpApp(tester, services);

      await chooseSnap(tester, '50 cm');
      await drawRectangle(tester, const [Offset(1.2, 1.3), Offset(2.9, 1.3), Offset(2.9, 2.2), Offset(1.2, 2.2)]);

      final fields = services.parcels.created.single;
      expect(fields['pos_x'], 1);
      expect(fields['pos_y'], 1.5);
      expect(shapeFromJson(fields['shape']), rect(2, 0.5));
    });

    testWidgets('dimensions of a parcel : typed sides and position saved in one request', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2))];
      await pumpApp(tester, services);

      await tapAt(tester, const Offset(2, 2)); // select
      await tester.tap(find.byTooltip('Mesures'));
      await tester.pumpAndSettle();
      expect(find.text('Mesures de « Carré A »'), findsOneWidget);

      await type(tester, 'side_0', '3'); // A -> B : 2 m -> 3 m
      await type(tester, 'position_x', '0,5');
      await save(tester);

      final (id, changes) = services.parcels.updates.single;
      expect(id, 1);
      expect(changes['pos_x'], 0.5);
      expect(changes['pos_y'], 1);
      expect(shapeFromJson(changes['shape']), rect(3, 2));
    });

    testWidgets('dimensions of a parcel : a size that leaves a zone outside is refused in the sheet', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2))];
      services.zones.zones = [Zone(id: 70, parcelId: 1, name: 'Rang 2', shape: rect(1, 2, 1, 0))];
      await pumpApp(tester, services);

      await tapAt(tester, const Offset(1.5, 1.5));
      await tester.tap(find.byTooltip('Mesures'));
      await tester.pumpAndSettle();
      await type(tester, 'side_0', '1,5');
      await save(tester);

      expect(find.text('Cette forme laisserait des zones en dehors de la parcelle.'), findsOneWidget);
      expect(services.parcels.updates, isEmpty);
    });

    testWidgets('dimensions of a zone : checked against the parcel, then saved', (tester) async {
      services.parcels.parcels = [Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 1, posY: 1, shape: rect(2, 2))];
      services.zones.zones = [Zone(id: 70, parcelId: 1, name: 'Rang 1', shape: rect(1, 2))];
      await pumpApp(tester, services);
      await tapAt(tester, const Offset(2, 2));
      await tapAt(tester, const Offset(2, 2)); // inside the parcel

      await tapAt(tester, const Offset(0.5, 1)); // select the zone
      await tester.tap(find.byTooltip('Mesures'));
      await tester.pumpAndSettle();

      await type(tester, 'side_0', '3');
      await save(tester);
      expect(find.text("La zone doit être à l'intérieur de la parcelle."), findsOneWidget);

      await type(tester, 'side_0', '1,5');
      await save(tester);
      expect(services.zones.zones.single.shape, rect(1.5, 2));
    });
  });

  test('the plan opens on 6 x 6 m', () => expect(PlanGeometry.gardenView(const []).size, const Size(6, 6)));
}
