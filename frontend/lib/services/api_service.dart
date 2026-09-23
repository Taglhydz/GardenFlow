import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import 'token_storage.dart';

/// Error returned by the API ({ code, message, details }) or by the network.
/// `code` is translated in the UI with 'errors.<code>' (see utils/error_messages.dart).
class ApiException implements Exception {
  ApiException({required this.statusCode, required this.code, required this.message, this.details = const []});

  /// 0 when the server could not be reached
  final int statusCode;
  final String code;
  final String message;
  final List<ApiFieldError> details;

  static const networkError = 'NETWORK_ERROR';

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

class ApiFieldError {
  ApiFieldError(this.field, this.message);

  final String field;
  final String message;
}

/// Thin HTTP client : adds the token, encodes JSON and turns errors into [ApiException].
class ApiService {
  ApiService({
    required TokenStorage tokenStorage,
    required this.onSessionExpired,
    http.Client? client,
  })  : _tokenStorage = tokenStorage,
        _client = client ?? http.Client();

  final TokenStorage _tokenStorage;
  final http.Client _client;

  /// Called when the server rejects our token (expired, account deleted...)
  final void Function() onSessionExpired;

  static const _timeout = Duration(seconds: 15);

  Future<dynamic> get(String endpoint) => _send('GET', endpoint);

  Future<dynamic> post(String endpoint, [Map<String, dynamic>? data]) => _send('POST', endpoint, data);

  Future<dynamic> patch(String endpoint, Map<String, dynamic> data) => _send('PATCH', endpoint, data);

  Future<dynamic> delete(String endpoint) => _send('DELETE', endpoint);

  Future<dynamic> _send(String method, String endpoint, [Map<String, dynamic>? data]) async {
    final token = await _tokenStorage.read();
    final request = http.Request(method, Uri.parse('${AppConstants.baseUrl}$endpoint'))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // skips the ngrok warning page when the API is exposed with ngrok
        'ngrok-skip-browser-warning': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    if (data != null) request.body = json.encode(data);

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(_timeout));
    } on TimeoutException {
      throw ApiException(statusCode: 0, code: ApiException.networkError, message: 'Request timed out');
    } catch (e) {
      throw ApiException(statusCode: 0, code: ApiException.networkError, message: e.toString());
    }

    return _handleResponse(response, hadToken: token != null);
  }

  dynamic _handleResponse(http.Response response, {required bool hadToken}) {
    final body = response.body.isEmpty ? null : _tryDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    final error = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final exception = ApiException(
      statusCode: response.statusCode,
      code: error['code'] as String? ?? 'HTTP_${response.statusCode}',
      message: error['message'] as String? ?? 'Server error',
      details: (error['details'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((d) => ApiFieldError(d['field'] as String? ?? '', d['message'] as String? ?? ''))
          .toList(),
    );

    // our token is no longer valid : the user must log in again
    // (a 401 without token, like wrong credentials on login, is a normal error)
    if (response.statusCode == 401 && hadToken) onSessionExpired();

    throw exception;
  }

  dynamic _tryDecode(String body) {
    try {
      return json.decode(body);
    } on FormatException {
      return null;
    }
  }
}
