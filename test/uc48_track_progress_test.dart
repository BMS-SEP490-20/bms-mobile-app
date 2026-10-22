import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bms_mobile_app/services/bms_auth.dart';
import 'package:bms_mobile_app/features/patient/data/track_progress_repository.dart';
import 'package:bms_mobile_app/features/patient/models/track_progress_model.dart';
import 'package:bms_mobile_app/features/patient/presentation/screens/track_test_progress_screen.dart';

Map<String, dynamic> sampleTrackResponse() => {
  'orderId': 'ORD-2026-001',
  'orderCode': 'ORD-2026-001',
  'barcode': 'BC-998877',
  'patientId': 'PAT-001',
  'patientNameMasked': 'Ng*** P***',
  'isStat': true,
  'currentStage': 'InAnalysis',
  'currentStageName': 'Đang Phân Tích',
  'currentStageIndex': 3,
  'totalStages': 6,
  'overallStatus': 'Processing',
  'orderedAt': '2026-10-23T06:00:00Z',
  'estimatedCompletionTime': '2026-10-23T08:00:00Z',
  'isOverdue': false,
  'isRejected': false,
  'isRerun': false,
  'stages': [
    {
      'stageIndex': 0,
      'code': 'OrderPlaced',
      'title': 'Tiếp nhận chỉ định',
      'description': 'Đã ghi nhận chỉ định xét nghiệm',
      'isCompleted': true,
      'isCurrent': false,
      'isFailed': false,
      'completedAt': '2026-10-23T06:00:00Z',
      'performedBy': 'Lễ tân tiếp nhận',
    },
    {
      'stageIndex': 1,
      'code': 'SampleCollected',
      'title': 'Lấy mẫu bệnh phẩm',
      'description': 'Mẫu đã lấy thành công',
      'isCompleted': true,
      'isCurrent': false,
      'isFailed': false,
      'completedAt': '2026-10-23T06:15:00Z',
      'performedBy': 'KTV Lấy mẫu',
    },
    {
      'stageIndex': 2,
      'code': 'SampleReceived',
      'title': 'Phòng Lab nhận mẫu',
      'description': 'Đã nhận mẫu tại lab',
      'isCompleted': true,
      'isCurrent': false,
      'isFailed': false,
      'completedAt': '2026-10-23T06:25:00Z',
      'performedBy': 'KTV Nhận mẫu',
    },
    {
      'stageIndex': 3,
      'code': 'InAnalysis',
      'title': 'Đang phân tích máy',
      'description': 'Đang chạy phân tích tự động trên máy Cobas',
      'isCompleted': false,
      'isCurrent': true,
      'isFailed': false,
      'completedAt': null,
      'performedBy': 'Máy xét nghiệm Roche Cobas',
    },
    {
      'stageIndex': 4,
      'code': 'ResultEntered',
      'title': 'Đã có kết quả thô',
      'description': 'Chờ bác sĩ chuyên khoa duyệt',
      'isCompleted': false,
      'isCurrent': false,
      'isFailed': false,
      'completedAt': null,
      'performedBy': null,
    },
    {
      'stageIndex': 5,
      'code': 'Approved',
      'title': 'Đã ký duyệt kết quả',
      'description': 'Bác sĩ đã ký duyệt hoàn tất',
      'isCompleted': false,
      'isCurrent': false,
      'isFailed': false,
      'completedAt': null,
      'performedBy': null,
    },
  ],
  'tests': [
    {
      'testId': 'TEST-CBC',
      'testName': 'Tổng phân tích tế bào máu ngoại vi',
      'category': 'Huyết học',
      'status': 'InAnalysis',
      'statusDescription': 'Đang chạy máy',
      'tubeType': 'EDTA (Tím)',
    }
  ],
  'rejectionReason': null,
  'rerunReason': null,
};

void main() {
  setUp(() {
    BmsAuth.accessToken = 'test-bearer-token';
    BmsAuth.user = {'role': 'Patient', 'roleId': 9};
  });

  tearDown(BmsAuth.logout);

  group('UC48 Track Test Progress - Model Deserialization & Business Rules', () {
    test('TrackProgressModel parses complete payload correctly', () {
      final json = sampleTrackResponse();
      final model = TrackProgressModel.fromJson(json);

      expect(model.orderId, 'ORD-2026-001');
      expect(model.barcode, 'BC-998877');
      expect(model.patientNameMasked, 'Ng*** P***');
      expect(model.isStat, isTrue);
      expect(model.currentStage, 'InAnalysis');
      expect(model.currentStageIndex, 3);
      expect(model.totalStages, 6);
      expect(model.stages.length, 6);
      expect(model.tests.length, 1);
      expect(model.tests.first.tubeType, 'EDTA (Tím)');
      expect(model.isOverdue, isFalse);
      expect(model.isRejected, isFalse);
    });

    test('TrackStageItem identifies completed vs current vs pending stages', () {
      final json = sampleTrackResponse();
      final model = TrackProgressModel.fromJson(json);

      expect(model.stages[0].isCompleted, isTrue);
      expect(model.stages[0].isCurrent, isFalse);
      expect(model.stages[3].isCompleted, isFalse);
      expect(model.stages[3].isCurrent, isTrue);
      expect(model.stages[5].isCompleted, isFalse);
      expect(model.stages[5].isCurrent, isFalse);
    });
  });

  group('UC48 Track Test Progress - Repository Tests', () {
    test('trackByIdentifier sends correct query and parses response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/tracking/ORD-2026-001');
        return http.Response(
          jsonEncode({'success': true, 'data': sampleTrackResponse()}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final repo = TrackProgressRepository(clientOverride: client);
      final result = await repo.trackByIdentifier('ORD-2026-001');

      expect(result, isNotNull);
      expect(result!.orderCode, 'ORD-2026-001');
      expect(result.currentStageIndex, 3);
    });

    test('trackByIdentifier returns null on 404 not found', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Order or barcode not found'}),
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final repo = TrackProgressRepository(clientOverride: client);
      final result = await repo.trackByIdentifier('NON-EXISTENT');

      expect(result, isNull);
    });
  });

  group('UC48 Track Test Progress - Widget Integration Tests', () {
    testWidgets('renders search box and displays tracking stages on lookup', (WidgetTester tester) async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'data': sampleTrackResponse()}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final repo = TrackProgressRepository(clientOverride: client);

      await tester.pumpWidget(
        MaterialApp(
          home: TrackTestProgressScreen(
            initialCode: 'ORD-2026-001',
            repository: repo,
          ),
        ),
      );

      // Allow async future to complete
      await tester.pumpAndSettle();

      // Verify header and tracking elements
      expect(find.text('Lộ Trình Mẫu Máu Live'), findsOneWidget);
      expect(find.text('Tra Cứu Tiến Trình Xét Nghiệm'), findsOneWidget);
      expect(find.text('ORD-2026-001'), findsWidgets);
      expect(find.text('Chặng 4/6'), findsOneWidget);
      expect(find.text('Đang thực hiện'), findsWidgets);
      expect(find.text('Tiếp nhận chỉ định'), findsOneWidget);
      expect(find.text('Lấy mẫu bệnh phẩm'), findsOneWidget);
      expect(find.text('Phòng Lab nhận mẫu'), findsOneWidget);
      expect(find.text('Đang phân tích máy'), findsOneWidget);
      expect(find.text('Tổng phân tích tế bào máu ngoại vi'), findsOneWidget);
    });
  });
}
