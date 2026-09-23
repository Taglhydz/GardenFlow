import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:GardenFlow/services/api_service.dart';
import 'package:GardenFlow/services/token_storage.dart';

/// In-memory token storage (the real one needs the platform secure storage).
class FakeTokenStorage extends TokenStorage {
  FakeTokenStorage([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> save(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

void main() {
  setUpAll(() => dotenv.loadFromString(envString: 'API_BASE_URL=http://test.local/api'));

  late int sessionExpiredCalls;
  late http.Request lastRequest;

  ApiService buildApi(http.Response Function(http.Request) handler, {String? token}) {
    sessionExpiredCalls = 0;
    return ApiService(
      tokenStorage: FakeTokenStorage(token),
      onSessionExpired: () => sessionExpiredCalls++,
      client: MockClient((request) async {
        lastRequest = request;
        return handler(request);
      }),
    );
  }

  http.Response jsonResponse(Object body, int status) =>
      http.Response(json.encode(body), status, headers: {'content-type': 'application/json'});

  test('sends the token and JSON body, decodes the response', () async {
    final api = buildApi((_) => jsonResponse({'id': 1}, 201), token: 'abc');

    final result = await api.post('/gardens', {'name': 'Potager'});

    expect(result, {'id': 1});
    expect(lastRequest.url.toString(), 'http://test.local/api/gardens');
    expect(lastRequest.method, 'POST');
    expect(lastRequest.headers['Authorization'], 'Bearer abc');
    expect(json.decode(lastRequest.body), {'name': 'Potager'});
  });

  test('204 No Content returns null', () async {
    final api = buildApi((_) => http.Response('', 204), token: 'abc');
    expect(await api.delete('/gardens/1'), isNull);
  });

  test('API errors become ApiException with code and field details', () async {
    final api = buildApi((_) => jsonResponse({
          'code': 'VALIDATION_ERROR',
          'message': 'Invalid request body',
          'details': [
            {'field': 'name', 'message': 'Required'},
          ],
        }, 400));

    final error = await api.post('/gardens', {}).then<ApiException?>((_) => null, onError: (e) => e as ApiException);

    expect(error!.statusCode, 400);
    expect(error.code, 'VALIDATION_ERROR');
    expect(error.details.single.field, 'name');
  });

  test('an error without JSON body still gives a code', () async {
    final api = buildApi((_) => http.Response('<html>Bad gateway</html>', 502));

    expect(
      () => api.get('/gardens'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'HTTP_502')),
    );
  });

  test('401 with a token -> session expired callback', () async {
    final api = buildApi((_) => jsonResponse({'code': 'INVALID_TOKEN', 'message': 'expired'}, 401), token: 'old');

    await expectLater(api.get('/gardens'), throwsA(isA<ApiException>()));
    expect(sessionExpiredCalls, 1);
  });

  test('401 without token (wrong credentials) -> no session expired callback', () async {
    final api = buildApi((_) => jsonResponse({'code': 'INVALID_CREDENTIALS', 'message': 'wrong'}, 401));

    await expectLater(
      api.post('/auth/login', {'email': 'a@b.c', 'password': 'x'}),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS')),
    );
    expect(sessionExpiredCalls, 0);
  });

  test('network failure -> NETWORK_ERROR', () async {
    final api = buildApi((_) => throw http.ClientException('connection refused'));

    expect(
      () => api.get('/gardens'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiException.networkError)
          .having((e) => e.statusCode, 'statusCode', 0)),
    );
  });
}
