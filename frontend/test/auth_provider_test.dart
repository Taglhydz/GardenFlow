import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:GardenFlow/config/constants.dart';
import 'package:GardenFlow/models/garden.dart';
import 'package:GardenFlow/models/user.dart';
import 'package:GardenFlow/providers/auth_provider.dart';
import 'package:GardenFlow/providers/core_providers.dart';
import 'package:GardenFlow/providers/garden_providers.dart';
import 'package:GardenFlow/services/api_service.dart';
import 'package:GardenFlow/services/auth_service.dart';
import 'package:GardenFlow/services/garden_service.dart';

const alice = User(id: 1, username: 'alice', email: 'alice@test.dev');

class FakeAuthService implements AuthService {
  /// What restoreSession returns (a User, null, or an exception to throw)
  Object? restoreResult;
  bool loggedOut = false;

  @override
  Future<User?> restoreSession() async {
    final result = restoreResult;
    if (result is Exception) throw result;
    return result as User?;
  }

  @override
  Future<User> login({required String email, required String password}) async {
    if (password != 'good') {
      throw ApiException(statusCode: 401, code: 'INVALID_CREDENTIALS', message: 'wrong');
    }
    return alice;
  }

  @override
  Future<User> register({required String username, required String email, required String password, DateTime? birthdate}) async => alice;

  @override
  Future<void> logout() async => loggedOut = true;
}

class FakeGardenService implements GardenService {
  List<Garden> gardens = [];

  @override
  Future<List<Garden>> getMyGardens() async => gardens;

  @override
  Future<Garden> createGarden({required String name, String? location, String? description}) async {
    final garden = Garden(id: 100 + gardens.length, userId: alice.id, name: name);
    gardens = [...gardens, garden];
    return garden;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late FakeAuthService authService;
  late FakeGardenService gardenService;
  late SharedPreferences prefs;

  Future<ProviderContainer> createContainer({Map<String, Object> prefsValues = const {}}) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authServiceProvider.overrideWithValue(authService),
      gardenServiceProvider.overrideWithValue(gardenService),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    authService = FakeAuthService();
    gardenService = FakeGardenService();
  });

  group('auto-login', () {
    test('valid stored token -> logged in', () async {
      authService.restoreResult = alice;
      final container = await createContainer();

      expect(await container.read(authProvider.future), alice);
      expect(container.read(currentUserIdProvider), alice.id);
    });

    test('no token -> logged out', () async {
      authService.restoreResult = null;
      final container = await createContainer();

      expect(await container.read(authProvider.future), isNull);
    });

    test('expired token (401) -> logged out and token cleared', () async {
      authService.restoreResult = ApiException(statusCode: 401, code: 'INVALID_TOKEN', message: 'expired');
      final container = await createContainer();

      expect(await container.read(authProvider.future), isNull);
      expect(authService.loggedOut, isTrue);
    });

    test('server unreachable -> error state (the app offers to retry), token kept', () async {
      authService.restoreResult = ApiException(statusCode: 0, code: ApiException.networkError, message: 'offline');
      final container = await createContainer();

      await expectLater(container.read(authProvider.future), throwsA(isA<ApiException>()));
      expect(container.read(authProvider).hasError, isTrue);
      expect(authService.loggedOut, isFalse);
    });
  });

  group('login / logout', () {
    test('wrong password throws and stays logged out', () async {
      final container = await createContainer();
      await container.read(authProvider.future);

      await expectLater(
        container.read(authProvider.notifier).login(email: 'a@b.c', password: 'bad'),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(authProvider).value, isNull);
    });

    test('login then logout clears the session and the remembered garden', () async {
      final container = await createContainer(prefsValues: {AppConstants.lastGardenIdKey: 5});
      await container.read(authProvider.future);

      await container.read(authProvider.notifier).login(email: 'a@b.c', password: 'good');
      expect(container.read(authProvider).value, alice);

      await container.read(authProvider.notifier).logout();
      expect(container.read(authProvider).value, isNull);
      expect(authService.loggedOut, isTrue);
      expect(prefs.getInt(AppConstants.lastGardenIdKey), isNull);
    });

    test('session expired while logged in -> logged out with a notification', () async {
      authService.restoreResult = alice;
      final container = await createContainer();
      await container.read(authProvider.future);

      container.read(authProvider.notifier).onSessionExpired();

      expect(container.read(authProvider).value, isNull);
      expect(container.read(sessionExpiredProvider), isTrue);
    });

    test('register raises the welcome flag once', () async {
      final container = await createContainer();
      await container.read(authProvider.future);

      await container.read(authProvider.notifier).register(username: 'alice', email: 'a@b.c', password: 'password123');

      final welcome = container.read(welcomePendingProvider.notifier);
      expect(welcome.consume(), isTrue);
      expect(welcome.consume(), isFalse);
    });
  });

  group('gardens', () {
    test('logged out -> no gardens', () async {
      gardenService.gardens = [const Garden(id: 1, userId: 1, name: 'A')];
      final container = await createContainer();
      await container.read(authProvider.future);

      expect(await container.read(gardensProvider.future), isEmpty);
    });

    test('creating a garden adds it and selects it (remembered)', () async {
      authService.restoreResult = alice;
      final container = await createContainer();
      await container.read(gardensProvider.future);

      final garden = await container.read(gardensProvider.notifier).create(name: 'Potager');

      expect(container.read(gardensProvider).value, [garden]);
      expect(container.read(selectedGardenProvider), garden);
      expect(prefs.getInt(AppConstants.lastGardenIdKey), garden.id);
    });

    test('a remembered garden that no longer exists is not selected', () async {
      authService.restoreResult = alice;
      gardenService.gardens = [const Garden(id: 1, userId: 1, name: 'A')];
      final container = await createContainer(prefsValues: {AppConstants.lastGardenIdKey: 99});
      await container.read(gardensProvider.future);

      expect(container.read(selectedGardenProvider), isNull);
    });
  });
}
