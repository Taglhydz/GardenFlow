import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/crop_service.dart';
import '../services/garden_service.dart';
import '../services/parcel_service.dart';
import '../services/plant_service.dart';
import '../services/token_storage.dart';
import '../services/user_service.dart';
import '../services/zone_service.dart';
import 'auth_provider.dart';

/// Loaded once in main() and injected with ProviderScope overrides,
/// so it can be read synchronously everywhere.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden in main()'),
);

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(
    tokenStorage: ref.watch(tokenStorageProvider),
    // any request rejected with 401 logs the user out
    onSessionExpired: () => ref.read(authProvider.notifier).onSessionExpired(),
  );
});

// Services (stateless API wrappers)
final authServiceProvider   = Provider((ref) => AuthService(ref.watch(apiServiceProvider), ref.watch(tokenStorageProvider)));
final userServiceProvider   = Provider((ref) => UserService(ref.watch(apiServiceProvider)));
final gardenServiceProvider = Provider((ref) => GardenService(ref.watch(apiServiceProvider)));
final parcelServiceProvider = Provider((ref) => ParcelService(ref.watch(apiServiceProvider)));
final cropServiceProvider   = Provider((ref) => CropService(ref.watch(apiServiceProvider)));
final plantServiceProvider  = Provider((ref) => PlantService(ref.watch(apiServiceProvider)));
final zoneServiceProvider   = Provider((ref) => ZoneService(ref.watch(apiServiceProvider)));

/// Retry policy of the providers that fail (ProviderScope.retry) :
/// network and server errors are retried 3 times, client errors (4xx) are not.
Duration? providerRetry(int retryCount, Object error) {
  if (error is ApiException && error.statusCode >= 400 && error.statusCode < 500) return null;
  if (retryCount >= 3) return null;
  return Duration(seconds: 1 << retryCount); // 1s, 2s, 4s
}
