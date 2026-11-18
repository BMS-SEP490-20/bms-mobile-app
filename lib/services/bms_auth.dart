import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../core/network/bms_http_client.dart';

/// Default API base URL constant retained for backward-compatible repository imports.
const String apiBaseUrl = 'http://localhost:5000';

/// Clinical Authentication & Session Persistence Service.
/// Supports the 3 mobile roles (Patient, Doctor, Receptionist) and detects Web-only workstation roles.
class BmsAuth {
  /// Active JWT Bearer access token.
  static String? accessToken;

  /// Long-lived refresh token for session renewal.
  static String? refreshToken;

  /// Cached user profile claims (id, username, email, fullName, roleId, role).
  static Map<String, dynamic>? user;

  /// Returns true when an access token is active in memory.
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
      case 1:
        return 'Admin';
      case 2:
        return 'Doctor';
      case 3:
        return 'Lab';
      case 4:
        return 'Receptionist';
      case 5:
      case 9:
        return 'Patient';
      case 6:
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

  /// Normalized role name of the currently signed-in user.
  static String get userRole {
    if (!isLoggedIn || user == null) return '';
    return resolveRoleFromMap(user);
  }

  /// Numeric role ID of the currently signed-in user (0 if unknown).
  static int get userRoleId {
    if (!isLoggedIn || user == null) return 0;
    final parsed = int.tryParse(
      (user!['roleId'] ?? user!['RoleId'] ?? user!['role_id'] ?? '')
          .toString()
          .trim(),
    );
    if (parsed != null && parsed > 0) return parsed;
    switch (userRole) {
      case 'Admin':
        return 1;
      case 'Doctor':
        return 2;
      case 'Lab':
        return 3;
      case 'Receptionist':
        return 4;
      case 'Patient':
        return 5;
      case 'Manager':
        return 6;
      default:
        return 0;
    }
  }

  /// Vietnamese display label for the signed-in role.
  static String get roleLabelVi => roleNameVi(userRole);

  static String roleNameVi(String canonicalRole) {
    switch (canonicalRole) {
      case 'Patient':
        return 'Bệnh nhân';
      case 'Doctor':
        return 'Bác sĩ khám bệnh';
      case 'Receptionist':
        return 'Lễ tân tiếp đón';
      case 'Admin':
        return 'Quản trị viên hệ thống';
      case 'Lab':
        return 'Kỹ thuật viên xét nghiệm';
      case 'Manager':
        return 'Quản lý phòng xét nghiệm';
      default:
        return canonicalRole.isEmpty ? 'Chưa xác định' : canonicalRole;
    }
  }

  static bool get isPatient => isLoggedIn && userRole == 'Patient';
  static bool get isDoctor => isLoggedIn && userRole == 'Doctor';
  static bool get isReceptionist => isLoggedIn && userRole == 'Receptionist';

  /// True only for the 3 roles supported on the BMS Mobile App (Patient, Doctor, Receptionist).
  static bool get isMobileSupportedRole =>
      isPatient || isDoctor || isReceptionist;

  /// Current authenticated user account ID.
  static String get currentUserId {
    if (user == null) return '';
    return (user!['id'] ?? user!['userId'] ?? user!['sub'] ?? '')
        .toString()
        .trim();
  }

  /// Current authenticated user display name.
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

  /// Authenticates user credentials via `POST /api/auth/login` and persists session to SharedPreferences.
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
      return {
        'success': false,
        'message': e.message,
      };
    } catch (_) {
      return {
        'success': false,
        'message':
            'Không thể kết nối đến máy chủ BMS. Vui lòng kiểm tra kết nối mạng.',
      };
    }
  }

  /// Restores persisted JWT session on app startup.
  /// Automatically attempts `POST /api/auth/refresh` when the access JWT is expired.
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

  /// Dispatches a password recovery OTP to the user's registered email address.
  static Future<Map<String, dynamic>> sendPasswordRecoveryOtp({
    required String email,
    http.Client? client,
  }) async {
    final transport = BmsHttpClient(client: client);
    try {
      final res = await transport.post(
        '/api/auth/forgot-password',
        includeAuth: false,
        body: {'email': email.trim()},
        timeout: const Duration(seconds: 15),
      );
      if (res.isSuccess) {
        return {
          'success': true,
          'message': res.extractMessage(
            'Nếu email tồn tại trong hệ thống, mã khôi phục đã được gửi.',
          ),
        };
      }
      return {
        'success': false,
        'message': res.extractMessage(
          'Gửi mã xác thực thất bại (Mã lỗi: ${res.statusCode}).',
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
        } catch (_) {
          // Local session remains cleared even when the backend is unreachable.
        }
      }
    } finally {
      if (client == null) transport.close();
    }
  }
}
