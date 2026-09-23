import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'core_providers.dart';

/// Logged in user, or null when logged out.
/// On startup, the stored token is used to restore the session (auto-login).
final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
  // the startup screen offers a "retry" button instead
  retry: (_, _) => null,
);

/// Id of the logged in user : watch it to reload user data when the account changes.
final currentUserIdProvider = Provider<int?>((ref) => ref.watch(authProvider.select((auth) => auth.value?.id)));

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final authService = ref.read(authServiceProvider);
    try {
      return await authService.restoreSession();
    } on ApiException catch (e) {
      // stored token expired or account deleted : start logged out
      if (e.statusCode == 401) {
        await authService.logout();
        return null;
      }
      rethrow;
    }
  }

  /// Throws an [ApiException] on failure, the auth state is left unchanged.
  Future<void> login({required String email, required String password}) async {
    final user = await ref.read(authServiceProvider).login(email: email, password: password);
    state = AsyncData(user);
  }

  /// Throws an [ApiException] on failure, the auth state is left unchanged.
  Future<void> register({
    required String username,
    required String email,
    required String password,
    DateTime? birthdate,
  }) async {
    final user = await ref.read(authServiceProvider).register(
      username: username,
      email: email,
      password: password,
      birthdate: birthdate,
    );
    ref.read(welcomePendingProvider.notifier).raise();
    state = AsyncData(user);
  }

  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    await ref.read(sharedPreferencesProvider).remove(AppConstants.lastGardenIdKey);
    state = const AsyncData(null);
  }

  /// Called by ApiService when the server rejects the token.
  void onSessionExpired() {
    // nothing to do if already logged out, or while restoring the session (handled in build)
    if (state.isLoading || state.value == null) return;

    ref.read(authServiceProvider).logout();
    ref.read(sessionExpiredProvider.notifier).raise();
    state = const AsyncData(null);
  }

  /// After a profile update.
  void updateUser(User user) => state = AsyncData(user);
}

/// true right after a registration : the home screen shows a welcome dialog once.
final welcomePendingProvider = NotifierProvider<FlagNotifier, bool>(FlagNotifier.new);

/// true when the user was logged out because the session expired : the login screen tells them why.
final sessionExpiredProvider = NotifierProvider<FlagNotifier, bool>(FlagNotifier.new);

/// One-shot boolean flag.
class FlagNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void raise() => state = true;

  /// Returns the flag value and resets it.
  bool consume() {
    final value = state;
    state = false;
    return value;
  }
}
