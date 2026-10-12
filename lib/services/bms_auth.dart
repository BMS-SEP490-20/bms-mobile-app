
import 'dart:convert';
import 'package:http/http.dart' as http;

// Android Emulator: dùng 10.0.2.2 để truy cập localhost của máy tính.
// Windows Desktop: dùng localhost nếu API chạy trên cùng máy.
// Điện thoại thật: dùng IP LAN của máy tính.
const String apiBaseUrl = 'http://localhost:5000';

class BmsAuth {
  static String? accessToken;
  static String? refreshToken;
  static Map<String, dynamic>? user;

  static bool get isLoggedIn =>
      accessToken != null && accessToken!.isNotEmpty;

  static Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse('$apiBaseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'usernameOrEmail': usernameOrEmail.trim(),
          'password': password,
        }),
      )
          .timeout(const Duration(seconds: 20));

      Map<String, dynamic> data = {};

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        // Phản hồi không phải JSON.
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['accessToken'] != null) {
        accessToken = data['accessToken'].toString();
        refreshToken = data['refreshToken']?.toString();

        user = data['user'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(data['user'])
            : {};

        return {
          'success': true,
          'message': 'Đăng nhập thành công.',
        };
      }

      return {
        'success': false,
        'message': data['message'] ??
            data['error'] ??
            'Đăng nhập thất bại. Mã lỗi: ${response.statusCode}',
      };
    } catch (e) {
      return {
        'success': false,
        'message':
        'Không thể kết nối API. Kiểm tra server và địa chỉ API.',
      };
    }
  }

  static void logout() {
    accessToken = null;
    refreshToken = null;
    user = null;
  }
}