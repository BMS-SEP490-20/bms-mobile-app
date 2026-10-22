import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bms_mobile_app/services/bms_auth.dart';
import 'package:bms_mobile_app/features/patient/data/test_history_repository.dart';
import 'package:bms_mobile_app/features/patient/models/test_history_model.dart';
import 'package:bms_mobile_app/features/patient/presentation/screens/test_history_screen.dart';

Map<String, dynamic> summary({bool available = true}) => {
  'id': 'fixture-result',
  'resultCode': 'FIX-1',
  'patientId': 'fixture-patient',
  'sampleId': 'fixture-sample',
  'packageName': 'Fixture panel',
  'createdAt': null,
  'approvedAt': null,
  'available': available,
};
Map<String, dynamic> page() => {
  'items': [summary()],
  'total': 1,
  'page': 1,
  'totalPages': 1,
};
Map<String, dynamic> detail({bool available = true}) => {
  'summary': summary(available: available),
  'items': [
    {
      'code': 'FIX',
      'name': 'Fixture marker',
      'value': '<5',
      'unit': 'fixture-unit',
      'referenceRange': 'Stored range',
      'flag': 'H',
    },
  ],
  'conclusion': 'Fixture conclusion',
};
http.Response response(Object json, [int status = 200]) => http.Response(
  jsonEncode(json),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() {
    BmsAuth.accessToken = 'fixture-session';
    BmsAuth.user = {'role': 'Patient', 'roleId': 9};
  });
  tearDown(BmsAuth.logout);
  test(
    'canonical role IDs and names never inherit the legacy numeric mapping',
    () {
      for (final id in [1, 2, 3, 4, 9]) {
        BmsAuth.user = {'roleId': id};
        expect(TestHistoryRepository.canView, isTrue);
      }
      for (final id in [5, 6, 7, 8]) {
        BmsAuth.user = {'roleId': id};
        expect(TestHistoryRepository.canView, isFalse);
      }
      BmsAuth.user = {'role': 'Nurse', 'roleId': 1};
      expect(TestHistoryRepository.canView, isFalse);
      BmsAuth.logout();
      expect(TestHistoryRepository.canView, isFalse);
    },
  );
  test(
    'transport sends bearer and encoded filters without account identity',
    () async {
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer fixture-session');
        expect(request.url.path, '/api/test-history');
        expect(request.url.queryParameters['search'], '[fixture]');
        expect(request.url.queryParameters['fromDate'], '2026-10-22');
        expect(request.url.queryParameters.containsKey('accountId'), isFalse);
        return response(page());
      });
      final repository = TestHistoryRepository(
        client: client,
        baseUrl: 'http://localhost/api/',
      );
      expect(
        (await repository.list(
          search: '[fixture]',
          fromDate: '2026-10-22',
        )).items.single.createdAt,
        isNull,
      );
      client.close();
    },
  );
  test(
    'HTTP denial, missing data and transport failure never return fake success',
    () async {
      for (final status in [401, 403, 404, 500]) {
        final client = MockClient(
          (_) async => response({'title': 'Fixture failure'}, status),
        );
        final repository = TestHistoryRepository(client: client);
        await expectLater(
          repository.list(),
          throwsA(isA<TestHistoryException>()),
        );
        client.close();
      }
      final client = MockClient(
        (_) async => throw http.ClientException('Fixture offline'),
      );
      await expectLater(
        TestHistoryRepository(client: client).list(),
        throwsA(isA<http.ClientException>()),
      );
      client.close();
    },
  );
  test('response from a previous session is discarded', () async {
    final pending = Completer<http.Response>();
    final client = MockClient((_) => pending.future);
    final request = TestHistoryRepository(client: client).list();
    await Future<void>.delayed(Duration.zero);
    BmsAuth.accessToken = 'different-session';
    pending.complete(response(page()));
    await expectLater(request, throwsA(isA<TestHistoryException>()));
    client.close();
  });
  test(
    'unavailable detail suppresses injected measurements and conclusion',
    () {
      final locked = TestHistoryDetail.fromJson(detail(available: false));
      expect(locked.items, isEmpty);
      expect(locked.conclusion, isNull);
      final published = TestHistoryDetail.fromJson(detail());
      expect(published.items.single.value, '<5');
      expect(published.items.single.referenceRange, 'Stored range');
    },
  );
  testWidgets('signed detail displays real response text and unknown times', (
    tester,
  ) async {
    final client = MockClient(
      (request) async => response(
        request.url.path.endsWith('/fixture-result') ? detail() : page(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TestHistoryScreen(
          repository: TestHistoryRepository(client: client),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fixture panel'), findsOneWidget);
    expect(find.textContaining('<5'), findsNothing);
    await tester.tap(find.text('Fixture panel'));
    await tester.pumpAndSettle();
    expect(find.text('Fixture marker'), findsOneWidget);
    expect(find.text('<5 fixture-unit'), findsOneWidget);
    expect(find.textContaining('Ngày duyệt: Chưa ghi nhận'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    client.close();
  });
  testWidgets('pending detail shows processing without revealing values', (
    tester,
  ) async {
    final client = MockClient(
      (request) async => response(
        request.url.path.endsWith('/fixture-result')
            ? detail(available: false)
            : page(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TestHistoryScreen(
          repository: TestHistoryRepository(client: client),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fixture panel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đang phân tích.'), findsOneWidget);
    expect(find.text('Fixture marker'), findsNothing);
    expect(find.textContaining('Fixture conclusion'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    client.close();
  });
  testWidgets('logged-out screen does not fetch data', (tester) async {
    BmsAuth.logout();
    var called = false;
    final client = MockClient((_) async {
      called = true;
      return response(page());
    });
    await tester.pumpWidget(
      MaterialApp(
        home: TestHistoryScreen(
          repository: TestHistoryRepository(client: client),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(called, isFalse);
    expect(find.text('Đăng nhập'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    client.close();
  });
}
