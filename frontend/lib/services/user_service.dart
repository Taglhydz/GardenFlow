import '../config/constants.dart';
import '../models/gardener_level.dart';
import '../models/json_utils.dart';
import '../models/user.dart';
import 'api_service.dart';

/// Current user's account (/users/me).
class UserService {
  UserService(this._api);

  final ApiService _api;

  static const _me = '${AppConstants.usersEndpoint}/me';

  Future<User> getMe() async => User.fromJson(await _api.get(_me));

  /// Only the given fields are modified. Pass clearBirthdate to remove the birthdate.
  /// The email is changed with [changeEmail].
  Future<User> updateMe({String? username, DateTime? birthdate, bool clearBirthdate = false}) async {
    final response = await _api.patch(_me, {
      if (username != null) 'username': username,
      if (birthdate != null || clearBirthdate) 'birthdate': JsonUtils.formatDate(birthdate),
    });
    return User.fromJson(response);
  }

  /// The new email becomes [User.pendingEmail] and receives a link (in [lang]) : it replaces the email once opened.
  /// Refused for an account created with Google (GOOGLE_ACCOUNT).
  Future<User> changeEmail({required String email, required String currentPassword, required String lang}) async {
    return User.fromJson(await _api.patch('$_me/email', {
      'email': email,
      'current_password': currentPassword,
      'lang': lang,
    }));
  }

  /// Forgets the pending email, its link stops working.
  Future<User> cancelEmailChange() async => User.fromJson(await _api.delete('$_me/email'));

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _api.patch('$_me/password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  /// Deletes the account and all its gardens.
  Future<void> deleteMe() => _api.delete(_me);

  /// Plant avatar (Avatars.codes) : it replaces the photo.
  Future<User> setAvatar(String avatar) async => User.fromJson(await _api.patch(_me, {'avatar': avatar}));

  /// Profile photo (JPEG, PNG or WebP, 2 MB max) : it replaces the avatar.
  Future<User> uploadPhoto(List<int> bytes, {required String filename, required String contentType}) async {
    return User.fromJson(
      await _api.upload('$_me/photo', field: 'photo', bytes: bytes, filename: filename, contentType: contentType),
    );
  }

  /// No photo or avatar anymore : the first letter of the name is shown.
  Future<User> removePicture(User user) async {
    if (user.photo != null) return User.fromJson(await _api.delete('$_me/photo'));
    return User.fromJson(await _api.patch(_me, {'avatar': null}));
  }

  Future<GardenerLevel> getMyLevel() async => GardenerLevel.fromJson(await _api.get('$_me/level'));
}
