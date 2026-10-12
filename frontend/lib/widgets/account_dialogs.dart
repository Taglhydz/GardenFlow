import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/core_providers.dart';
import '../providers/profile_providers.dart';
import '../utils/validators.dart';
import 'password_rules.dart';

/// Changes the username. Returns true when it was saved.
Future<bool> showUsernameDialog(BuildContext context, User user) async =>
    await showDialog<bool>(context: context, builder: (_) => _UsernameDialog(user: user)) ?? false;

/// Asks for a new email (sent a confirmation link). Returns the new email when the link was sent.
/// Only for an account with a password (not created with Google).
Future<String?> showEmailDialog(BuildContext context, User user) =>
    showDialog<String>(context: context, builder: (_) => _EmailDialog(user: user));

/// Changes the password (the other devices are logged out). Returns true when it was changed.
/// Only for an account with a password (not created with Google).
Future<bool> showPasswordDialog(BuildContext context) async =>
    await showDialog<bool>(context: context, builder: (_) => const _PasswordDialog()) ?? false;

/// "Forgot password" on the login screen : asks for the email ([email] : the one already typed).
/// Returns the email when the request was sent.
Future<String?> showForgotPasswordDialog(BuildContext context, {String email = ''}) =>
    showDialog<String>(context: context, builder: (_) => _ForgotPasswordDialog(email: email));

/// Deletes the account after a clear warning, with the password for an account that has one.
/// Once deleted, AuthGate closes the dialog and shows the login screen.
Future<void> showDeleteAccountDialog(BuildContext context, User user) =>
    showDialog<void>(context: context, builder: (_) => _DeleteAccountDialog(user: user));

/// Dialog with a form : the server error is shown in it, above the buttons.
class _AccountDialog extends StatelessWidget {
  const _AccountDialog({
    required this.title,
    required this.formKey,
    required this.fields,
    required this.action,
    required this.isLoading,
    required this.error,
    required this.onSubmit,
    this.destructive = false,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final String action;
  final bool isLoading;
  final String? error;
  final VoidCallback onSubmit;

  /// Red button and warning icon : the action can't be undone
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: destructive ? const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 40) : null,
      title: Text(title),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...fields,
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: AppColors.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: destructive ? AppColors.error : AppColors.primary,
            foregroundColor: AppColors.white,
          ),
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                )
              : Text(action),
        ),
      ],
    );
  }
}

// ========
// Username
// ========
class _UsernameDialog extends ConsumerStatefulWidget {
  const _UsernameDialog({required this.user});

  final User user;

  @override
  ConsumerState<_UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends ConsumerState<_UsernameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.user.displayName);
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _controller.text.trim();
    // stored in lowercase : only the case changed = nothing to save
    if (username.toLowerCase() == widget.user.username) {
      Navigator.pop(context, false);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(accountProvider).rename(username);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = AppLocalizations.errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountDialog(
      title: 'profile.edit_username'.tr(),
      formKey: _formKey,
      action: 'save'.tr(),
      isLoading: _isLoading,
      error: _error,
      onSubmit: _save,
      fields: [
        TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: 50,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _isLoading ? null : _save(),
          decoration: InputDecoration(
            labelText: 'username'.tr(),
            prefixIcon: const Icon(Icons.person),
            border: const OutlineInputBorder(),
          ),
          validator: Validators.username,
        ),
      ],
    );
  }
}

// =====
// Email
// =====
class _EmailDialog extends ConsumerStatefulWidget {
  const _EmailDialog({required this.user});

  final User user;

  @override
  ConsumerState<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends ConsumerState<_EmailDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(accountProvider).changeEmail(
            email: email,
            currentPassword: _passwordController.text,
            lang: context.locale.languageCode,
          );
      if (mounted) Navigator.pop(context, email);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = AppLocalizations.errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountDialog(
      title: 'profile.edit_email'.tr(),
      formKey: _formKey,
      action: 'profile.send_link'.tr(),
      isLoading: _isLoading,
      error: _error,
      onSubmit: _send,
      fields: [
        Text(
          'profile.email_change_help'.tr(),
          style: const TextStyle(fontSize: 13, color: AppColors.greyDark),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'profile.new_email'.tr(),
            prefixIcon: const Icon(Icons.email),
            border: const OutlineInputBorder(),
          ),
          validator: Validators.email,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _isLoading ? null : _send(),
          decoration: InputDecoration(
            labelText: 'profile.current_password'.tr(),
            prefixIcon: const Icon(Icons.lock),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ),
          validator: Validators.passwordRequired,
        ),
      ],
    );
  }
}

// ========
// Password
// ========
class _PasswordDialog extends ConsumerStatefulWidget {
  const _PasswordDialog();

  @override
  ConsumerState<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends ConsumerState<_PasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _arePasswordsVisible = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(accountProvider).changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = AppLocalizations.errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountDialog(
      title: 'profile.change_password'.tr(),
      formKey: _formKey,
      action: 'save'.tr(),
      isLoading: _isLoading,
      error: _error,
      onSubmit: _save,
      fields: [
        Text(
          'profile.change_password_help'.tr(),
          style: const TextStyle(fontSize: 13, color: AppColors.greyDark),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _currentController,
          autofocus: true,
          obscureText: !_arePasswordsVisible,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'profile.current_password'.tr(),
            prefixIcon: const Icon(Icons.lock),
            border: const OutlineInputBorder(),
            // one button shows or hides the three fields
            suffixIcon: IconButton(
              icon: Icon(_arePasswordsVisible ? Icons.visibility : Icons.visibility_off),
              tooltip: _arePasswordsVisible ? 'auth.hide_password'.tr() : 'auth.show_password'.tr(),
              onPressed: () => setState(() => _arePasswordsVisible = !_arePasswordsVisible),
            ),
          ),
          validator: Validators.passwordRequired,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _newController,
          obscureText: !_arePasswordsVisible,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'profile.new_password'.tr(),
            prefixIcon: const Icon(Icons.lock_reset),
            border: const OutlineInputBorder(),
          ),
          validator: Validators.newPassword,
        ),
        PasswordRules(controller: _newController),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmController,
          obscureText: !_arePasswordsVisible,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _isLoading ? null : _save(),
          decoration: InputDecoration(
            labelText: 'auth.confirm_password'.tr(),
            prefixIcon: const Icon(Icons.lock_reset),
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'validation.confirm_password_required'.tr();
            if (value != _newController.text) return 'validation.passwords_dont_match'.tr();
            return null;
          },
        ),
      ],
    );
  }
}

// ===============
// Forgot password
// ===============
class _ForgotPasswordDialog extends ConsumerStatefulWidget {
  const _ForgotPasswordDialog({required this.email});

  final String email;

  @override
  ConsumerState<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.email.trim());
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _controller.text.trim().toLowerCase();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).forgotPassword(email: email, lang: context.locale.languageCode);
      if (mounted) Navigator.pop(context, email);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = AppLocalizations.errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountDialog(
      title: 'auth.forgot_password_title'.tr(),
      formKey: _formKey,
      action: 'profile.send_link'.tr(),
      isLoading: _isLoading,
      error: _error,
      onSubmit: _send,
      fields: [
        Text(
          'auth.forgot_password_help'.tr(),
          style: const TextStyle(fontSize: 13, color: AppColors.greyDark),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _isLoading ? null : _send(),
          decoration: InputDecoration(
            labelText: 'email'.tr(),
            prefixIcon: const Icon(Icons.email),
            border: const OutlineInputBorder(),
          ),
          validator: Validators.email,
        ),
      ],
    );
  }
}

// ==============
// Delete account
// ==============
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog({required this.user});

  final User user;

  @override
  ConsumerState<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // an account created with Google has no password : the session is enough
      await ref.read(authProvider.notifier).deleteAccount(
            currentPassword: widget.user.hasPassword ? _passwordController.text : null,
          );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = AppLocalizations.errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountDialog(
      title: 'profile.delete_account_title'.tr(),
      formKey: _formKey,
      action: 'profile.delete_account_action'.tr(),
      isLoading: _isLoading,
      error: _error,
      onSubmit: _delete,
      destructive: true,
      fields: [
        Text('profile.delete_account_confirm'.tr()),
        if (widget.user.hasPassword) ...[
          const SizedBox(height: 16),
          Text(
            'profile.delete_account_password'.tr(),
            style: const TextStyle(fontSize: 13, color: AppColors.greyDark),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _isLoading ? null : _delete(),
            decoration: InputDecoration(
              labelText: 'profile.current_password'.tr(),
              prefixIcon: const Icon(Icons.lock),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
            validator: Validators.passwordRequired,
          ),
        ],
      ],
    );
  }
}
