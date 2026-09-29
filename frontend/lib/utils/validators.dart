import 'package:easy_localization/easy_localization.dart';
import '../config/constants.dart';

/// A rule of the password : [key] is translated with `validation.password_rule_<key>`.
class PasswordRule {
  const PasswordRule(this.key, this.test);

  final String key;
  final bool Function(String password) test;
}

/// Form validators, the rules match the backend (validators/userValidators.js).
class Validators {
  Validators._();

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Same rules as the backend : must stay in sync
  static final passwordRules = [
    PasswordRule('length'   , (p) => p.length >= AppConstants.passwordMinLength),
    PasswordRule('lowercase', (p) => RegExp(r'\p{Ll}', unicode: true).hasMatch(p)),
    PasswordRule('uppercase', (p) => RegExp(r'\p{Lu}', unicode: true).hasMatch(p)),
    PasswordRule('digit'    , (p) => RegExp(r'\p{Nd}', unicode: true).hasMatch(p)),
    PasswordRule('symbol'   , (p) => RegExp(r'[^\p{L}\p{Nd}\s]', unicode: true).hasMatch(p)),
  ];

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'validation.email_required'.tr();
    if (!_emailRegex.hasMatch(value.trim())) return 'validation.email_invalid'.tr();
    return null;
  }

  /// Login : any non empty password (older accounts may have simpler passwords).
  static String? passwordRequired(String? value) {
    if (value == null || value.isEmpty) return 'validation.password_required'.tr();
    return null;
  }

  /// Register / new password : the missing rules are listed under the field (widgets/password_rules.dart).
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'validation.password_required'.tr();
    if (!passwordRules.every((rule) => rule.test(value))) return 'validation.password_weak'.tr();
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return 'validation.username_required'.tr();
    if (value.trim().length < AppConstants.usernameMinLength) {
      return 'validation.username_min'.tr(args: ['${AppConstants.usernameMinLength}']);
    }
    return null;
  }

  static String? requiredName(String? value) {
    if (value == null || value.trim().isEmpty) return 'validation.name_required'.tr();
    return null;
  }
}
