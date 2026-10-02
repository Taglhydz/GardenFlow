import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/core_providers.dart';
import '../services/api_service.dart';
import 'google_web_button_stub.dart' if (dart.library.js_interop) 'google_web_button_web.dart';

/// "or" + "Continue with Google", under the login and register forms.
/// Signs up or logs in : on success, AuthGate shows the home screen. Hidden where Google sign-in is not available.
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _isLoading = false;
  StreamSubscription<String>? _webSignIns;

  @override
  void initState() {
    super.initState();
    final google = ref.read(googleSignInServiceProvider);
    if (google.isAvailable && google.usesGoogleButton) {
      _webSignIns = google.webIdTokens().listen((idToken) {
        // the login and register screens can both be open : only the visible one logs in
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) _logIn(idToken);
      });
    }
  }

  @override
  void dispose() {
    _webSignIns?.cancel();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final idToken = await ref.read(googleSignInServiceProvider).signIn();
      if (idToken != null) await _logIn(idToken);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logIn(String idToken) async {
    try {
      await ref.read(authProvider.notifier).loginWithGoogle(idToken);
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // errors of Google itself (not of our server) : one generic message
        content: Text(error is ApiException ? AppLocalizations.errorMessage(error) : 'errors.GOOGLE_SIGN_IN_FAILED'.tr()),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final google = ref.watch(googleSignInServiceProvider);
    if (!google.isAvailable) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('auth.or'.tr(), style: const TextStyle(color: AppColors.grey)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        if (google.usesGoogleButton)
          Center(child: googleWebButton())
        else
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _signIn,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text(
                      'G',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4285F4)),
                    ),
              label: Text('auth.continue_with_google'.tr(), style: const TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
      ],
    );
  }
}
