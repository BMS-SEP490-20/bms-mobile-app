import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../core/network/bms_http_client.dart';

/// Resolved active base URL getter for legacy consumers.
String get apiBaseUrl => BmsHttpClient.resolvedBaseUrl;

/// Canonical 6-Role Constants matching BMS Backend & Web Workstation.
class BmsRoles {
  BmsRoles._();
  static const int admin = 1;
  static const int doctor = 2;
  static const int lab = 3;
  static const int receptionist = 4;
  static const int patient = 5;
  static const int manager = 6;
}

/// Clinical Authentication & Session Persistence Service.
/// Supports all 6 canonical roles + Guest mode, with automatic JWT refresh rotation.
class BmsAuth {
  static String? accessToken;
  static String? refreshToken;
  static Map<String, dynamic>? user;

  /// Registered by [BmsMobileApp] so a failed 401 refresh navigates cleanly to `/login`.
  static VoidCallback? onSessionExpired;

  static bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  /// Resolves the canonical role name for any user payload.
  /// Canonical values: 'Admin' (1), 'Doctor' (2), 'Lab' (3), 'Receptionist' (4), 'Patient' (5 or 9), 'Manager' (6).
  static String resolveRoleFromMap(Map<String, dynamic>? source) {
    if (source == null) return '';
    final roleId = int.tryParse(
      (source['roleId'] ?? source['RoleId'] ?? source['role_id'] ?? '')
          .toString()
          .trim(),
    );
    switch (roleId) {
      case BmsRoles.admin:
        return 'Admin';
      case BmsRoles.doctor:
        return 'Doctor';
      case BmsRoles.lab:
        return 'Lab';
      case BmsRoles.receptionist:
        return 'Receptionist';
      case BmsRoles.patient:
      case 9:
        return 'Patient';
      case BmsRoles.manager:
        return 'Manager';
    }

    final rawRole =
        (source['role'] ??
                source['roleName'] ??
                source['Role'] ??
                source['RoleName'] ??
                '')
            .toString()
            .trim();
    final lower = rawRole.toLowerCase();
    if (lower == 'admin' || lower == 'administrator') return 'Admin';
    if (lower == 'doctor' || lower == 'bacsi') return 'Doctor';
    if (lower == 'lab' ||
        lower == 'labuser' ||
        lower == 'labtech' ||
        lower == 'labtechnician') {
      return 'Lab';
    }
    if (lower == 'receptionist' || lower == 'letan') return 'Receptionist';
    if (lower == 'patient' || lower == 'benhnhan') return 'Patient';
    if (lower == 'manager' || lower == 'labhead') return 'Manager';
    return rawRole;
  }

  static String get userRole {
    if (!isLoggedIn || user == null) return '';
    return resolveRoleFromMap(user);
  }

  static int get userRoleId {
    if (!isLoggedIn || user == null) return 0;
    final parsed = int.tryParse(
      (user!['roleId'] ?? user!['RoleId'] ?? user!['role_id'] ?? '')
          .toString()
          .trim(),
    );
    if (parsed == 9) return BmsRoles.patient;
    if (parsed != null && parsed >= 1 && parsed <= 6) return parsed;
    switch (userRole) {
      case 'Admin':
        return BmsRoles.admin;
      case 'Doctor':
        return BmsRoles.doctor;
      case 'Lab':
        return BmsRoles.lab;
      case 'Receptionist':
        return BmsRoles.receptionist;
      case 'Patient':
        return BmsRoles.patient;
      case 'Manager':
        return BmsRoles.manager;
      default:
        return 0;
    }
  }

  static String get roleLabelVi => roleNameVi(userRole);

  static String roleNameVi(String canonicalRole) {
    switch (canonicalRole) {
      case 'Patient':
        return 'Bệnh nhân';
      case 'Doctor':
        return 'Bác sĩ chuyên khoa';
      case 'Receptionist':
        return 'Lễ tân tiếp đón';
      case 'Admin':
        return 'Quản trị viên hệ thống';
      case 'Lab':
        return 'Kỹ thuật viên xét nghiệm';
      case 'Manager':
        return 'Quản lý phòng xét nghiệm';
      default:
        return canonicalRole.isEmpty ? 'Khách' : canonicalRole;
    }
  }

  static bool get isAdmin => isLoggedIn && userRole == 'Admin';
  static bool get isDoctor => isLoggedIn && userRole == 'Doctor';
  static bool get isLab => isLoggedIn && userRole == 'Lab';
  static bool get isReceptionist => isLoggedIn && userRole == 'Receptionist';
  static bool get isPatient => isLoggedIn && userRole == 'Patient';
  static bool get isManager => isLoggedIn && userRole == 'Manager';
  static bool get isStaff =>
      isAdmin || isDoctor || isLab || isReceptionist || isManager;

  static String get currentUserId {
    if (user == null) return '';
    return (user!['id'] ?? user!['userId'] ?? user!['sub'] ?? '')
        .toString()
        .trim();
  }

  static String get currentUserName {
    if (user == null) return '';
    return (user!['fullName'] ??
            user!['full_name'] ??
            user!['name'] ??
            user!['username'] ??
            user!['email'] ??
            '')
        .toString()
        .trim();
  }

  static String get currentUserEmail {
    if (user == null) return '';
    return (user!['email'] ?? '').toString().trim();
  }

  static String get currentUserUsername {
    if (user == null) return '';
    return (user!['username'] ?? '').toString().trim();
  }

  /// Authenticates user credentials via `POST /api/auth/login` and persists session.
  static Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
    http.Client? client,
  }) async {
    final transport = BmsHttpClient(client: client);
    try {
      final res = await transport.post(
        '/api/auth/login',
        includeAuth: false,
        body: {
          'usernameOrEmail': usernameOrEmail.trim(),
          'password': password,
        },
        timeout: const Duration(seconds: 12),
      );

      final map = res.bodyAsMap;
      final payload = map['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['data'] as Map<String, dynamic>)
          : map;
      final token = (payload['accessToken'] ?? payload['token'])
          ?.toString()
          .trim();

      if (res.isSuccess && token != null && token.isNotEmpty) {
        final nextRefresh = payload['refreshToken']?.toString();
        final rawUser = payload['user'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(payload['user'] as Map<String, dynamic>)
            : _extractUserFromJwt(token);

        await _applyAndPersistSession(
          token: token,
          refresh: nextRefresh,
          rawUser: rawUser,
        );

        return {
          'success': true,
          'message': 'Đăng nhập thành công.',
          'accessToken': accessToken,
          'user': user,
          'role': userRole,
        };
      }

      String errMsg;
      if (res.statusCode == 401) {
        errMsg = res.extractMessage(
          'Tên đăng nhập hoặc mật khẩu không chính xác.',
        );
      } else if (res.statusCode == 423) {
        errMsg = res.extractMessage(
          'Tài khoản tạm thời bị khóa do đăng nhập sai quá 5 lần.',
        );
      } else {
        errMsg = res.extractMessage(
          'Đăng nhập thất bại (Mã lỗi: ${res.statusCode}).',
        );
      }

      return {
        'success': false,
        'message': errMsg,
        'statusCode': res.statusCode,
        'code': map['code'],
        'retryAfterMinutes': map['retryAfterMinutes'],
      };
    } on BmsApiException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (_) {
      return {
        'success': false,
        'message':
            'Không thể kết nối đến máy chủ BMS. Vui lòng kiểm tra kết nối mạng.',
      };
    }
  }

  /// Restores persisted JWT session on app startup.
  static Future<bool> restoreSession({http.Client? client}) async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken =
        (prefs.getString('token') ??
                prefs.getString('accessToken') ??
                prefs.getString('bms_access_token') ??
                '')
            .trim();

    if (storedToken.isEmpty) {
      accessToken = null;
      refreshToken = null;
      user = null;
      ApiClient.userToken = null;
      return false;
    }

    final storedRefresh =
        (prefs.getString('refreshToken') ??
                prefs.getString('bms_refresh_token') ??
                '')
            .trim();
    final storedUserJson =
        prefs.getString('user') ?? prefs.getString('bms_user');

    Map<String, dynamic> parsedUser = {};
    if (storedUserJson != null && storedUserJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(storedUserJson);
        if (decoded is Map<String, dynamic>) {
          parsedUser = decoded;
        }
      } catch (_) {}
    }

    bool expired = false;
    if (storedToken.split('.').length == 3) {
      try {
        expired = JwtDecoder.isExpired(storedToken);
        if (parsedUser.isEmpty) {
          parsedUser = _extractUserFromJwt(storedToken);
        }
      } catch (_) {
        expired = true;
      }
    }

    if (expired) {
      if (storedRefresh.isNotEmpty) {
        final refreshed = await _tryRefreshToken(
          storedRefresh,
          fallbackUser: parsedUser,
          client: client,
        );
        if (refreshed) return true;
      }
      await logout(client: client);
      return false;
    }

    await _applyAndPersistSession(
      token: storedToken,
      refresh: storedRefresh.isEmpty ? null : storedRefresh,
      rawUser: parsedUser,
    );
    return true;
  }

  /// Runtime refresh invoked by [BmsHttpClient] on HTTP 401.
  static Future<bool> tryRefreshCurrentSession({http.Client? client}) async {
    var currentRefresh = refreshToken?.trim() ?? '';
    if (currentRefresh.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      currentRefresh =
          (prefs.getString('refreshToken') ??
                  prefs.getString('bms_refresh_token') ??
                  '')
              .trim();
    }
    if (currentRefresh.isEmpty) return false;
    return _tryRefreshToken(
      currentRefresh,
      fallbackUser: user ?? <String, dynamic>{},
      client: client,
    );
  }

  static Future<bool> _tryRefreshToken(
    String refresh, {
    required Map<String, dynamic> fallbackUser,
    http.Client? client,
  }) async {
    final transport = BmsHttpClient(client: client);
    try {
      final res = await transport.post(
        '/api/auth/refresh',
        includeAuth: false,
        body: {'refreshToken': refresh},
        timeout: const Duration(seconds: 8),
      );
      if (!res.isSuccess) return false;

      final map = res.bodyAsMap;
      final payload = map['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['data'] as Map<String, dynamic>)
          : map;
      final nextToken = (payload['accessToken'] ?? payload['token'])
          ?.toString()
          .trim();
      if (nextToken == null || nextToken.isEmpty) return false;

      final nextRefresh = payload['refreshToken']?.toString() ?? refresh;
      final nextUser = payload['user'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(payload['user'] as Map<String, dynamic>)
          : fallbackUser;

      await _applyAndPersistSession(
        token: nextToken,
        refresh: nextRefresh,
        rawUser: nextUser,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _applyAndPersistSession({
    required String token,
    String? refresh,
    required Map<String, dynamic> rawUser,
  }) async {
    accessToken = token;
    refreshToken = refresh;
    ApiClient.userToken = token;

    final normalizedUser = Map<String, dynamic>.from(rawUser);
    final canonical = resolveRoleFromMap(normalizedUser);
    if (canonical.isNotEmpty) {
      normalizedUser['role'] = canonical;
      normalizedUser['roleName'] = canonical;
    }
    if (normalizedUser['roleId'] == 9) {
      normalizedUser['roleId'] = BmsRoles.patient;
    }
    user = normalizedUser;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('accessToken', token);
    if (refresh != null && refresh.isNotEmpty) {
      await prefs.setString('refreshToken', refresh);
    }
    await prefs.setString('user', jsonEncode(normalizedUser));
  }

  static Map<String, dynamic> _extractUserFromJwt(String token) {
    try {
      final claims = JwtDecoder.decode(token);
      final id =
          claims['sub'] ??
          claims['nameid'] ??
          claims['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] ??
          '';
      final username =
          claims['preferred_username'] ??
          claims['unique_name'] ??
          claims['username'] ??
          '';
      final fullName =
          claims['name'] ??
          claims['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'] ??
          username;
      final roleClaim =
          claims['role'] ??
          claims['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ??
          '';
      final roleIdClaim = int.tryParse((claims['role_id'] ?? '').toString());
      return {
        'id': id.toString(),
        'username': username.toString(),
        'fullName': fullName.toString(),
        'email': (claims['email'] ?? '').toString(),
        'roleId': ?roleIdClaim,
        'role': roleClaim is List && roleClaim.isNotEmpty
            ? roleClaim.first.toString()
            : roleClaim.toString(),
      };
    } catch (_) {
      return {};
    }
  }

  /// Step 1 of Forgot Password (matches `authApi.jsx`: `/api/auth/forgot` -> fallback `/api/auth/forgot-password` unless 404).
  static Future<Map<String, dynamic>> sendPasswordRecoveryOtp({
    required String email,
    http.Client? client,
  }) async {
    final transport = BmsHttpClient(client: client);
    try {
      var res = await transport.post(
        '/api/auth/forgot',
        includeAuth: false,
        body: {'email': email.trim()},
        timeout: const Duration(seconds: 15),
      );
      if (!res.isSuccess && res.statusCode != 404) {
        final fallbackRes = await transport.post(
          '/api/auth/forgot-password',
          includeAuth: false,
          body: {'email': email.trim()},
          timeout: const Duration(seconds: 15),
        );
        if (fallbackRes.isSuccess || fallbackRes.statusCode == 404) {
          res = fallbackRes;
        }
      }
      if (res.isSuccess) {
        return {
          'success': true,
          'message': res.extractMessage(
            'Mã OTP khôi phục gồm 6 chữ số đã được gửi đến email của bạn.',
          ),
        };
      }
      return {
        'success': false,
        'statusCode': res.statusCode,
        'message': res.extractMessage(
          'Không thể gửi mã khôi phục. Vui lòng kiểm tra lại địa chỉ email.',
        ),
      };
    } on BmsApiException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (_) {
      return {
        'success': false,
        'message': 'Không thể kết nối máy chủ gửi mã khôi phục.',
      };
    }
  }

  /// Step 2 of Forgot Password: `POST /api/auth/verify-reset-otp`.
  static Future<Map<String, dynamic>> verifyPasswordResetOtp({
    required String email,
    required String otp,
    http.Client? client,
  }) async {
    final transport = BmsHttpClient(client: client);
    try {
      final res = await transport.post(
        '/api/auth/verify-reset-otp',
        includeAuth: false,
        body: {'email': email.trim(), 'otp': otp.trim()},
      );
      if (res.isSuccess) {
        return {
          'success': true,
          'message': res.extractMessage(
            'Mã OTP hợp lệ. Tiếp tục đặt mật khẩu mới.',
          ),
        };
      }
      return {
        'success': false,
        'statusCode': res.statusCode,
        'message': res.extractMessage('Mã OTP không hợp lệ. Vui lòng thử lại.'),
      };
    } on BmsApiException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  /// Step 3 of Forgot Password: `POST /api/auth/reset`.
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmNewPassword,
    http.Client? client,
  }) async {
    final transport = BmsHttpClient(client: client);
    try {
      final res = await transport.post(
        '/api/auth/reset',
        includeAuth: false,
        body: {
          'email': email.trim(),
          'otp': otp.trim(),
          'newPassword': newPassword,
          'confirmNewPassword': confirmNewPassword,
        },
      );
      if (res.isSuccess) {
        return {
          'success': true,
          'message': res.extractMessage(
            'Đặt lại mật khẩu thành công! Vui lòng đăng nhập với mật khẩu mới.',
          ),
        };
      }
      final body = res.bodyAsMap;
      return {
        'success': false,
        'statusCode': res.statusCode,
        'errorCode': body['errorCode']?.toString(),
        'message': res.extractMessage(
          'Đặt lại mật khẩu thất bại. Vui lòng kiểm tra mã OTP.',
        ),
      };
    } on BmsApiException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  /// Clears in-memory and persistent credentials BEFORE revoking refresh token on backend.
  static Future<void> logout({http.Client? client}) async {
    final capturedAccess = accessToken;
    final capturedRefresh = refreshToken;
    accessToken = null;
    refreshToken = null;
    user = null;
    ApiClient.userToken = null;

    final prefs = await SharedPreferences.getInstance();
    final access =
        capturedAccess ??
        prefs.getString('token') ??
        prefs.getString('bms_access_token');
    final refresh =
        capturedRefresh ??
        prefs.getString('refreshToken') ??
        prefs.getString('bms_refresh_token');

    for (final key in const [
      'token',
      'user',
      'accessToken',
      'refreshToken',
      'bms_access_token',
      'bms_refresh_token',
      'bms_user',
      'bms_token',
    ]) {
      await prefs.remove(key);
    }

    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      return;
    }

    final transport = client ?? http.Client();
    try {
      for (final base in BmsHttpClient.candidateBaseUrls) {
        try {
          final response = await transport
              .post(
                Uri.parse('$base/api/auth/logout'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $access',
                },
                body: jsonEncode({'refreshToken': refresh}),
              )
              .timeout(const Duration(seconds: 5));
          if (response.statusCode < 500) break;
        } catch (_) {}
      }
    } finally {
      if (client == null) transport.close();
    }
  }
}
