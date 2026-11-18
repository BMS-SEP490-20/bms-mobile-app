import 'bms_http_client.dart';

/// Data model representing the response from the Send OTP API.
class SendOtpResult {
  final bool isSuccess;
  final String message;
  final int cooldownSeconds;
  final bool isRateLimited;

  const SendOtpResult({
    required this.isSuccess,
    required this.message,
    this.cooldownSeconds = 60,
    this.isRateLimited = false,
  });
}

/// Data model representing the response from the Verify OTP API.
class VerifyOtpResult {
  final bool isSuccess;
  final String message;
  final String? verificationToken;

  const VerifyOtpResult({
    required this.isSuccess,
    required this.message,
    this.verificationToken,
  });
}

/// Real-API HTTP Network Client communicating with the BMS Backend Web API (.NET 9).
/// Zero fabricated or offline simulation fallbacks.
class ApiClient {
  static const String baseUrl = 'http://localhost:5000/api';

  static String? userToken;

  static const BmsHttpClient _http = BmsHttpClient();

  static String _normalizeApiPath(String endpoint) {
    final trimmed = endpoint.trim();
    if (trimmed.startsWith('/api/')) return trimmed;
    if (trimmed.startsWith('/')) return '/api$trimmed';
    return '/api/$trimmed';
  }

  /// Generic POST request to `/api/...`
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _http.post(_normalizeApiPath(endpoint), body: body);
      final map = res.bodyAsMap;
      if (res.isSuccess) {
        return {
          'success': true,
          ...map,
        };
      }
      return {
        'success': false,
        'statusCode': res.statusCode,
        'message': res.extractMessage('Thao tác không thành công.'),
        ...map,
      };
    } on BmsApiException catch (e) {
      return {
        'success': false,
        'message': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Không thể kết nối máy chủ: $e',
      };
    }
  }

  /// Generic GET request to `/api/...`
  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final res = await _http.get(_normalizeApiPath(endpoint));
      final map = res.bodyAsMap;
      if (res.isSuccess) {
        return map.isNotEmpty ? map : {'success': true, 'data': res.body};
      }
      return {
        'success': false,
        'statusCode': res.statusCode,
        'message': res.extractMessage('Không thể tải dữ liệu từ máy chủ.'),
      };
    } on BmsApiException catch (e) {
      return {
        'success': false,
        'message': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Không thể kết nối máy chủ: $e',
      };
    }
  }

  /// Dispatches a real OTP request via `/api/auth/otp/send`.
  static Future<SendOtpResult> sendOtp({
    required String destination,
    String purpose = 'PasswordReset',
    String channel = 'Email',
  }) async {
    try {
      final res = await _http.post(
        '/api/auth/otp/send',
        includeAuth: false,
        body: {
          'destination': destination.trim(),
          'purpose': purpose,
          'channel': channel,
        },
      );
      final map = res.bodyAsMap;
      if (res.isSuccess) {
        return SendOtpResult(
          isSuccess: true,
          message: res.extractMessage('Mã xác thực OTP đã được gửi.'),
          cooldownSeconds: (map['cooldownSeconds'] as num?)?.toInt() ?? 60,
        );
      }
      if (res.statusCode == 429) {
        return SendOtpResult(
          isSuccess: false,
          isRateLimited: true,
          message: res.extractMessage(
            'Gửi yêu cầu quá nhanh. Vui lòng đợi ít phút trước khi thử lại.',
          ),
          cooldownSeconds: 300,
        );
      }
      return SendOtpResult(
        isSuccess: false,
        message: res.extractMessage('Không thể gửi mã OTP.'),
      );
    } on BmsApiException catch (e) {
      return SendOtpResult(isSuccess: false, message: e.message);
    }
  }

  /// Verifies a 6-digit OTP code via `/api/auth/otp/verify` or `/api/auth/verify-otp`.
  static Future<VerifyOtpResult> verifyOtp({
    required String destination,
    required String otp,
    String purpose = 'PasswordReset',
  }) async {
    if (otp.trim().length != 6) {
      return const VerifyOtpResult(
        isSuccess: false,
        message: 'Vui lòng nhập đủ 6 chữ số của mã OTP.',
      );
    }

    try {
      final path = purpose == 'Registration'
          ? '/api/auth/verify-otp'
          : '/api/auth/otp/verify';
      final body = purpose == 'Registration'
          ? {'email': destination.trim(), 'otp': otp.trim()}
          : {
              'destination': destination.trim(),
              'otp': otp.trim(),
              'purpose': purpose,
            };

      final res = await _http.post(path, includeAuth: false, body: body);
      final map = res.bodyAsMap;
      if (res.isSuccess) {
        return VerifyOtpResult(
          isSuccess: true,
          message: res.extractMessage('Xác thực mã OTP thành công.'),
          verificationToken: map['verificationToken']?.toString(),
        );
      }
      return VerifyOtpResult(
        isSuccess: false,
        message: res.extractMessage('Mã OTP không hợp lệ hoặc đã hết hạn.'),
      );
    } on BmsApiException catch (e) {
      return VerifyOtpResult(isSuccess: false, message: e.message);
    }
  }

  /// Retrieves real role-based dashboard statistics from `GET /api/dashboard/stats`.
  static Future<Map<String, dynamic>> getDashboardStats([String? role]) async {
    final res = await _http.get(
      '/api/dashboard/stats',
      query: role != null && role.isNotEmpty ? {'role': role} : null,
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tải thống kê bảng điều khiển.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    return res.bodyAsMap;
  }
}
