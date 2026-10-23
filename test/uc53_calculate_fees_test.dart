import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bms_mobile_app/services/bms_auth.dart';
import 'package:bms_mobile_app/features/patient/data/calculate_fee_repository.dart';
import 'package:bms_mobile_app/features/patient/models/calculate_fee_model.dart';
import 'package:bms_mobile_app/features/patient/presentation/screens/calculate_fees_screen.dart';

Map<String, dynamic> sampleFeeCalculationResponse() => {
  'calculationReference': 'CALC-20261023-999',
  'calculatedAt': '2026-10-23T07:00:00Z',
  'items': [
    {
      'itemId': 'PKG-CBC-01',
      'itemCode': 'CBC-01',
      'itemName': 'Tổng Phân Tích Tế Bào Máu (CBC)',
      'category': 'Hematology',
      'unitPrice': 150000.0,
      'quantity': 1,
      'totalPrice': 150000.0,
      'isBhytEligible': true,
      'bhytCoveredAmount': 120000.0,
      'patientPayAmount': 30000.0,
    },
    {
      'itemId': 'PKG-BIO-01',
      'itemCode': 'BIO-01',
      'itemName': 'Sinh Hóa Máu Cơ Bản',
      'category': 'Biochemistry',
      'unitPrice': 250000.0,
      'quantity': 1,
      'totalPrice': 250000.0,
      'isBhytEligible': true,
      'bhytCoveredAmount': 200000.0,
      'patientPayAmount': 50000.0,
    }
  ],
  'testSubTotal': 400000.0,
  'serviceType': 'HomeCollection',
  'homeCollectionSurcharge': 150000.0,
  'grossTotal': 550000.0,
  'hasInsurance': true,
  'insuranceCardNumber': 'DN4791234567890',
  'insuranceTierDescription': 'BHYT chi trả 80%',
  'insuranceCoveragePercent': 80,
  'insuranceDeduction': 320000.0,
  'voucherCode': 'FREEHOME',
  'isVoucherValid': true,
  'voucherDescription': 'Miễn phí phụ phí lấy mẫu tại nhà',
  'voucherDiscount': 150000.0,
  'isPriorityPatient': false,
  'priorityDiscount': 0.0,
  'totalDiscount': 150000.0,
  'netTotalPayable': 80000.0,
  'totalInWords': 'Tám mươi nghìn đồng chẵn',
  'currency': 'VND',
};

void main() {
  setUp(() {
    BmsAuth.accessToken = 'test-bearer-token';
    BmsAuth.user = {'role': 'Patient', 'roleId': 9};
  });

  tearDown(BmsAuth.logout);

  group('UC53 Calculate Fees - Model Deserialization', () {
    test('CalculateFeeResultModel parses complete JSON response accurately', () {
      final json = sampleFeeCalculationResponse();
      final model = CalculateFeeResultModel.fromJson(json);

      expect(model.calculationReference, 'CALC-20261023-999');
      expect(model.items.length, 2);
      expect(model.testSubTotal, 400000.0);
      expect(model.homeCollectionSurcharge, 150000.0);
      expect(model.grossTotal, 550000.0);
      expect(model.hasInsurance, isTrue);
      expect(model.insuranceCoveragePercent, 80);
      expect(model.insuranceDeduction, 320000.0);
      expect(model.voucherCode, 'FREEHOME');
      expect(model.voucherDiscount, 150000.0);
      expect(model.netTotalPayable, 80000.0);
      expect(model.totalInWords, 'Tám mươi nghìn đồng chẵn');
    });
  });

  group('UC53 Calculate Fees - Repository & Business Rules', () {
    test('Offline calculation engine accurately computes Clinic fees', () async {
      final repo = CalculateFeeRepository();
      final result = await repo.calculateFees(
        packageIds: ['PKG-CBC-01', 'PKG-BIO-01'],
        serviceType: 'Clinic',
      );

      expect(result.testSubTotal, 400000.0);
      expect(result.homeCollectionSurcharge, 0.0);
      expect(result.netTotalPayable, 400000.0);
      expect(result.hasInsurance, isFalse);
    });

    test('Home collection surcharge is added for HomeCollection', () async {
      final repo = CalculateFeeRepository();
      final result = await repo.calculateFees(
        packageIds: ['PKG-CBC-01'],
        serviceType: 'HomeCollection',
      );

      expect(result.testSubTotal, 150000.0);
      expect(result.homeCollectionSurcharge, 150000.0);
      expect(result.grossTotal, 300000.0);
      expect(result.netTotalPayable, 300000.0);
    });

    test('BHYT 80% coverage (DN prefix) deducts from laboratory tests only', () async {
      final repo = CalculateFeeRepository();
      final result = await repo.calculateFees(
        packageIds: ['PKG-CBC-01'], // 150,000
        serviceType: 'HomeCollection', // 150,000 surcharge
        insuranceCardNumber: 'DN4791234567890', // 80% of 150,000 = 120,000
      );

      expect(result.hasInsurance, isTrue);
      expect(result.insuranceCoveragePercent, 80);
      expect(result.insuranceDeduction, 120000.0);
      // Net: 150,000 - 120,000 + 150,000 = 180,000
      expect(result.netTotalPayable, 180000.0);
    });

    test('BHYT 100% coverage (TE prefix) covers all test fees', () async {
      final repo = CalculateFeeRepository();
      final result = await repo.calculateFees(
        packageIds: ['PKG-CBC-01'],
        serviceType: 'Clinic',
        insuranceCardNumber: 'TE1012345678901',
      );

      expect(result.insuranceCoveragePercent, 100);
      expect(result.insuranceDeduction, 150000.0);
      expect(result.netTotalPayable, 0.0);
    });

    test('Voucher FREEHOME waives home collection surcharge', () async {
      final repo = CalculateFeeRepository();
      final result = await repo.calculateFees(
        packageIds: ['PKG-CBC-01'],
        serviceType: 'HomeCollection',
        voucherCode: 'FREEHOME',
      );

      expect(result.isVoucherValid, isTrue);
      expect(result.voucherDiscount, 150000.0);
      expect(result.netTotalPayable, 150000.0);
    });

    test('Net total payable is strictly non-negative', () async {
      final repo = CalculateFeeRepository();
      final result = await repo.calculateFees(
        packageIds: ['PKG-CBC-01'], // 150,000
        insuranceCardNumber: 'TE1012345678901', // 150,000 deduction
        voucherCode: 'VIP50', // 50,000 discount
      );

      expect(result.netTotalPayable >= 0, isTrue);
      expect(result.netTotalPayable, 0.0);
    });
  });

  group('UC53 Calculate Fees - Widget Integration Test', () {
    testWidgets('renders CalculateFeesScreen and shows live fee calculation', (WidgetTester tester) async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'data': sampleFeeCalculationResponse()}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final repo = CalculateFeeRepository(clientOverride: client);

      await tester.pumpWidget(
        MaterialApp(
          home: CalculateFeesScreen(
            repository: repo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header, packages, and breakdown
      expect(find.text('Dự Toán Chi Phí Xét Nghiệm'), findsOneWidget);
      expect(find.text('1. Chọn Gói Xét Nghiệm'), findsOneWidget);
      expect(find.text('2. Hình Thức Lấy Mẫu'), findsOneWidget);
      expect(find.text('3. Bảo Hiểm Y Tế & Chế Độ Ưu Tiên'), findsOneWidget);
      expect(find.text('4. Mã Khuyến Mãi / Voucher'), findsOneWidget);
      expect(find.text('Chi Tiết Bảng Giá'), findsOneWidget);
      expect(find.text('Thanh Toán'), findsOneWidget);
    });
  });
}
