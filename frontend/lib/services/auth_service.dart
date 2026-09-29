import '../config/constants.dart';
import '../models/json_utils.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'token_storage.dart';

/// Authentication API calls. The session state itself lives in authProvider.
class AuthService {
  AuthService(this._api, this._tokenStorage);

  final ApiService _api;
  final TokenStorage _tokenStorage;

  /// No session : the server sends a verification email, login is possible once its link is opened.
  /// [lang] : language of the email ('fr' / 'en').
  Future<User> register({
    required String username,
    required String email,
    required String password,
    DateTime? birthdate,
    required String lang,
  }) async {
    final response = await _api.post('${AppConstants.authEndpoint}/register', {
      'username': username,
      'email': email,
      'password': password,
      if (birthdate != null) 'birthdate': JsonUtils.formatDate(birthdate),
      'lang': lang,
    });
    return User.fromJson(response['user']);
  }

  /// Sends a new verification email (the server answers the same way whether the email exists or not).
  Future<void> resendVerification({required String email, required String lang}) async {
    await _api.post('${AppConstants.authEndpoint}/resend-verification', {'email': email, 'lang': lang});
  }

  Future<User> login({required String email, required String password}) async {
    final response = await _api.post('${AppConstants.authEndpoint}/login', {
      'email': email,
      'password': password,
    });
    return _saveSession(response);
  }

  /// Current user, or null if no token is stored.
  Future<User?> restoreSession() async {
    if (await _tokenStorage.read() == null) return null;
    final response = await _api.get('${AppConstants.usersEndpoint}/me');
    return User.fromJson(response);
  }

  Future<void> logout() => _tokenStorage.clear();

  Future<User> _saveSession(dynamic response) async {
    await _tokenStorage.save(response['token'] as String);
    return User.fromJson(response['user']);
  }
}
