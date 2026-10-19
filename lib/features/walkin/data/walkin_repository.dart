import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../services/bms_auth.dart';
import '../domain/walkin_models.dart';

/// UC26 data layer – uses [BmsAuth] for JWT + API base.
class WalkInRepository {
  final String? baseUrlOverride;

  WalkInRepository({this.baseUrlOverride});

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

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    Object? lastError;
    for (final base in _bases) {
      try {
        return await http
            .post(
              Uri.parse('$base$path'),
              headers: _headers,
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('Cannot reach API: $lastError');
  }

  Future<http.Response> _get(String path, [Map<String, String>? query]) async {
    Object? lastError;
    for (final base in _bases) {
      try {
        final uri = Uri.parse('$base$path').replace(queryParameters: query);
        return await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('Cannot reach API: $lastError');
  }

  Future<RegisterWalkInResponse> register(RegisterWalkInRequest request) async {
    if (!BmsAuth.isLoggedIn) {
      throw Exception('Please sign in (Receptionist) to register a walk-in.');
    }

    final res = await _post('/api/walk-in/register', request.toJson());

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception(
        body?['message']?.toString() ?? 'Register failed (${res.statusCode})',
      );
    }
    return RegisterWalkInResponse.fromJson(body ?? {});
  }

  Future<PatientLookupResponse> lookupByIdentity(String identityNumber) async {
    final res = await _get('/api/walk-in/lookup', {
      'identityNumber': identityNumber,
    });
    if (res.statusCode == 200) {
      return PatientLookupResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    return const PatientLookupResponse(exists: false);
  }
}
