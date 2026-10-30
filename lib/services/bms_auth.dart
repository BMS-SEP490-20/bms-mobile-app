import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/network/api_client.dart';

/// Centralized API base URL configuration for development and emulator environments.
const String apiBaseUrl = 'http://localhost:5000';

/// Clinical Authentication Service managing user login sessions, JWT storage, role checks, and password reset requests.
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

  /// Returns normalized role name of the currently logged-in user (e.g. 'Receptionist', 'Patient', 'Doctor', 'LabUser', 'Admin').
  static String get userRole {
    if (!isLoggedIn || user == null) return '';
    final rawRole = (user!['roleName'] ??
            user!['role'] ??
            user!['RoleName'] ??
            user!['Role'] ??
            '')
        .toString()
        .trim();
    final roleId = int.tryParse((user!['roleId'] ?? user!['RoleId'] ?? '').toString());
    if (roleId == 1 || rawRole.toLowerCase().contains('admin')) {
      return 'Admin';
    }
    if (roleId == 2 || rawRole.toLowerCase().contains('doctor') || rawRole.toLowerCase().contains('bacsi')) {
      return 'Doctor';
    }
    if (roleId == 3 ||
        rawRole.toLowerCase().contains('lab') ||
        rawRole.toLowerCase().contains('tech')) {
      return 'LabUser';
    }
    if (roleId == 4 ||
        rawRole.toLowerCase().contains('recept') ||
        rawRole.toLowerCase().contains('letan')) {
      return 'Receptionist';
    }
    if (roleId == 5 || rawRole.toLowerCase().contains('patient')) {
      return 'Patient';
    }
    if (roleId == 6 ||
        rawRole.toLowerCase().contains('head') ||
        rawRole.toLowerCase().contains('manager')) {
      return 'Manager';
    }
    return rawRole;
  }

  /// Returns true ONLY when the user is authenticated with the Receptionist role.
  static bool get isReceptionist =>
      isLoggedIn && userRole.toLowerCase() == 'receptionist';

  static List<String> get _candidateBaseUrls => const [
        'http://localhost:5000',
        'http://10.0.2.2:5000',
      ];

  /// Authenticates user credentials against the BMS Backend API (/api/auth/login).
  static Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    for (final base in _candidateBaseUrls) {
      try {
        final response = await http
            .post(
              Uri.parse('$base/api/auth/login'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'usernameOrEmail': usernameOrEmail.trim(),
                'password': password,
              }),
            )
            .timeout(const Duration(seconds: 12));

        Map<String, dynamic> data = {};
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            data = decoded;
          }
        } catch (_) {}

        final token = (data['accessToken'] ?? data['token'])?.toString();

        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            token != null &&
            token.isNotEmpty) {
          accessToken = token;
          refreshToken = data['refreshToken']?.toString();
          ApiClient.userToken = token;

          user = data['user'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(data['user'])
              : {};

          return {
            'success': true,
            'message': 'Đăng nhập thành công.',
            'accessToken': accessToken,
            'user': user,
            'role': userRole,
          };
        }

        String errMsg;
        if (response.statusCode == 401) {
          errMsg = (data['message'] ??
                  data['title'] ??
                  'Tên đăng nhập hoặc mật khẩu không chính xác. Vui lòng thử lại!')
              .toString();
        } else if (response.statusCode == 423) {
          errMsg = (data['message'] ??
                  data['title'] ??
                  'Tài khoản tạm thời bị khóa do nhập sai mật khẩu quá 5 lần liên tiếp. Vui lòng thử lại sau.')
              .toString();
        } else {
          errMsg = (data['message'] ??
                  data['title'] ??
                  data['detail'] ??
                  data['error'] ??
                  'Đăng nhập thất bại. Mã lỗi: ${response.statusCode}')
              .toString();
        }

        return {
          'success': false,
          'message': errMsg,
          'statusCode': response.statusCode,
          'code': data['code'],
          'retryAfterMinutes': data['retryAfterMinutes'],
        };
      } catch (_) {}
    }

    return {
      'success': false,
      'message':
          'Không thể kết nối đến máy chủ BMS. Vui lòng kiểm tra dịch vụ mạng hoặc địa chỉ máy chủ.',
    };
  }

  /// Dispatches a password recovery OTP to the user's registered email address (UC10).
  static Future<Map<String, dynamic>> sendPasswordRecoveryOtp({
    required String email,
  }) async {
    Object? lastError;
    for (final base in _candidateBaseUrls) {
      final uri = Uri.parse('$base/api/auth/forgot-password');
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
            .timeout(const Duration(seconds: 15));

        Map<String, dynamic> data = {};
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            data = decoded;
          }
        } catch (_) {}

        if (response.statusCode >= 200 && response.statusCode < 300) {
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
        lastError = e;
      }
    }

    debugPrint('[BMS Auth] OTP request error: $lastError');
    return {
      'success': false,
      'message': 'Không thể kết nối API gửi OTP: $lastError',
    };
  }

  /// Clears active credentials, tokens, and user profile claims from memory.
  static void logout() {
    accessToken = null;
    refreshToken = null;
    user = null;
    ApiClient.userToken = null;
  }
}