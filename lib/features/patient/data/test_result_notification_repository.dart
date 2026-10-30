import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/bms_auth.dart';
import '../models/test_result_notification_model.dart';

/// Repository handling patient test result notification retrieval and read status updates (UC60 / BR-184).
/// Conforms to: Production Medical Standards, Zero Mock Data in production with offline safety & AGENTS-CODE.md.
class TestResultNotificationRepository {
  final String? baseUrlOverride;

  TestResultNotificationRepository({this.baseUrlOverride});

  List<String> get _bases {
    if (baseUrlOverride != null && baseUrlOverride!.isNotEmpty) {
      return [baseUrlOverride!];
    }
    return const [
      apiBaseUrl,
      'http://10.0.2.2:5000',
      'http://localhost:5000',
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

  /// Fetches all test result notifications for a specific patient.
  Future<List<TestResultNotificationModel>> getPatientNotifications(String patientId) async {
    String? lastApiError;
    for (final base in _bases) {
      try {
        final res = await http
            .get(
              Uri.parse('$base/api/notifications/test-results/patient/${Uri.encodeComponent(patientId)}'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['data'] is List) {
            final list = (data['data'] as List)
                .map((e) => TestResultNotificationModel.fromJson(e as Map<String, dynamic>))
                .toList();
            return list;
          }
          return const [];
        } else if (res.statusCode >= 400) {
          try {
            final body = jsonDecode(res.body);
            lastApiError = body['message']?.toString();
          } catch (_) {}
          lastApiError ??= 'Không thể tải danh sách thông báo (Mã lỗi: ${res.statusCode}).';
          break;
        }
      } catch (_) {
        // Fallback to next host
      }
    }

    if (lastApiError != null) {
      throw Exception(lastApiError);
    }

    throw Exception('Không thể kết nối máy chủ xét nghiệm để tải thông báo kết quả.');
  }

  /// Fetches unread notification count for badge display.
  Future<int> getUnreadCount(String patientId) async {
    for (final base in _bases) {
      try {
        final res = await http
            .get(
              Uri.parse('$base/api/notifications/test-results/patient/${Uri.encodeComponent(patientId)}/unread-count'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['data'] is num) {
            return (data['data'] as num).toInt();
          }
        }
      } catch (_) {
        // Continue fallback
      }
    }
    return 0;
  }

  /// Marks a specific notification as read.
  Future<bool> markAsRead(String notificationId) async {
    String? lastApiError;
    for (final base in _bases) {
      try {
        final res = await http
            .put(
              Uri.parse('$base/api/notifications/test-results/${Uri.encodeComponent(notificationId)}/read'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          return true;
        } else if (res.statusCode >= 400) {
          try {
            final body = jsonDecode(res.body);
            lastApiError = body['message']?.toString();
          } catch (_) {}
          lastApiError ??= 'Không thể cập nhật trạng thái đã đọc (Mã lỗi: ${res.statusCode}).';
          break;
        }
      } catch (_) {
        // Continue
      }
    }
    if (lastApiError != null) {
      throw Exception(lastApiError);
    }
    throw Exception('Không thể kết nối máy chủ để cập nhật trạng thái thông báo.');
  }
}
