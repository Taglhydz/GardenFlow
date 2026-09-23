import 'package:easy_localization/easy_localization.dart';
import '../config/constants.dart';

/// Form validators, the rules match the backend (validators/userValidators.js).
class Validators {
  Validators._();

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'validation.email_required'.tr();
    if (!_emailRegex.hasMatch(value.trim())) return 'validation.email_invalid'.tr();
    return null;
  }

  /// Login : any non empty password (older accounts may have shorter passwords).
  static String? passwordRequired(String? value) {
    if (value == null || value.isEmpty) return 'validation.password_required'.tr();
    return null;
  }

  /// Register / new password : minimal length.
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'validation.password_required'.tr();
    if (value.length < AppConstants.passwordMinLength) {
      return 'validation.password_min'.tr(args: ['${AppConstants.passwordMinLength}']);
    }
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
