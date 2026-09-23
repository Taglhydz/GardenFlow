// Builds the real app (AuthGate, screens, translations) with in-memory services.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:GardenFlow/main.dart';
import 'package:GardenFlow/providers/core_providers.dart';
import 'fakes.dart';

class FakeServices {
  final auth = FakeAuthService();
  final gardens = FakeGardenService();
  final parcels = FakeParcelService();
  final crops = FakeCropService();
  final plants = FakePlantService();
  final zones = FakeZoneService();
}

/// Call once per test file (setUpAll).
Future<void> initTestApp() async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
}

Future<void> pumpApp(WidgetTester tester, FakeServices services) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  // pumped in a real async zone : easy_localization loads the translations with real I/O
  await tester.runAsync(() => tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(services.auth),
        gardenServiceProvider.overrideWithValue(services.gardens),
        parcelServiceProvider.overrideWithValue(services.parcels),
        cropServiceProvider.overrideWithValue(services.crops),
        plantServiceProvider.overrideWithValue(services.plants),
        zoneServiceProvider.overrideWithValue(services.zones),
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
