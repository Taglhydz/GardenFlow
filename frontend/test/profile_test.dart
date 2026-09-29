import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:GardenFlow/models/garden.dart';
import 'package:GardenFlow/models/gardener_level.dart';
import 'package:GardenFlow/widgets/level_badge.dart';
import 'package:GardenFlow/widgets/user_avatar.dart';
import 'app_harness.dart';
import 'fakes.dart';

/// Profile picture (photo or plant avatar) and level of the gardener.
void main() {
  late FakeServices services;

  setUpAll(initTestApp);
  setUp(() {
    services = FakeServices();
    services.auth.restoreResult = alice;
    services.gardens.gardens = [
      const Garden(id: 7, userId: 1, name: 'Mon potager'),
      const Garden(id: 8, userId: 1, name: 'Balcon'),
    ];
  });

  Future<void> openProfile(WidgetTester tester) async {
    await pumpApp(tester, services);
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
  }

  Future<void> openPictureSheet(WidgetTester tester) async {
    await openProfile(tester);
    await tester.tap(find.byTooltip('Photo de profil'));
    await tester.pumpAndSettle();
  }

  testWidgets('home : the rank of the gardener under the title, their picture opens the profile', (tester) async {
    await pumpApp(tester, services);

    expect(find.byType(LevelBadge), findsOneWidget);
    expect(find.text('Jeune plant'), findsOneWidget);
    expect(find.byType(UserAvatar), findsOneWidget);
    expect(find.text('A'), findsOneWidget); // no picture yet : the first letter of the name
  });

  testWidgets('profile : the level card with the rank, the points to the next rank and the stats', (tester) async {
    await openProfile(tester);

    expect(find.byType(LevelCard), findsOneWidget);
    expect(find.text('Niveau de jardinier'), findsOneWidget);
    expect(find.text('176 points'), findsOneWidget);
    expect(find.text('Encore 174 points pour devenir Jardinier'), findsOneWidget);
    expect(find.text('6 cultures'), findsOneWidget);
  });

  testWidgets('the header (back, title, settings) stays at the top while the profile scrolls', (tester) async {
    await openProfile(tester);
    final title = tester.getRect(find.text('Profil'));
    final settings = tester.getRect(find.byTooltip('Paramètres'));
    final card = tester.getRect(find.text('Niveau de jardinier'));

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.text('Niveau de jardinier')).top, lessThan(card.top)); // the content scrolled
    expect(tester.getRect(find.text('Profil')), title);
    expect(tester.getRect(find.byTooltip('Paramètres')), settings);
    // the content goes under the header, not over it
    expect(tester.getRect(find.byType(SingleChildScrollView)).top, greaterThanOrEqualTo(title.bottom));
  });

  testWidgets('the top rank has no next rank', (tester) async {
    services.users.level = const GardenerLevel(rank: 'master_gardener', points: 1500, rankMin: 1200);
    await openProfile(tester);

    expect(find.text('Maître jardinier'), findsOneWidget);
    expect(find.text('Rang maximum atteint, bravo !'), findsOneWidget);
  });

  testWidgets('choose a plant avatar : it replaces the first letter, here and on the home page', (tester) async {
    await openPictureSheet(tester);
    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(find.text('Choisir dans la galerie'), findsOneWidget);

    await tester.tap(find.byTooltip('Carotte'));
    await tester.pumpAndSettle();

    expect(find.text('Ou choisissez un avatar'), findsNothing); // the sheet is closed
    final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar).last);
    expect(avatar.user.avatar, 'carrot');
    expect(find.descendant(of: find.byType(UserAvatar).last, matching: find.byType(SvgPicture)), findsOneWidget);

    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(tester.widget<UserAvatar>(find.byType(UserAvatar)).user.avatar, 'carrot');
  });

  testWidgets('a photo from the gallery is sent, and shown instead of the letter', (tester) async {
    await openPictureSheet(tester);

    await tester.tap(find.text('Choisir dans la galerie'));
    await tester.pumpAndSettle();

    expect(services.photoPicker.usedCamera, isFalse);
    expect(services.users.uploaded, [1, 2, 3]);
    final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar).last);
    expect(avatar.user.photoUrl, endsWith('/uploads/photos/1-abc.jpg'));
    expect(find.descendant(of: find.byType(UserAvatar).last, matching: find.byType(Image)), findsOneWidget);
  });

  testWidgets('taking a photo with the camera, cancelling sends nothing', (tester) async {
    services.photoPicker.photo = null; // cancelled
    await openPictureSheet(tester);

    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();

    expect(services.photoPicker.usedCamera, isTrue);
    expect(services.users.uploaded, isNull);
    expect(find.text('Ou choisissez un avatar'), findsOneWidget); // still open
  });

  testWidgets('no camera (desktop) : only the gallery is offered', (tester) async {
    services.photoPicker.camera = false;
    await openPictureSheet(tester);

    expect(find.text('Prendre une photo'), findsNothing);
    expect(find.text('Choisir dans la galerie'), findsOneWidget);
  });

  testWidgets('in a garden, the header shows my picture', (tester) async {
    services.gardens.gardens = [const Garden(id: 7, userId: 1, name: 'Mon potager')]; // opened directly
    await pumpApp(tester, services);

    expect(find.text('Dessiner une parcelle'), findsOneWidget);
    expect(find.descendant(of: find.byType(AppBar), matching: find.byType(UserAvatar)), findsOneWidget);
  });

  testWidgets('delete my account : after a clear warning, back to the login screen', (tester) async {
    await openProfile(tester);

    await tester.ensureVisible(find.text('Supprimer mon compte'));
    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();
    expect(find.textContaining('irréversible'), findsOneWidget);

    // changed my mind
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(services.users.deleted, isFalse);

    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer définitivement'));
    await tester.pumpAndSettle();

    expect(services.users.deleted, isTrue);
    expect(services.auth.loggedOut, isTrue);
    expect(find.text('Se connecter'), findsOneWidget); // login screen
  });
}
