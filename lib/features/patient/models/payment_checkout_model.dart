/// Data model representing patient billing fee checkout and payment details (UC55 / Process Payment).
/// Conforms to: Production Standards & AGENTS.md.
class PaymentCheckoutModel {
  final String invoiceId;
  final String invoiceCode;
  final String patientId;
  final String patientName;
  final String? patientPhone;
  final String? appointmentId;
  final String packageName;
  final double subTotal;
  final double serviceFee;
  final double discountAmount;
  final String? discountCode;
  final double totalAmount;
  final String status;
  final String? paymentMethod;
  final String? transactionReference;
  final DateTime? paidAt;
  final String? paymentUrl;
  final String? qrCodePayload;
  final String message;

  const PaymentCheckoutModel({
    required this.invoiceId,
    required this.invoiceCode,
    required this.patientId,
    required this.patientName,
    this.patientPhone,
    this.appointmentId,
    required this.packageName,
    required this.subTotal,
    required this.serviceFee,
    required this.discountAmount,
    this.discountCode,
    required this.totalAmount,
    required this.status,
    this.paymentMethod,
    this.transactionReference,
    this.paidAt,
    this.paymentUrl,
    this.qrCodePayload,
    required this.message,
  });

  factory PaymentCheckoutModel.fromJson(Map<String, dynamic> json) {
    // Extract primary item name if present
    String resolvedPackage = 'Clinical Laboratory Services';
    if (json['items'] is List && (json['items'] as List).isNotEmpty) {
      final first = (json['items'] as List).first;
      if (first is Map && first['itemName'] != null) {
        resolvedPackage = first['itemName'].toString();
      }
    }

    return PaymentCheckoutModel(
      invoiceId: json['invoiceId']?.toString() ?? json['id']?.toString() ?? '',
      invoiceCode: json['invoiceCode']?.toString() ?? 'INV-CHECKOUT',
      patientId: json['patientId']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? 'Patient',
      patientPhone: json['patientPhone']?.toString(),
      appointmentId: json['appointmentId']?.toString(),
      packageName: resolvedPackage,
      subTotal: (json['subTotal'] is num) ? (json['subTotal'] as num).toDouble() : 0.0,
      serviceFee: (json['serviceFee'] is num) ? (json['serviceFee'] as num).toDouble() : 0.0,
      discountAmount: (json['discountAmount'] is num) ? (json['discountAmount'] as num).toDouble() : 0.0,
      discountCode: json['discountCode']?.toString(),
      totalAmount: (json['totalAmount'] is num) ? (json['totalAmount'] as num).toDouble() : 0.0,
      status: json['status']?.toString() ?? 'Unpaid',
      paymentMethod: json['paymentMethod']?.toString(),
      transactionReference: json['transactionReference']?.toString(),
      paidAt: json['paidAt'] != null ? DateTime.tryParse(json['paidAt'].toString()) : null,
      paymentUrl: json['paymentUrl']?.toString(),
      qrCodePayload: json['qrCodePayload']?.toString(),
      message: json['message']?.toString() ?? '',
    );
  }
}
