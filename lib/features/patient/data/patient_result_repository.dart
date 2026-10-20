import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/bms_auth.dart';
import '../models/patient_test_result_model.dart';

/// Repository for patient diagnostic test result retrieval, PDF compilation, and sharing (UC62 / Export Test Results).
/// Connects to BMS backend Web API endpoints per Clean MVC architecture and Zero Mock Data rules.
class PatientResultRepository {
  final String? baseUrlOverride;

  PatientResultRepository({this.baseUrlOverride});

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

  /// Fetches formatted patient test result with reference ranges and doctor notes.
  Future<PatientTestResultModel?> getPatientResult(String orderId) async {
    for (final base in _bases) {
      try {
        final res = await http
            .get(
              Uri.parse('$base/api/testresults/patient/order/$orderId'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['data'] != null) {
            return PatientTestResultModel.fromJson(data['data']);
          }
        }
      } catch (_) {
        // Try fallback host
      }
    }
    return null;
  }

  /// Requests PDF export payload for an order.
  Future<Map<String, dynamic>?> exportResultPdf(String orderId) async {
    for (final base in _bases) {
      try {
        final res = await http
            .get(
              Uri.parse('$base/api/testresults/patient/order/$orderId/export-pdf'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          return data['data'];
        }
      } catch (_) {
        // Try fallback host
      }
    }
    return null;
  }

  /// Generates a secure share link for external consulting doctor.
  Future<Map<String, dynamic>?> shareResultWithDoctor(String orderId) async {
    for (final base in _bases) {
      try {
        final res = await http
            .post(
              Uri.parse('$base/api/testresults/patient/order/$orderId/share'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          return data['data'];
        }
      } catch (_) {
        // Try fallback host
      }
    }
    return null;
  }
}
