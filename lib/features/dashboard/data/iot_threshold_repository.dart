import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/bms_auth.dart';
import '../models/iot_threshold_model.dart';

/// Repository for IoT environmental monitoring thresholds (UC67 / Configure IoT Thresholds).
class IotThresholdRepository {
  final String? baseUrlOverride;

  IotThresholdRepository({this.baseUrlOverride});

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

  /// Fetches summary of all IoT thresholds and recipients.
  Future<IotConfigSummaryModel?> fetchSummary() async {
    for (final base in _bases) {
      try {
        final res = await http
            .get(
              Uri.parse('$base/api/iot/thresholds'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['data'] != null) {
            return IotConfigSummaryModel.fromJson(data['data']);
          }
        }
      } catch (_) {
        // Fallback
      }
    }
    return null;
  }

  /// Batch updates multiple IoT thresholds.
  Future<bool> batchUpdateThresholds(List<IotThresholdModel> thresholds) async {
    final payload = jsonEncode({
      'devices': thresholds
          .map((t) => {
                'deviceId': t.deviceId,
                'lowAlert': t.lowAlert,
                'highAlert': t.highAlert,
                'intervalSeconds': t.intervalSeconds,
              })
          .toList(),
    });

    for (final base in _bases) {
      try {
        final res = await http
            .post(
              Uri.parse('$base/api/iot/thresholds/batch'),
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

  /// Resets thresholds to regulatory defaults.
  Future<bool> resetDefaults() async {
    for (final base in _bases) {
      try {
        final res = await http
            .post(
              Uri.parse('$base/api/iot/thresholds/reset-defaults'),
              headers: _headers,
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
