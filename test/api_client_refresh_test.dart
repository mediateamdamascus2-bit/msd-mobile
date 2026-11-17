import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:msd_mobile/api_client.dart';
import 'package:msd_mobile/services/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsStore.instance.init();
  });

  test('expired token → successful refresh → retry POST uses the new token', () async {
    final authHeaders = <String>[];
    var eventPosts = 0;
    var refreshCalls = 0;

    final mock = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/api/auth/refresh')) {
        refreshCalls++;
        expect(jsonDecode(request.body)['refreshToken'], 'refresh-old');
        return http.Response(
          jsonEncode({'accessToken': 'access-new', 'refreshToken': 'refresh-new'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/api/auth/logout')) {
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      }
      if (path.endsWith('/api/facilities/harasta/events') && request.method == 'POST') {
        eventPosts++;
        final auth = request.headers['Authorization'] ?? '';
        authHeaders.add(auth);
        if (auth == 'Bearer access-old') {
          return http.Response(
            jsonEncode({'title': 'Unauthorized'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        if (auth == 'Bearer access-new') {
          return http.Response(
            jsonEncode({'id': 'ev-1', 'title': 'ok'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('unexpected auth: $auth', 500);
      }
      return http.Response('not found: $path', 404);
    });

    final api = ApiClient(httpClient: mock);
    api.debugSetSession(accessToken: 'access-old', refreshToken: 'refresh-old');

    final created = await api.createFacilityEvent(
      'harasta',
      title: 'اختبار',
      kind: 'طبي',
      severity: 'متوسط',
    );

    expect(created['id'], 'ev-1');
    expect(refreshCalls, 1);
    expect(eventPosts, 2);
    expect(authHeaders, ['Bearer access-old', 'Bearer access-new']);
  });

  test('failed refresh does not retry the original POST', () async {
    var eventPosts = 0;
    var refreshCalls = 0;

    final mock = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/api/auth/refresh')) {
        refreshCalls++;
        return http.Response('{}', 401, headers: {'content-type': 'application/json'});
      }
      if (path.endsWith('/api/auth/logout')) {
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      }
      if (path.endsWith('/api/facilities/harasta/events') && request.method == 'POST') {
        eventPosts++;
        return http.Response(
          jsonEncode({'title': 'Unauthorized'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

    final api = ApiClient(httpClient: mock);
    api.debugSetSession(accessToken: 'access-old', refreshToken: 'refresh-old');

    await expectLater(
      () => api.createFacilityEvent(
        'harasta',
        title: 'اختبار',
        kind: 'طبي',
        severity: 'متوسط',
      ),
      throwsA(isA<Exception>()),
    );

    expect(refreshCalls, 1);
    expect(eventPosts, 1, reason: 'must not re-POST after failed refresh');
  });
}
