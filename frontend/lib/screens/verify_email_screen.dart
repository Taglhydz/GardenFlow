import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../providers/core_providers.dart';
import '../widgets/custom_button.dart';

/// "Check your emails" : shown after the registration, and when logging in with an email not verified yet.
/// The link of the email opens a web page served by the API, the user then comes back to log in.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email, this.justRegistered = false});

  final String email;

  /// true : the email has just been sent. false : login refused, no new email sent yet.
  final bool justRegistered;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  // same delay as the server between two emails
  static const _cooldown = 60;

  bool _isSending = false;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.justRegistered) _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _secondsLeft = _cooldown;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() => _isSending = true);
    try {
      await ref.read(authServiceProvider).resendVerification(email: widget.email, lang: context.locale.languageCode);
      if (!mounted) return;
      setState(_startCooldown);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('verify_email.sent'.tr()), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.errorMessage(e)), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.mark_email_unread_outlined, size: 80, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  (widget.justRegistered ? 'verify_email.title_sent' : 'verify_email.title_not_verified').tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  (widget.justRegistered ? 'verify_email.message_sent' : 'verify_email.message_not_verified').tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: AppColors.greyDark),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'verify_email.spam_hint'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.grey),
                ),
                const SizedBox(height: 40),

                // back to the login screen, where the email is already filled in
                CustomButton(
                  text: 'verify_email.go_to_login'.tr(),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _isSending || _secondsLeft > 0 ? null : _resend,
                  icon: _isSending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: Text(
                    _secondsLeft > 0
                        ? 'verify_email.resend_in'.tr(args: ['$_secondsLeft'])
                        : 'verify_email.resend'.tr(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
