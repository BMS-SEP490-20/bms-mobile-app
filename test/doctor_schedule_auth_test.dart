import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bms_mobile_app/services/bms_auth.dart';
import 'package:bms_mobile_app/features/doctor-schedule/data/schedule_repository.dart';

void main() {
  tearDown(BmsAuth.logout);
  test(
    'Doctor schedule sends session bearer and preserves configured host',
    () async {
      BmsAuth.accessToken = 'fixture';
      final repository = ScheduleRepository(
        baseUrl: 'http://fixture.invalid',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer fixture');
          expect(request.url.host, 'fixture.invalid');
          expect(request.url.queryParameters['date'], '2026-11-08');
          return http.Response(jsonEncode({}), 200);
        }),
      );
      await repository.getDaySchedule(date: '2026-11-08');
      repository.dispose();
    },
  );
  test(
    'Doctor schedule never converts forbidden responses to success',
    () async {
      final repository = ScheduleRepository(
        client: MockClient((_) async => http.Response('{}', 403)),
      );
      await expectLater(
        repository.getDaySchedule(),
        throwsA(isA<ScheduleException>()),
      );
      repository.dispose();
    },
  );
}
