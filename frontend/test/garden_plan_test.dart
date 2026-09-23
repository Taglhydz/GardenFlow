import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:GardenFlow/models/crop.dart';
import 'package:GardenFlow/models/garden.dart';
import 'package:GardenFlow/models/parcel.dart';
import 'package:GardenFlow/models/suggestion.dart';
import 'package:GardenFlow/widgets/garden_plan.dart';
import 'app_harness.dart';
import 'fakes.dart';

/// Garden plan, parcel screen and suggestions on the real app.
void main() {
  late FakeServices services;

  setUpAll(initTestApp);

  setUp(() {
    services = FakeServices();
    services.auth.restoreResult = alice;
    services.gardens.gardens = [const Garden(id: 7, userId: 1, name: 'Mon potager')];
    services.parcels.parcels = [
      const Parcel(id: 1, gardenId: 7, name: 'Carré A', posX: 0, posY: 0, width: 2, length: 2, soilType: 'humus'),
      const Parcel(id: 2, gardenId: 7, name: 'Carré B', posX: 3, posY: 0, width: 1, length: 2),
    ];
    services.crops.crops = [const Crop(id: 10, parcelId: 1, plantId: 1)];
  });

  Finder parcelTile(String name) => find.descendant(of: find.byType(GardenPlan), matching: find.text(name));

  testWidgets('the plan shows the parcels and the plants in the ground', (tester) async {
    await pumpApp(tester, services);

    expect(parcelTile('Carré A'), findsOneWidget);
    expect(parcelTile('Carré B'), findsOneWidget);
    expect(find.descendant(of: find.byType(GardenPlan), matching: find.text('Tomate')), findsOneWidget);
    expect(find.text('Touchez une parcelle pour la sélectionner. Pincez pour zoomer.'), findsOneWidget);
  });

  testWidgets('select a parcel, drag it : the new position is saved, snapped to 10 cm', (tester) async {
    await pumpApp(tester, services);

    await tester.tap(parcelTile('Carré B'));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);

    // 1 m of the plan in pixels : the plan width (5 m + 2 m margin) fits the screen width
    final plan = tester.getSize(find.byType(GardenPlan));
    final pixelsPerMeter = plan.width / 6; // world width = max(6, 4 m + 2 m margin)

    await tester.drag(parcelTile('Carré B'), Offset(pixelsPerMeter * 1.03, pixelsPerMeter * 0.5));
    await tester.pumpAndSettle();

    final (id, changes) = services.parcels.updates.single;
    expect(id, 2);
    expect(changes['pos_x'], 4.0);
    expect(changes['pos_y'], 0.5);
    expect(changes['width'], 1.0);
  });

  testWidgets('tap outside deselects, tap the selected parcel opens it', (tester) async {
    await pumpApp(tester, services);

    await tester.tap(parcelTile('Carré A'));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);

    await tester.tap(parcelTile('Carré A'));
    await tester.pumpAndSettle();

    // parcel screen : characteristics and crops
    expect(find.text('Cultures'), findsOneWidget);
    expect(find.text('Humifère'), findsOneWidget);
    expect(find.text('En terre'), findsOneWidget);
    expect(find.text('Tomate'), findsOneWidget);
  });

  testWidgets('suggestions tab : translated reasons and plant button', (tester) async {
    services.parcels.suggestions = const [
      Suggestion(
        plantId: 2,
        plantCode: 'basil',
        score: 87,
        actions: ['sow_outdoor'],
        reasons: [
          SuggestionReason(code: 'good_companion', impact: 'positive', params: {'plant_code': 'tomato'}),
          SuggestionReason(code: 'rotation_same_family', impact: 'negative', params: {'family': 'solanaceae', 'plant_code': 'tomato', 'months_ago': 9}),
        ],
      ),
    ];
    await pumpApp(tester, services);

    await tester.tap(parcelTile('Carré A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suggestions'));
    await tester.pumpAndSettle();

    expect(find.text('Basilic'), findsOneWidget);
    expect(find.text('87'), findsOneWidget);
    expect(find.text('Bonne association avec Tomate'), findsOneWidget);
    expect(find.text('Rotation : même famille (Solanacées) que Tomate, récoltée il y a 9 mois'), findsOneWidget);

    // "Planter" opens the crop form with the plant already chosen
    await tester.tap(find.text('Planter'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle culture'), findsOneWidget);
    expect(find.descendant(of: find.byType(InputDecorator), matching: find.text('Basilic')), findsOneWidget);

    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
    expect(services.crops.crops.last.plantId, 2);
    expect(services.crops.crops.last.parcelId, 1);
  });

  testWidgets('add a parcel : it is placed next to the others and selected', (tester) async {
    await pumpApp(tester, services);

    await tester.tap(find.text('Ajouter une parcelle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Aromatiques');
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();

    final created = services.parcels.parcels.last;
    expect(created.name, 'Aromatiques');
    expect(created.posX, 4.5); // right of "Carré B" (3 + 1) + 0.5 m
    expect(parcelTile('Aromatiques'), findsOneWidget);
    expect(find.text('Ouvrir'), findsOneWidget);
  });
}
