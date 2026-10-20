import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/bms_auth.dart';
import '../models/test_result_verification_model.dart';

/// Repository for laboratory technical verification (UC72 / Verify Test Results).
class TestResultVerificationRepository {
  final String? baseUrlOverride;

  TestResultVerificationRepository({this.baseUrlOverride});

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

  /// Fetches technical verification details and checklist for a specimen.
  Future<TestResultVerificationDetailModel?> fetchVerificationDetails(String specimenId) async {
    for (final base in _bases) {
      try {
        final res = await http
            .get(
              Uri.parse('$base/api/laboratory/verification/$specimenId'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['data'] != null) {
            return TestResultVerificationDetailModel.fromJson(data['data']);
          }
        }
      } catch (_) {
        // Fallback
      }
    }
    return null;
  }

  /// Technically verifies specimen results and sends them to doctor approval.
  Future<bool> verifyTestResult(String specimenId, String verifierComment) async {
    final payload = jsonEncode({
      'verifierComment': verifierComment,
    });

    for (final base in _bases) {
      try {
        final res = await http
            .post(
              Uri.parse('$base/api/laboratory/verification/$specimenId/verify'),
              headers: _headers,
              body: payload,
            )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          return true;
        }
      } catch (_) {
        // Fallback
      }
    }
    return false;
  }

  /// Rejects technical verification and returns specimen to lab technician.
  Future<bool> returnTestResult(String specimenId, String returnReason) async {
    final payload = jsonEncode({
      'returnReason': returnReason,
    });

    for (final base in _bases) {
      try {
        final res = await http
            .post(
              Uri.parse('$base/api/laboratory/verification/$specimenId/return'),
              headers: _headers,
              body: payload,
            )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          return true;
        }
      } catch (_) {
        // Fallback
      }
    }
    return false;
  }
}
