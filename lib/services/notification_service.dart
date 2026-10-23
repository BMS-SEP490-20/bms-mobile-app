import 'dart:convert';
import 'api.dart';

/// Service responsible for fetching system notification history and updating read states.
/// Utilized by Patient, Doctor, and Staff roles on mobile devices.
class NotificationService {
  /// Retrieves past notifications history for a specific recipient user.
  /// Automatically seeds initial notifications history if none exist.
  static Future<Map<String, dynamic>> getUserNotifications(String userId, {String? role}) async {
    try {
      final roleParam = role != null && role.isNotEmpty ? '?role=$role' : '';
      final response = await Api.get('/gateway/testorder/notification/user/$userId$roleParam');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> list = decoded['data'] ?? [];
        return {
          'success': true,
          'data': list,
        };
      } else {
        return {
          'success': false,
          'message': 'Không thể tải lịch sử thông báo (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối máy chủ thông báo: $e',
      };
    }
  }

  /// Marks a specific notification record as read.
  static Future<bool> markAsRead(String notificationId) async {
    try {
      final response = await Api.put('/gateway/testorder/notification/$notificationId/read', {});
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Marks all notifications for a specific user as read.
  static Future<bool> markAllAsRead(String userId) async {
    try {
      final response = await Api.put('/gateway/testorder/notification/user/$userId/read-all', {});
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
