import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

class AccountService {
  /// Lấy thông tin tài khoản theo ID
  static Future<Map<String, dynamic>> getAccountById(String id) async {
    try {
      final response = await Api.get('/gateway/admin/accounts/$id');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'] ?? data,
        };
      }
      return {
        'success': false,
        'message': 'Không tìm thấy tài khoản (Mã: ${response.statusCode})',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối khi tải thông tin tài khoản',
      };
    }
  }

  /// Cập nhật thông tin tài khoản
  static Future<Map<String, dynamic>> updateAccount(
    String id, {
    required String username,
    required String email,
    String? password,
    int roleId = 5, // 5 = Patient / Mặc định
    int status = 1, // 1 = Active
  }) async {
    try {
      final payload = <String, dynamic>{
        'username': username,
        'email': email,
        'roleId': roleId,
        'status': status,
      };

      if (password != null && password.isNotEmpty) {
        payload['password'] = password;
      }

      final response = await Api.put('/gateway/admin/accounts/$id', payload);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Đồng bộ cập nhật vào SharedPreferences nếu đây là tài khoản hiện tại
        final prefs = await SharedPreferences.getInstance();
        final currentUserStr = prefs.getString('user');
        if (currentUserStr != null) {
          try {
            final currentUser = jsonDecode(currentUserStr) as Map<String, dynamic>;
            final currentId = currentUser['id']?.toString();
            if (currentId == id) {
              currentUser['username'] = username;
              currentUser['fullName'] = username;
              currentUser['email'] = email;
              await prefs.setString('user', jsonEncode(currentUser));
            }
          } catch (_) {}
        }

        return {
          'success': true,
          'message': data['message'] ?? 'Cập nhật tài khoản thành công',
          'data': data['data'],
        };
      } else if (response.statusCode == 404 || response.statusCode == 400) {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Dữ liệu không hợp lệ hoặc tài khoản không tồn tại',
        };
      } else {
        return {
          'success': false,
          'message': 'Lỗi máy chủ (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối máy chủ khi cập nhật tài khoản',
      };
    }
  }
}
