import '../config/constants.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  Future<User> register({
    required String username,
    required String email,
    required String password,
    DateTime? birthdate,
  }) async {
    try {
      final response = await _apiService.post(
        '${AppConstants.authEndpoint}/register',
        {
          'username': username,
          'email': email,
          'password': password,
          if (birthdate != null) 'birthdate': birthdate.toIso8601String(),
        },
      );

      // save token
      if (response['token'] != null) {
        await _apiService.saveToken(response['token']);
      }

      final user = User.fromJson(response['user']);
      
      // save user id
      if (user.id != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', user.id!);
      }

      return user;
    } catch (e) {
      throw Exception('Erreur lors de l\'inscription: $e');
    }
  }

  Future<User> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.post(
        '${AppConstants.authEndpoint}/login',
        {
          'email': email,
          'password': password,
        },
      );

      // save token
      if (response['token'] != null) {
        await _apiService.saveToken(response['token']);
      }

      final user = User.fromJson(response['user']);
      
      // save user id
      if (user.id != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', user.id!);
      }

      return user;
    } catch (e) {
      throw Exception('Erreur lors de la connexion: $e');
    }
  }

  Future<User> getProfile() async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.get('${AppConstants.authEndpoint}/profile');
      return User.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération du profil: $e');
    }
  }

  Future<void> logout() async {
    await _apiService.removeToken();
  }

  Future<bool> isLoggedIn() async {
    await _apiService.loadToken();
    // try to verify if the token exists by trying to get the profile
    try {
      await getProfile();
      return true;
    } catch (e) {
      return false;
    }
  }
}
