import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/bms_auth.dart';
import '../models/calculate_fee_model.dart';

/// Repository for calculating lab fees, BHYT co-pays, and vouchers (UC53 / Calculate Fees Mobile).
class CalculateFeeRepository {
  final String? baseUrlOverride;
  final http.Client? clientOverride;

  CalculateFeeRepository({this.baseUrlOverride, this.clientOverride});

  List<String> get _bases {
    if (baseUrlOverride != null && baseUrlOverride!.isNotEmpty) {
      return [baseUrlOverride!];
    }
    return const [
      apiBaseUrl,
      'http://10.0.2.2:5000',
    ];
  }

  Map<String, String> get _headers {
    final token = BmsAuth.accessToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Calculates fees by contacting BMS backend or computing with clinical fallbacks.
  Future<CalculateFeeResultModel> calculateFees({
    required List<String> packageIds,
    List<String> individualTestIds = const [],
    String serviceType = 'Clinic',
    String? insuranceCardNumber,
    String? voucherCode,
    bool isPriorityPatient = false,
  }) async {
    final client = clientOverride ?? http.Client();
    final bodyPayload = jsonEncode({
      'packageIds': packageIds,
      'individualTestIds': individualTestIds,
      'serviceType': serviceType,
      'insuranceCardNumber': insuranceCardNumber,
      'voucherCode': voucherCode,
      'isPriorityPatient': isPriorityPatient,
    });

    try {
      for (final base in _bases) {
        try {
          final uri = Uri.parse('$base/api/billing/calculate-fee');
          final res = await client.post(uri, headers: _headers, body: bodyPayload).timeout(const Duration(seconds: 8));

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            if (data['data'] != null) {
              return CalculateFeeResultModel.fromJson(data['data']);
            }
          }
        } catch (_) {}
      }
    } finally {
      if (clientOverride == null) {
        client.close();
      }
    }

    // Offline clinical fallback calculation
    return _computeOfflineFee(
      packageIds: packageIds,
      serviceType: serviceType,
      insuranceCardNumber: insuranceCardNumber,
      voucherCode: voucherCode,
      isPriorityPatient: isPriorityPatient,
    );
  }

  CalculateFeeResultModel _computeOfflineFee({
    required List<String> packageIds,
    required String serviceType,
    String? insuranceCardNumber,
    String? voucherCode,
    bool isPriorityPatient = false,
  }) {
    final isHome = serviceType.toLowerCase() == 'homecollection';
    final homeSurcharge = isHome ? 150000.0 : 0.0;

    final catalog = <String, Map<String, dynamic>>{
      'PKG-CBC-01': {'name': 'Tổng Phân Tích Tế Bào Máu (CBC)', 'price': 150000.0, 'cat': 'Huyết học'},
      'PKG-BIO-01': {'name': 'Sinh Hóa Máu Cơ Bản (Glucose, Ure, Creatinine)', 'price': 250000.0, 'cat': 'Sinh hóa'},
      'PKG-LIPID-01': {'name': 'Bộ Mỡ Máu Toàn Phần (Cholesterol, Triglyceride)', 'price': 220000.0, 'cat': 'Sinh hóa'},
      'PKG-LIVER-01': {'name': 'Bộ Men Gan Đầy Đủ (AST, ALT, GGT)', 'price': 180000.0, 'cat': 'Sinh hóa'},
      'PKG-GENERAL-01': {'name': 'Gói Khám Sức Khỏe Tổng Quát', 'price': 1200000.0, 'cat': 'Tổng quát'},
    };

    double subTotal = 0.0;
    final items = <FeeItemBreakdownModel>[];

    for (final id in packageIds) {
      final item = catalog[id] ?? {'name': 'Gói xét nghiệm #$id', 'price': 200000.0, 'cat': 'Laboratory'};
      final price = (item['price'] as num).toDouble();
      subTotal += price;

      items.add(FeeItemBreakdownModel(
        itemId: id,
        itemCode: id,
        itemName: item['name'] as String,
        category: item['cat'] as String,
        unitPrice: price,
        quantity: 1,
        totalPrice: price,
        isBhytEligible: true,
        bhytCoveredAmount: 0.0,
        patientPayAmount: price,
      ));
    }

    bool hasInsurance = false;
    int coveragePercent = 0;
    double insuranceDeduction = 0.0;
    String tierDesc = '';

    if (insuranceCardNumber != null && insuranceCardNumber.trim().length >= 10) {
      hasInsurance = true;
      final clean = insuranceCardNumber.trim().toUpperCase();
      final prefix = clean.substring(0, 2);

      if (['TE', 'HT', 'HN'].contains(prefix)) {
        coveragePercent = 100;
        tierDesc = 'BHYT chi trả 100% (Đối tượng ưu tiên đặc biệt)';
      } else if (prefix == 'CN') {
        coveragePercent = 95;
        tierDesc = 'BHYT chi trả 95% (Hộ cận nghèo)';
      } else {
        coveragePercent = 80;
        tierDesc = 'BHYT chi trả 80% (Chuẩn BHXH Việt Nam)';
      }

      insuranceDeduction = (subTotal * (coveragePercent / 100.0)).roundToDouble();

      for (var it in items) {
        final covered = (it.totalPrice * (coveragePercent / 100.0)).roundToDouble();
        items[items.indexOf(it)] = FeeItemBreakdownModel(
          itemId: it.itemId,
          itemCode: it.itemCode,
          itemName: it.itemName,
          category: it.category,
          unitPrice: it.unitPrice,
          quantity: it.quantity,
          totalPrice: it.totalPrice,
          isBhytEligible: true,
          bhytCoveredAmount: covered,
          patientPayAmount: it.totalPrice - covered,
        );
      }
    }

    double voucherDiscount = 0.0;
    bool isVoucherValid = false;
    String? voucherDesc;

    if (voucherCode != null && voucherCode.trim().isNotEmpty) {
      final code = voucherCode.trim().toUpperCase();
      if (code == 'BMS10' || code == 'HEALTHY10') {
        isVoucherValid = true;
        voucherDiscount = (subTotal * 0.10).clamp(0.0, 200000.0).roundToDouble();
        voucherDesc = 'Giảm 10% phí xét nghiệm (tối đa 200,000đ)';
      } else if (code == 'BMS20') {
        isVoucherValid = true;
        voucherDiscount = (subTotal * 0.20).clamp(0.0, 500000.0).roundToDouble();
        voucherDesc = 'Giảm 20% phí xét nghiệm (tối đa 500,000đ)';
      } else if (code == 'FREEHOME') {
        isVoucherValid = true;
        voucherDiscount = homeSurcharge;
        voucherDesc = 'Miễn phí phụ phí lấy mẫu tại nhà (150,000đ)';
      } else if (code == 'VIP50') {
        isVoucherValid = true;
        voucherDiscount = 50000.0;
        voucherDesc = 'Giảm trực tiếp 50,000đ';
      }
    }

    double priorityDiscount = 0.0;
    if (isPriorityPatient && coveragePercent < 100) {
      priorityDiscount = ((subTotal - insuranceDeduction) * 0.10).clamp(0.0, 100000.0).roundToDouble();
    }

    final totalDiscount = voucherDiscount + priorityDiscount;
    final gross = subTotal + homeSurcharge;
    final rawNet = (gross - insuranceDeduction - totalDiscount).clamp(0.0, double.infinity);
    final netPayable = ((rawNet / 1000.0).round() * 1000).toDouble();

    return CalculateFeeResultModel(
      calculationReference: 'CALC-MOB-${DateTime.now().millisecondsSinceEpoch}',
      calculatedAt: DateTime.now(),
      items: items,
      testSubTotal: subTotal,
      serviceType: isHome ? 'HomeCollection' : 'Clinic',
      homeCollectionSurcharge: homeSurcharge,
      grossTotal: gross,
      hasInsurance: hasInsurance,
      insuranceCardNumber: insuranceCardNumber,
      insuranceTierDescription: tierDesc,
      insuranceCoveragePercent: coveragePercent,
      insuranceDeduction: insuranceDeduction,
      voucherCode: voucherCode,
      isVoucherValid: isVoucherValid,
      voucherDescription: voucherDesc,
      voucherDiscount: voucherDiscount,
      isPriorityPatient: isPriorityPatient,
      priorityDiscount: priorityDiscount,
      totalDiscount: totalDiscount,
      netTotalPayable: netPayable,
      totalInWords: '${netPayable.toInt()} đồng chẵn',
    );
  }
}
