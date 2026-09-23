import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:GardenFlow/main.dart';
import 'package:GardenFlow/models/garden.dart';
import 'package:GardenFlow/providers/core_providers.dart';
import 'package:GardenFlow/services/api_service.dart';
import 'auth_provider_test.dart' show FakeAuthService, FakeGardenService, alice;

/// Builds the real app (AuthGate, screens, translations) with fake services.
void main() {
  late FakeAuthService authService;
  late FakeGardenService gardenService;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    authService = FakeAuthService();
    gardenService = FakeGardenService();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // pumped in a real async zone : easy_localization loads the translations with real I/O
    await tester.runAsync(() => tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authServiceProvider.overrideWithValue(authService),
          gardenServiceProvider.overrideWithValue(gardenService),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('fr'), Locale('en')],
          path: 'assets/translations',
          fallbackLocale: const Locale('fr'),
          startLocale: const Locale('fr'),
          saveLocale: false,
          child: const MyApp(),
        ),
      ),
    ));
    // wait until a screen is displayed
    for (var i = 0; i < 50 && find.byType(Scaffold).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('no session -> login screen, translated', (tester) async {
    await pumpApp(tester);

    expect(find.text('Gérez votre jardin facilement'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('wrong password -> translated error message', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'alice@test.dev');
    await tester.enterText(find.byType(TextFormField).at(1), 'bad');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Email ou mot de passe incorrect.'), findsOneWidget);
  });

  testWidgets('login -> home screen without gardens', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'alice@test.dev');
    await tester.enterText(find.byType(TextFormField).at(1), 'good');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Aucun jardin pour le moment'), findsOneWidget);
  });

  testWidgets('restored session with one garden -> the garden is opened', (tester) async {
    authService.restoreResult = alice;
    gardenService.gardens = [const Garden(id: 7, userId: 1, name: 'Mon potager')];

    await pumpApp(tester);

    expect(find.text('Mon potager'), findsOneWidget);
    expect(find.text('Vue du jardin à venir...'), findsOneWidget);
  });

  testWidgets('register from the login screen -> home with welcome dialog', (tester) async {
    await pumpApp(tester);

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
    authService.restoreResult = ApiException(statusCode: 0, code: ApiException.networkError, message: 'offline');

    await pumpApp(tester);

    expect(find.text('Impossible de joindre le serveur'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
