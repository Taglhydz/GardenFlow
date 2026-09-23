import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:GardenFlow/models/garden.dart';
import 'package:GardenFlow/services/api_service.dart';
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
