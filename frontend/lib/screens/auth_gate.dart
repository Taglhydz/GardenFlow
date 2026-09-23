import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// First screen of the app : shows Login or Home depending on the session.
/// Login, logout and session expiry only change authProvider, this widget does the navigation.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // when the user logs in or out, close the screens opened on top (register, profile...)
    ref.listen(currentUserIdProvider, (previous, next) {
      if (previous != next) Navigator.of(context).popUntil((route) => route.isFirst);
    });

    ref.listen(sessionExpiredProvider, (_, expired) {
      if (!expired) return;
      ref.read(sessionExpiredProvider.notifier).consume();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auth.session_expired'.tr()), backgroundColor: AppColors.warning),
      );
    });

    return ref.watch(authProvider).when(
      // show the spinner again when "retry" is pressed
      skipLoadingOnRefresh: false,
      loading: () => const _SplashScreen(),
      error: (_, _) => _StartupErrorScreen(onRetry: () => ref.invalidate(authProvider)),
      data: (user) => user == null ? const LoginScreen() : const HomeScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco, size: 80, color: AppColors.primary),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

/// The server could not be reached while restoring the session.
class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              Text(
                'startup.error_title'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'startup.error_message'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text('retry'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
