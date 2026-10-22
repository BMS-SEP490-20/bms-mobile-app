import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/network/api_client.dart';
import '../../../services/bms_auth.dart';
import '../models/test_history_model.dart';

/// Strict UC76 transport using the active session and existing API base. No demo or host fallback.
class TestHistoryRepository {
  final http.Client _client;
  final bool _ownsClient;
  final String baseUrl;
  TestHistoryRepository({
    http.Client? client,
    this.baseUrl = const String.fromEnvironment(
      'BMS_API_BASE_URL',
      defaultValue: ApiClient.baseUrl,
    ),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  /// Raw canonical role claims avoid the legacy auth helper's different numeric role mapping.
  static bool get canView {
    if (!BmsAuth.isLoggedIn) return false;
    final user = BmsAuth.user ?? {};
    final role =
        (user['roleName'] ??
                user['role'] ??
                user['RoleName'] ??
                user['Role'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();
    if (role.isNotEmpty) {
      return const [
        'admin',
        'administrator',
        'manager',
        'doctor',
        'labhead',
        'labtech',
        'labtechnician',
        'patient',
      ].contains(role);
    }
    return const [
      '1',
      '2',
      '3',
      '4',
      '9',
    ].contains((user['roleId'] ?? user['RoleId']).toString());
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    if (!canView) {
      throw const TestHistoryException(
        'Vui lòng đăng nhập bằng tài khoản có quyền xem lịch sử.',
      );
    }
    final token = BmsAuth.accessToken!;
    final response = await _client
        .get(
          Uri.parse(
            '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/test-history$path',
          ).replace(queryParameters: query),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (BmsAuth.accessToken != token) {
      throw const TestHistoryException(
        'Phiên đăng nhập đã thay đổi. Vui lòng mở lại lịch sử.',
      );
    }
    if (response.statusCode == 401) {
      throw const TestHistoryException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
    if (response.statusCode == 403) {
      throw const TestHistoryException('Bạn không có quyền xem lịch sử này.');
    }
    if (response.statusCode == 404) {
      throw const TestHistoryException(
        'Không tìm thấy kết quả trong phạm vi được phép truy cập.',
      );
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw TestHistoryException(
        body is Map
            ? (body['title'] ?? body['message'] ?? 'Không thể tải lịch sử.')
                  .toString()
            : 'Không thể tải lịch sử.',
      );
    }
    if (body is! Map<String, dynamic>) {
      throw const TestHistoryException('Phản hồi lịch sử không hợp lệ.');
    }
    return body;
  }

  Future<TestHistoryPage> list({
    String search = '',
    String patientId = '',
    String fromDate = '',
    String toDate = '',
    int page = 1,
  }) async => TestHistoryPage.fromJson(
    await _get(
      '',
      {
        'search': search,
        'patientId': patientId,
        'fromDate': fromDate,
        'toDate': toDate,
        'page': '$page',
        'pageSize': '20',
      }..removeWhere((key, value) => value.isEmpty),
    ),
  );
  Future<TestHistoryDetail> detail(String id) async =>
      TestHistoryDetail.fromJson(await _get('/${Uri.encodeComponent(id)}', {}));
  void dispose() {
    if (_ownsClient) _client.close();
  }
}

/// Safe user-facing transport failures, without exposing raw response bodies or stack traces.
class TestHistoryException implements Exception {
  final String message;
  const TestHistoryException(this.message);
  @override
  String toString() => message;
}
