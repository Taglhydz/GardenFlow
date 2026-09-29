import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:GardenFlow/models/garden.dart';
import 'package:GardenFlow/screens/garden_view.dart';
import 'package:GardenFlow/services/api_service.dart';
import 'package:GardenFlow/widgets/garden_mini_map.dart';
import 'package:GardenFlow/widgets/shape_canvas.dart';
import 'app_harness.dart';
import 'fakes.dart';

/// Login, registration and startup flows on the real app.
void main() {
  late FakeServices services;

  setUpAll(initTestApp);
  setUp(() => services = FakeServices());

  testWidgets('no session -> login screen, translated', (tester) async {
    await pumpApp(tester, services);

    expect(find.text('Gérez votre jardin facilement'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('wrong password -> translated error message', (tester) async {
    await pumpApp(tester, services);

    await tester.enterText(find.byType(TextFormField).at(0), 'alice@test.dev');
    await tester.enterText(find.byType(TextFormField).at(1), 'bad');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Email ou mot de passe incorrect.'), findsOneWidget);
  });

  testWidgets('login -> home screen without gardens', (tester) async {
    await pumpApp(tester, services);

    await tester.enterText(find.byType(TextFormField).at(0), 'alice@test.dev');
    await tester.enterText(find.byType(TextFormField).at(1), 'good');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Aucun jardin pour le moment'), findsOneWidget);
  });

  testWidgets('restored session with one garden -> the garden is opened', (tester) async {
    services.auth.restoreResult = alice;
    services.gardens.gardens = [const Garden(id: 7, userId: 1, name: 'Mon potager')];

    await pumpApp(tester, services);

    expect(find.text('Mon potager'), findsOneWidget);
    expect(find.text('Dessiner une parcelle'), findsOneWidget);
  });

  testWidgets('several gardens : the list under the GardenFlow title, a card with its mini plan and description', (tester) async {
    services.auth.restoreResult = alice;
    services.gardens.gardens = [
      const Garden(id: 7, userId: 1, name: 'Mon potager', description: 'Derrière la maison'),
      const Garden(id: 8, userId: 1, name: 'Balcon'),
    ];

    await pumpApp(tester, services);

    expect(find.text('GardenFlow'), findsOneWidget);
    expect(find.text('Derrière la maison'), findsOneWidget);
    expect(find.text('Pas de description'), findsOneWidget);
    expect(find.byType(GardenMiniMap), findsNWidgets(2));
    // the gardens start below the title, not behind the home and profile buttons
    expect(tester.getRect(find.text('Mon potager')).top, greaterThan(tester.getRect(find.text('GardenFlow')).bottom));

    await tester.tap(find.text('Balcon'));
    await tester.pumpAndSettle();
    expect(find.text('Dessiner une parcelle'), findsOneWidget);
  });

  testWidgets('opening a garden : the plan grows out of its mini plan, the buttons slide in, backwards when closing', (tester) async {
    services.auth.restoreResult = alice;
    services.gardens.gardens = [
      const Garden(id: 7, userId: 1, name: 'Mon potager'),
      const Garden(id: 8, userId: 1, name: 'Balcon'),
    ];
    await pumpApp(tester, services);
    final miniMap = tester.getRect(find.byType(GardenMiniMap).last);

    await tester.tap(find.text('Balcon'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // early : the plan is still around the mini plan, the header and the button are not in place yet
    final plan = tester.getRect(find.byType(ShapeCanvas));
    final earlyTitle = tester.getRect(find.text('Balcon').last);
    final earlyButton = tester.getRect(find.text('Dessiner une parcelle'));
    expect(find.text('Mon potager'), findsOneWidget); // the list is still behind

    await tester.pumpAndSettle();
    expect(find.text('Mon potager'), findsNothing);
    final title = tester.getRect(find.text('Balcon'));
    final button = tester.getRect(find.text('Dessiner une parcelle'));
    expect(earlyTitle.top, lessThan(title.top)); // the header came down
    expect(earlyButton.top, greaterThan(button.top)); // the button came up
    expect(plan.contains(miniMap.center), isTrue);

    // closing : the same animation backwards, then the list is back
    await tester.tap(find.byTooltip('Mes jardins'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(find.text('Dessiner une parcelle')).top, greaterThan(button.top)); // going down
    await tester.pumpAndSettle();
    expect(find.byType(GardenView), findsNothing);
    expect(find.text('Mon potager'), findsOneWidget);
    expect(tester.getRect(find.byType(GardenMiniMap).last), miniMap);
  });

  testWidgets('register from the login screen -> home with welcome dialog', (tester) async {
    await pumpApp(tester, services);

    await tester.tap(find.text("S'inscrire"));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'alice');
    await tester.enterText(fields.at(1), 'alice@test.dev');
    await tester.enterText(fields.at(2), 'password123');
    await tester.enterText(fields.at(3), 'password123');
    await tester.ensureVisible(find.text("S'inscrire").last);
    await tester.tap(find.text("S'inscrire").last);
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue dans GardenFlow !'), findsOneWidget);
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun jardin pour le moment'), findsOneWidget);
  });

  testWidgets('server unreachable at startup -> retry screen', (tester) async {
    services.auth.restoreResult = ApiException(statusCode: 0, code: ApiException.networkError, message: 'offline');

    await pumpApp(tester, services);

    expect(find.text('Impossible de joindre le serveur'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
