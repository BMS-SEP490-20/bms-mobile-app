import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Centralized API base URL configuration for development and emulator environments.
/// - Android Emulator: Uses 10.0.2.2 to access host localhost.
/// - Windows Desktop: Uses localhost directly.
/// - Physical Device: Uses LAN IP address of the development workstation.
const String apiBaseUrl = 'http://localhost:5000';

/// Clinical Authentication Service managing user login sessions, JWT storage, and password reset requests.
/// Conforms to: BR-IAM-01, BR-IAM-02 & AGENTS-CODE.md.
class BmsAuth {
  /// Active JWT Bearer access token issued by the backend IAM microservice.
  static String? accessToken;

  /// Long-lived Refresh Token for rolling session renewal.
  static String? refreshToken;

  /// Cached user profile claims (userId, role, fullName, permissions).
  static Map<String, dynamic>? user;

  /// Returns whether a valid user session is currently authenticated in-memory.
  static bool get isLoggedIn =>
      accessToken != null && accessToken!.isNotEmpty;

  /// Authenticates user credentials against the BMS Backend API (/api/auth/login).
  ///
  /// Returns a map containing operation status, server messages, and claims.
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
        // Non-JSON response payload
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

  /// Dispatches a password recovery OTP to the user's registered email address (UC10).
  static Future<Map<String, dynamic>> sendPasswordRecoveryOtp({
    required String email,
  }) async {
    final uri = Uri.parse(
      '$apiBaseUrl/api/auth/forgot-password',
    );

    try {
      debugPrint('[BMS Auth] Dispatching OTP recovery request to $uri');

      final response = await http
          .post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
        }),
      )
          .timeout(const Duration(seconds: 20));

      Map<String, dynamic> data = {};

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {}

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        return {
          'success': true,
          'message': data['message'] ??
              'Yêu cầu gửi OTP đã được tiếp nhận.',
        };
      }

      return {
        'success': false,
        'message': data['message'] ??
            data['title'] ??
            'Gửi OTP thất bại (${response.statusCode}).',
      };
    } catch (e) {
      debugPrint('[BMS Auth] OTP request error: $e');

      return {
        'success': false,
        'message': 'Không thể kết nối API gửi OTP: $e',
      };
    }
  }

  /// Clears active credentials, tokens, and user profile claims from memory.
  static void logout() {
    accessToken = null;
    refreshToken = null;
    user = null;
  }
}