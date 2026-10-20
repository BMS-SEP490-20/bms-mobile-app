import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../services/bms_auth.dart';

/// Data layer for UC27 – Reception Queue & Ticket Issuance on Mobile.
class QueueRepository {
  final String? baseUrlOverride;

  QueueRepository({this.baseUrlOverride});

  List<String> get _bases {
    if (baseUrlOverride != null && baseUrlOverride!.isNotEmpty) {
      return [baseUrlOverride!];
    }
    return const [
      apiBaseUrl, // http://localhost:5000
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

  Future<Map<String, dynamic>> fetchLiveQueue() async {
    Object? lastError;
    for (final base in _bases) {
      try {
        final res = await http
            .get(Uri.parse('$base/api/reception/queue'), headers: _headers)
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded is Map<String, dynamic>) {
            return decoded['data'] is Map<String, dynamic>
                ? decoded['data'] as Map<String, dynamic>
                : decoded;
          }
        }
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('Cannot reach queue API: $lastError');
  }

  Future<Map<String, dynamic>> issueTicket({
    String? patientName,
    String? packageName,
    bool isWalkIn = true,
  }) async {
    Object? lastError;
    final payload = {
      'patientName': patientName ?? 'Khách vãng lai',
      'packageName': packageName ?? 'Tổng quát',
      'isWalkIn': isWalkIn,
      'priority': 1,
    };

    for (final base in _bases) {
      try {
        final res = await http
            .post(
              Uri.parse('$base/api/reception/queue/issue'),
              headers: _headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 201 || res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded is Map<String, dynamic>) {
            return decoded['data'] is Map<String, dynamic>
                ? decoded['data'] as Map<String, dynamic>
                : decoded;
          }
        }
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('Cannot issue ticket: $lastError');
  }
}
