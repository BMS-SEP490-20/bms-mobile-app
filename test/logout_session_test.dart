import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bms_mobile_app/services/bms_auth.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'token': 'stored-access',
      'user': '{}',
      'refreshToken': 'stored-refresh',
    }),
  );
  test(
    'Logout clears saved startup credentials and revokes the refresh token',
    () async {
      var called = false;
      await BmsAuth.logout(
        client: MockClient((request) async {
          called = true;
          expect(request.url.path, '/api/auth/logout');
          expect(request.headers['Authorization'], 'Bearer stored-access');
          expect(jsonDecode(request.body)['refreshToken'], 'stored-refresh');
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('token'), isNull);
          return http.Response('', 204);
        }),
      );
      expect(called, isTrue);
      expect(BmsAuth.isLoggedIn, isFalse);
    },
  );
  test(
    'Offline logout still clears memory and persistent credentials',
    () async {
      BmsAuth.accessToken = 'active';
      await BmsAuth.logout(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
      expect(BmsAuth.accessToken, isNull);
    },
  );
}
