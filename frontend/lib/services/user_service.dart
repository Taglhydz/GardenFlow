import '../config/constants.dart';
import '../models/json_utils.dart';
import '../models/user.dart';
import 'api_service.dart';

/// Current user's account (/users/me).
class UserService {
  UserService(this._api);

  final ApiService _api;

  static const _me = '${AppConstants.usersEndpoint}/me';

  /// Only the given fields are modified. Pass clearBirthdate to remove the birthdate.
  Future<User> updateMe({String? username, String? email, DateTime? birthdate, bool clearBirthdate = false}) async {
    final response = await _api.patch(_me, {
      if (username != null) 'username': username,
      if (email != null) 'email': email,
      if (birthdate != null || clearBirthdate) 'birthdate': JsonUtils.formatDate(birthdate),
    });
    return User.fromJson(response);
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _api.patch('$_me/password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  /// Deletes the account and all its gardens.
  Future<void> deleteMe() => _api.delete(_me);
}
