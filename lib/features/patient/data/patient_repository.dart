import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../services/bms_auth.dart';
import '../models/guest_profile_model.dart';

/// Repository communicating with `/api/patients` and `/api/patients/guests`
/// for Create Guest Profile (UC25 – Mobile) and View Patient Information.
class PatientRepository {
  final String baseUrl;
  final http.Client _client;

  PatientRepository({
    this.baseUrl = 'http://localhost:5000',
    http.Client? client,
  }) : _client = client ?? http.Client();

  List<String> get _candidateBaseUrls {
    final urls = <String>[baseUrl];
    if (!urls.contains('http://10.0.2.2:5000')) {
      urls.add('http://10.0.2.2:5000');
    }
    if (!urls.contains('http://localhost:5000')) {
      urls.add('http://localhost:5000');
    }
    return urls;
  }

  String? get _activeToken =>
      (BmsAuth.accessToken != null && BmsAuth.accessToken!.isNotEmpty)
          ? BmsAuth.accessToken
          : ApiClient.userToken;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_activeToken != null && _activeToken!.isNotEmpty)
          'Authorization': 'Bearer $_activeToken',
      };

  /// Creates a new walk-in / guest patient profile (`POST /api/patients/guests`).
  /// Restricted to authenticated Receptionist role.
  ///
  /// Throws [PatientApiException] on auth errors (401/403), validation errors (400), or duplicate conflicts (409).
  Future<PatientProfileModel> createGuestProfile(
    CreateGuestProfileRequestModel request,
  ) async {
    if (!BmsAuth.isReceptionist) {
      throw PatientApiException(
        'Chỉ tài khoản Lễ Tân (Receptionist) mới có quyền tạo hồ sơ khách vãng lai.',
        statusCode: 403,
      );
    }

    Object? lastError;

    for (final candidate in _candidateBaseUrls) {
      final uri = Uri.parse('$candidate/api/patients/guests');
      try {
        final response = await _client
            .post(
              uri,
              headers: _headers,
              body: jsonEncode(request.toJson()),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final dataMap = (decoded['data'] is Map<String, dynamic>)
              ? decoded['data'] as Map<String, dynamic>
              : decoded;
          return PatientProfileModel.fromJson(dataMap);
        }

        final fallbackMsg = response.statusCode == 401 ||
                response.statusCode == 403
            ? 'Chỉ tài khoản Lễ Tân (Receptionist) mới có quyền tạo hồ sơ khách vãng lai.'
            : response.statusCode == 409
                ? 'Hồ sơ bệnh nhân (CCCD hoặc SĐT + Họ tên) đã tồn tại trong hệ thống.'
                : 'Dữ liệu hồ sơ khách vãng lai không hợp lệ (${response.statusCode}).';

        final errMsg = _extractErrorMessage(response.body, fallbackMsg);
        throw PatientApiException(
          errMsg,
          statusCode: response.statusCode,
          isDuplicateConflict: response.statusCode == 409,
        );
      } on PatientApiException {
        rethrow;
      } catch (e) {
        lastError = e;
      }
    }

    throw PatientApiException(
      'Không thể kết nối máy chủ BMS Backend: $lastError',
    );
  }

  /// Searches patient / guest profiles (`GET /api/patients`) for duplicate checking and directory listing.
  Future<List<PatientProfileModel>> searchPatients({
    String? search,
    bool? isGuest,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (isGuest != null) {
      query['isGuest'] = isGuest.toString();
    }

    Object? lastError;
    for (final candidate in _candidateBaseUrls) {
      final uri = Uri.parse('$candidate/api/patients')
          .replace(queryParameters: query);
      try {
        final response = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final rawItems = decoded['items'] as List<dynamic>? ??
                decoded['Items'] as List<dynamic>? ??
                decoded['data'] as List<dynamic>? ??
                const [];
            return rawItems
                .whereType<Map<String, dynamic>>()
                .map(PatientProfileModel.fromJson)
                .toList();
          } else if (decoded is List<dynamic>) {
            return decoded
                .whereType<Map<String, dynamic>>()
                .map(PatientProfileModel.fromJson)
                .toList();
          }
        }
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) {
      throw PatientApiException('Lỗi kết nối khi tra cứu hồ sơ: $lastError');
    }
    return const [];
  }

  /// Retrieves a single patient / guest profile by ID, Patient Code, or CCCD (`GET /api/patients/{id}`).
  Future<PatientProfileModel?> getPatientById(String idOrCode) async {
    final encoded = Uri.encodeComponent(idOrCode.trim());
    for (final candidate in _candidateBaseUrls) {
      final uri = Uri.parse('$candidate/api/patients/$encoded');
      try {
        final response = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 404) return null;
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final dataMap = (decoded['data'] is Map<String, dynamic>)
              ? decoded['data'] as Map<String, dynamic>
              : decoded;
          return PatientProfileModel.fromJson(dataMap);
        }
      } catch (_) {}
    }
    return null;
  }

  String _extractErrorMessage(String rawBody, String fallback) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        if (decoded['errors'] is Map<String, dynamic>) {
          final errs = (decoded['errors'] as Map<String, dynamic>)
              .values
              .expand((v) => v is Iterable ? v : [v])
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
          if (errs.isNotEmpty) return errs.join(' ');
        }
        return (decoded['detail'] ??
                decoded['message'] ??
                decoded['title'] ??
                fallback)
            .toString();
      }
    } catch (_) {}
    return fallback;
  }

  void dispose() {
    _client.close();
  }
}

/// Exception thrown by [PatientRepository].
class PatientApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isDuplicateConflict;

  PatientApiException(
    this.message, {
    this.statusCode,
    this.isDuplicateConflict = false,
  });

  @override
  String toString() => message;
}
