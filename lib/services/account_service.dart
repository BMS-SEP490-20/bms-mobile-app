import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/bms_http_client.dart';
import 'bms_auth.dart';

/// Real-API Account Service for authenticated user profile read/update (`GET /api/users/me` & `PUT /api/users/{id}`).
/// Zero offline simulation fallbacks. Sends ONLY `{fullName, email, phoneNumber}` on update.
class AccountService {
  static const BmsHttpClient _http = BmsHttpClient();

  /// Retrieves the signed-in user's account profile via `GET /api/users/me`.
  static Future<Map<String, dynamic>> getCurrentAccount() async {
    try {
      final res = await _http.get('/api/users/me');
      if (res.isSuccess) {
        final data = res.data;
        return {
          'success': true,
          'data': data is Map<String, dynamic> ? data : res.bodyAsMap,
        };
      }
      return {
        'success': false,
        'message': res.extractMessage(
          'Không thể tải thông tin tài khoản (Mã: ${res.statusCode}).',
        ),
      };
    } on BmsApiException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  /// Compatibility wrapper loading own account profile.
  static Future<Map<String, dynamic>> getAccountById(String id) async {
    return getCurrentAccount();
  }

  /// Updates the signed-in user's contact profile via `PUT /api/users/{id}`.
  /// Sends ONLY `{fullName, email, phoneNumber}` (never `roleId` or `isActive`).
  static Future<Map<String, dynamic>> updateAccount(
    String id, {
    required String fullName,
    required String email,
    String? phoneNumber,
  }) async {
    try {
      final payload = <String, dynamic>{
        'fullName': fullName.trim(),
        'email': email.trim(),
        if (phoneNumber != null) 'phoneNumber': phoneNumber.trim(),
      };

      final res = await _http.put('/api/users/$id', body: payload);
      if (res.isSuccess) {
        await _syncCachedUser(
          fullName: fullName.trim(),
          email: email.trim(),
          phoneNumber: phoneNumber?.trim(),
        );
        return {
          'success': true,
          'message': res.extractMessage('Cập nhật thông tin tài khoản thành công.'),
          'data': res.data,
        };
      }
      return {
        'success': false,
        'message': res.extractMessage(
          'Cập nhật tài khoản thất bại (Mã: ${res.statusCode}).',
        ),
      };
    } on BmsApiException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  static Future<void> _syncCachedUser({
    required String fullName,
    required String email,
    String? phoneNumber,
  }) async {
    if (BmsAuth.user != null) {
      BmsAuth.user!['fullName'] = fullName;
      BmsAuth.user!['email'] = email;
      if (phoneNumber != null) {
        BmsAuth.user!['phoneNumber'] = phoneNumber;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(BmsAuth.user));
    }
  }
}
