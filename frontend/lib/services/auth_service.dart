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

  Future<User> register({
    required String username,
    required String email,
    required String password,
    DateTime? birthdate,
  }) async {
    final response = await _api.post('${AppConstants.authEndpoint}/register', {
      'username': username,
      'email': email,
      'password': password,
      if (birthdate != null) 'birthdate': JsonUtils.formatDate(birthdate),
    });
    return _saveSession(response);
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
