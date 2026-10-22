import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/bms_auth.dart';
import '../models/track_progress_model.dart';

/// Repository for retrieving specimen 6-stage lifecycle progress on mobile (UC48 / Track Test Progress).
/// Connects to BMS backend Web API endpoints.
class TrackProgressRepository {
  final String? baseUrlOverride;
  final http.Client? clientOverride;

  TrackProgressRepository({this.baseUrlOverride, this.clientOverride});

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

  /// Fetches specimen 6-stage lifecycle progress by Order Number or Barcode.
  Future<TrackProgressModel?> getTracking(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return null;

    final client = clientOverride ?? http.Client();
    try {
      for (final base in _bases) {
        try {
          final uri = Uri.parse('$base/api/tracking/${Uri.encodeComponent(cleanCode)}');
          final res = await client.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            if (data['data'] != null) {
              return TrackProgressModel.fromJson(data['data']);
            }
          }
        } catch (_) {
          // Fallback to next host candidate
        }
      }
    } finally {
      if (clientOverride == null) {
        client.close();
      }
    }
    return null;
  }

  /// Alias for getTracking
  Future<TrackProgressModel?> trackByIdentifier(String code) => getTracking(code);

  /// Fetches active trackings for a logged-in patient.
  Future<List<TrackProgressModel>> getPatientTrackings(String patientId) async {
    final cleanId = patientId.trim();
    if (cleanId.isEmpty) return [];

    final client = clientOverride ?? http.Client();
    try {
      for (final base in _bases) {
        try {
          final uri = Uri.parse('$base/api/tracking/patient/${Uri.encodeComponent(cleanId)}');
          final res = await client.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final rawList = data['data'];
            if (rawList is List) {
              return rawList.map((e) => TrackProgressModel.fromJson(e)).toList();
            }
          }
        } catch (_) {}
      }
    } finally {
      if (clientOverride == null) {
        client.close();
      }
    }
    return [];
  }
}
