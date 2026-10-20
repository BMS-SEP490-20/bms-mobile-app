import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/bms_auth.dart';
import '../models/sample_origin_trace_model.dart';

/// Repository for specimen origin traceability (UC77 / Trace Sample Origin).
class SampleOriginTraceRepository {
  final String? baseUrlOverride;

  SampleOriginTraceRepository({this.baseUrlOverride});

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

  /// Fetches origin trace nodes and custody chain for a specimen.
  Future<SampleOriginTraceModel?> fetchOriginTrace(String specimenId) async {
    for (final base in _bases) {
      try {
        final res = await http
            .get(
              Uri.parse('$base/api/laboratory/trace/$specimenId'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['data'] != null) {
            return SampleOriginTraceModel.fromJson(data['data']);
          }
        }
      } catch (_) {
        // Fallback
      }
    }
    return null;
  }
}
