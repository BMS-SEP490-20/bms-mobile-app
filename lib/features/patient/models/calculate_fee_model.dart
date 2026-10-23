/// Data models for automated fee calculations, BHYT co-pays, and voucher breakdowns (UC53 / Calculate Fees Mobile).
/// Conforms to: Production Engineering Standards & AGENTS-DESIGN.md.

class FeeItemBreakdownModel {
  final String itemId;
  final String itemCode;
  final String itemName;
  final String category;
  final double unitPrice;
  final int quantity;
  final double totalPrice;
  final bool isBhytEligible;
  final double bhytCoveredAmount;
  final double patientPayAmount;

  FeeItemBreakdownModel({
    required this.itemId,
    required this.itemCode,
    required this.itemName,
    required this.category,
    required this.unitPrice,
    required this.quantity,
    required this.totalPrice,
    required this.isBhytEligible,
    required this.bhytCoveredAmount,
    required this.patientPayAmount,
  });

  factory FeeItemBreakdownModel.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic val) {
      if (val is num) return val.toDouble();
      return double.tryParse(val?.toString() ?? '0') ?? 0.0;
    }

    return FeeItemBreakdownModel(
      itemId: json['itemId']?.toString() ?? '',
      itemCode: json['itemCode']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Laboratory',
      unitPrice: toDouble(json['unitPrice']),
      quantity: json['quantity'] is int ? json['quantity'] : int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      totalPrice: toDouble(json['totalPrice']),
      isBhytEligible: json['isBhytEligible'] == true,
      bhytCoveredAmount: toDouble(json['bhytCoveredAmount']),
      patientPayAmount: toDouble(json['patientPayAmount']),
    );
  }
}

class CalculateFeeResultModel {
  final String calculationReference;
  final DateTime calculatedAt;
  final List<FeeItemBreakdownModel> items;
  final double testSubTotal;
  final String serviceType;
  final double homeCollectionSurcharge;
  final double grossTotal;
  final bool hasInsurance;
  final String? insuranceCardNumber;
  final String? insuranceTierDescription;
  final int insuranceCoveragePercent;
  final double insuranceDeduction;
  final String? voucherCode;
  final bool isVoucherValid;
  final String? voucherDescription;
  final double voucherDiscount;
  final bool isPriorityPatient;
  final double priorityDiscount;
  final double totalDiscount;
  final double netTotalPayable;
  final String totalInWords;
  final String currency;

  CalculateFeeResultModel({
    required this.calculationReference,
    required this.calculatedAt,
    required this.items,
    required this.testSubTotal,
    required this.serviceType,
    required this.homeCollectionSurcharge,
    required this.grossTotal,
    required this.hasInsurance,
    this.insuranceCardNumber,
    this.insuranceTierDescription,
    required this.insuranceCoveragePercent,
    required this.insuranceDeduction,
    this.voucherCode,
    required this.isVoucherValid,
    this.voucherDescription,
    required this.voucherDiscount,
    required this.isPriorityPatient,
    required this.priorityDiscount,
    required this.totalDiscount,
    required this.netTotalPayable,
    required this.totalInWords,
    this.currency = 'VND',
  });

  factory CalculateFeeResultModel.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic val) {
      if (val is num) return val.toDouble();
      return double.tryParse(val?.toString() ?? '0') ?? 0.0;
    }

    final rawItems = json['items'];
    final itemList = <FeeItemBreakdownModel>[];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map<String, dynamic>) {
          itemList.add(FeeItemBreakdownModel.fromJson(it));
        }
      }
    }

    DateTime parsedDate = DateTime.now();
    if (json['calculatedAt'] != null) {
      try {
        parsedDate = DateTime.parse(json['calculatedAt'].toString());
      } catch (_) {}
    }

    return CalculateFeeResultModel(
      calculationReference: json['calculationReference']?.toString() ?? '',
      calculatedAt: parsedDate,
      items: itemList,
      testSubTotal: toDouble(json['testSubTotal']),
      serviceType: json['serviceType']?.toString() ?? 'Clinic',
      homeCollectionSurcharge: toDouble(json['homeCollectionSurcharge']),
      grossTotal: toDouble(json['grossTotal']),
      hasInsurance: json['hasInsurance'] == true,
      insuranceCardNumber: json['insuranceCardNumber']?.toString(),
      insuranceTierDescription: json['insuranceTierDescription']?.toString(),
      insuranceCoveragePercent: json['insuranceCoveragePercent'] is int
          ? json['insuranceCoveragePercent']
          : int.tryParse(json['insuranceCoveragePercent']?.toString() ?? '0') ?? 0,
      insuranceDeduction: toDouble(json['insuranceDeduction']),
      voucherCode: json['voucherCode']?.toString(),
      isVoucherValid: json['isVoucherValid'] == true,
      voucherDescription: json['voucherDescription']?.toString(),
      voucherDiscount: toDouble(json['voucherDiscount']),
      isPriorityPatient: json['isPriorityPatient'] == true,
      priorityDiscount: toDouble(json['priorityDiscount']),
      totalDiscount: toDouble(json['totalDiscount']),
      netTotalPayable: toDouble(json['netTotalPayable']),
      totalInWords: json['totalInWords']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'VND',
    );
  }
}
