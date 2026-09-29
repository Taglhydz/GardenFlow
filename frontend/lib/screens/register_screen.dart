import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../providers/auth_provider.dart';
import '../utils/validators.dart';
import '../widgets/custom_button.dart';
import '../widgets/date_input_field.dart';
import '../widgets/password_rules.dart';
import 'verify_email_screen.dart';

/// Opened on top of the login screen. On success, it is replaced by the "check your emails" screen
/// and the login screen receives the email (Navigator result) to fill it in.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey                   = GlobalKey<FormState>();
  final _usernameController        = TextEditingController();
  final _emailController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading                = false;
  bool _isPasswordVisible        = false;
  bool _isConfirmPasswordVisible = false;
  DateTime? _selectedBirthdate;

  @override
  void dispose() {
    _usernameController       .dispose();
    _emailController          .dispose();
    _passwordController       .dispose();
    _confirmPasswordController.dispose();
    super                     .dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    try {
      await ref.read(authProvider.notifier).register(
        username: _usernameController.text.trim(),
        email: email,
        password: _passwordController.text,
        birthdate: _selectedBirthdate,
        lang: context.locale.languageCode,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: email, justRegistered: true)),
          result: email,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.errorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo ou "GardenFlow"
                  const Icon(
                    Icons.eco,
                    size: 80,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'auth.register_title'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'auth.register_subtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.grey,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // username
                  TextFormField(
                    controller: _usernameController,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'username'.tr(),
                      prefixIcon: const Icon(Icons.person),
                      border: const OutlineInputBorder(),
                    ),
                    validator: Validators.username,
                  ),
                  const SizedBox(height: 16),

                  // email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'email'.tr(),
                      prefixIcon: const Icon(Icons.email),
                      border: const OutlineInputBorder(),
                    ),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),

                  // birthdate : typed (fixed slashes) or picked in the calendar
                  DateInputField(
                    label: 'auth.birthdate_optional'.tr(),
                    value: _selectedBirthdate,
                    onChanged: (date) => _selectedBirthdate = date,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                    initialPickerDate: DateTime(2000),
                    pickerHelpText: 'auth.birthdate_picker_help'.tr(),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'password'.tr(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        tooltip: _isPasswordVisible ? 'auth.hide_password'.tr() : 'auth.show_password'.tr(),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: Validators.newPassword,
                  ),
                  PasswordRules(controller: _passwordController),
                  const SizedBox(height: 16),

                  // password confirmation
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _isLoading ? null : _register(),
                    decoration: InputDecoration(
                      labelText: 'auth.confirm_password'.tr(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        tooltip: _isConfirmPasswordVisible ? 'auth.hide_password'.tr() : 'auth.show_password'.tr(),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'validation.confirm_password_required'.tr();
                      }
                      if (value != _passwordController.text) {
                        return 'validation.passwords_dont_match'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // submit button
                  CustomButton(
                    text: 'auth.register_button'.tr(),
                    onPressed: _register,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),

                  // link to login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('auth.have_account'.tr()),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'auth.login_button'.tr(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
