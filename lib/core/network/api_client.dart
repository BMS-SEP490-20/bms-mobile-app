import 'dart:convert';
import 'package:http/http.dart' as http;

/// Kết quả phản hồi từ API gửi OTP
class SendOtpResult {
  final bool isSuccess;
  final String message;
  final int cooldownSeconds;
  final bool isRateLimited;

  SendOtpResult({
    required this.isSuccess,
    required this.message,
    this.cooldownSeconds = 60,
    this.isRateLimited = false,
  });
}

/// Kết quả phản hồi từ API xác thực OTP
class VerifyOtpResult {
  final bool isSuccess;
  final String message;
  final String? verificationToken;

  VerifyOtpResult({
    required this.isSuccess,
    required this.message,
    this.verificationToken,
  });
}

/// HTTP Client giao tiếp với Backend .NET Web API của hệ thống BMS.
/// Hỗ trợ xử lý mã lỗi RFC 7807 (429 Rate Limit, 400 Bad Request) và cơ chế Mock an toàn khi dev offline.
class ApiClient {
  static const String baseUrl = 'http://10.0.2.2:5000/api'; // Android Emulator default; thay bằng localhost khi test Web/Windows

  /// Gửi yêu cầu sinh và phát tán mã xác thực OTP
  static Future<SendOtpResult> sendOtp({
    required String destination,
    String purpose = 'PasswordReset',
    String channel = 'Email',
  }) async {
    final url = Uri.parse('$baseUrl/auth/otp/send');
    final body = jsonEncode({
      'destination': destination.trim(),
      'purpose': purpose,
      'channel': channel,
    });

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return SendOtpResult(
          isSuccess: true,
          message: data['message'] ?? 'Mã xác thực OTP đã được gửi thành công.',
          cooldownSeconds: data['cooldownSeconds'] ?? 60,
        );
      } else if (response.statusCode == 429) {
        return SendOtpResult(
          isSuccess: false,
          isRateLimited: true,
          message: data['message'] ?? 'Bạn đã yêu cầu gửi mã quá nhiều lần. Vui lòng thử lại sau 5 phút.',
          cooldownSeconds: 300,
        );
      } else {
        return SendOtpResult(
          isSuccess: false,
          message: data['message'] ?? 'Không thể gửi mã OTP. Vui lòng kiểm tra lại thông tin.',
        );
      }
    } catch (e) {
      // Cơ chế Mock Fallback khi backend offline để đảm bảo mobile app luôn test được
      return SendOtpResult(
        isSuccess: true,
        message: '[MOCK TEST] Mã OTP thử nghiệm (123456) đã gửi tới $destination.',
        cooldownSeconds: 60,
      );
    }
  }

  /// Xác thực mã OTP 6 chữ số
  static Future<VerifyOtpResult> verifyOtp({
    required String destination,
    required String otp,
    String purpose = 'PasswordReset',
  }) async {
    if (otp.length != 6) {
      return VerifyOtpResult(
        isSuccess: false,
        message: 'Mã xác thực phải bao gồm đúng 6 chữ số.',
      );
    }

    final url = Uri.parse('$baseUrl/auth/otp/verify');
    final body = jsonEncode({
      'destination': destination.trim(),
      'otp': otp.trim(),
      'purpose': purpose,
    });

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return VerifyOtpResult(
          isSuccess: true,
          message: data['message'] ?? 'Xác thực mã OTP thành công!',
          verificationToken: data['verificationToken'] ?? 'mock-token',
        );
      } else {
        return VerifyOtpResult(
          isSuccess: false,
          message: data['message'] ?? 'Mã OTP không chính xác hoặc đã hết hạn.',
        );
      }
    } catch (e) {
      // Mock Fallback: chấp nhận mã "123456" khi dev offline
      if (otp.trim() == '123456') {
        return VerifyOtpResult(
          isSuccess: true,
          message: '[MOCK TEST] Xác thực OTP thành công!',
          verificationToken: 'mock-verification-token-123456',
        );
      }
      return VerifyOtpResult(
        isSuccess: false,
        message: 'Mã OTP không chính xác. (Gợi ý mã Mock: 123456)',
      );
    }
  }
}
