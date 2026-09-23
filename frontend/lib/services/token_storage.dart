import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';

/// Stores the JWT in the platform secure storage (Keychain on iOS, Keystore on Android)
/// instead of SharedPreferences, which is a plain text file.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  // kept in memory to avoid reading the secure storage on every request
  String? _token;
  bool _loaded = false;

  Future<String?> read() async {
    if (!_loaded) {
      _token = await _storage.read(key: AppConstants.tokenKey);
      _loaded = true;
    }
    return _token;
  }

  Future<void> save(String token) async {
    _token = token;
    _loaded = true;
    await _storage.write(key: AppConstants.tokenKey, value: token);
  }

  Future<void> clear() async {
    _token = null;
    _loaded = true;
    await _storage.delete(key: AppConstants.tokenKey);
  }
}
