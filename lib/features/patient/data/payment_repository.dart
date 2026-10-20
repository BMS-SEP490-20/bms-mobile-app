import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/bms_auth.dart';
import '../models/payment_checkout_model.dart';

/// Repository for patient billing fee checkout and payment processing (UC55 / Process Payment).
/// Connects to BMS backend API.
class PaymentRepository {
  final String? baseUrlOverride;

  PaymentRepository({this.baseUrlOverride});

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

  /// Fetches checkout summary for an invoice from backend database.
  Future<PaymentCheckoutModel?> getCheckoutSummary(String invoiceId) async {
    for (final base in _bases) {
      try {
        final res = await http
            .get(
              Uri.parse('$base/api/payments/checkout/$invoiceId'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['data'] != null) {
            return PaymentCheckoutModel.fromJson(data['data']);
          }
        }
      } catch (_) {
        // Try fallback host
      }
    }
    return null;
  }

  /// Validates and applies a discount code.
  Future<Map<String, dynamic>?> applyDiscount(String invoiceId, String discountCode) async {
    for (final base in _bases) {
      try {
        final res = await http
            .post(
              Uri.parse('$base/api/payments/apply-discount'),
              headers: _headers,
              body: jsonEncode({
                'invoiceId': invoiceId,
                'discountCode': discountCode,
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          return jsonDecode(res.body);
        }
      } catch (_) {
        // Try fallback host
      }
    }
    return null;
  }

  /// Submits payment transaction to backend.
  Future<PaymentCheckoutModel?> processPayment(Map<String, dynamic> payload) async {
    for (final base in _bases) {
      try {
        final res = await http
            .post(
              Uri.parse('$base/api/payments/process'),
              headers: _headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['data'] != null) {
            return PaymentCheckoutModel.fromJson(data['data']);
          }
        }
      } catch (_) {
        // Try fallback host
      }
    }
    return null;
  }
}
