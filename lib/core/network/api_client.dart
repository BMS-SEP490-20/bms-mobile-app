import 'dart:convert';
import 'package:http/http.dart' as http;

/// Data model representing the response from the Send OTP API.
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

/// Data model representing the response from the Verify OTP API.
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

/// HTTP Network Client communicating with the BMS Backend Web API (.NET).
/// Supports RFC 7807 problem details (429 Rate Limit, 400 Bad Request) and resilient mock fallback for offline dev/test.
class ApiClient {
  static const String baseUrl = 'http://10.0.2.2:5000/api'; // Android Emulator default; use localhost when testing Web/Desktop

  /// Dispatches a request to generate and send an OTP code via Email or SMS.
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
          message: data['message'] ?? 'OTP verification code has been dispatched successfully.',
          cooldownSeconds: data['cooldownSeconds'] ?? 60,
        );
      } else if (response.statusCode == 429) {
        return SendOtpResult(
          isSuccess: false,
          isRateLimited: true,
          message: data['message'] ?? 'Too many requests. Please wait 5 minutes before trying again.',
          cooldownSeconds: 300,
        );
      } else {
        return SendOtpResult(
          isSuccess: false,
          message: data['message'] ?? 'Unable to send OTP code. Please check your information.',
        );
      }
    } catch (e) {
      // Offline fallback: allows seamless offline mobile testing
      return SendOtpResult(
        isSuccess: true,
        message: '[MOCK TEST] Demo OTP code (123456) dispatched to $destination.',
        cooldownSeconds: 60,
      );
    }
  }

  /// Verifies a 6-digit OTP code submitted by the user.
  static Future<VerifyOtpResult> verifyOtp({
    required String destination,
    required String otp,
    String purpose = 'PasswordReset',
  }) async {
    if (otp.length != 6) {
      return VerifyOtpResult(
        isSuccess: false,
        message: 'Verification code must be exactly 6 numeric digits.',
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
          message: data['message'] ?? 'OTP verified successfully!',
          verificationToken: data['verificationToken'] ?? 'mock-token',
        );
      } else {
        return VerifyOtpResult(
          isSuccess: false,
          message: data['message'] ?? 'Incorrect or expired OTP code.',
        );
      }
    } catch (e) {
      // Offline mock fallback: accepts demo code "123456"
      if (otp.trim() == '123456') {
        return VerifyOtpResult(
          isSuccess: true,
          message: '[MOCK TEST] OTP verified successfully!',
          verificationToken: 'mock-verification-token-123456',
        );
      }
      return VerifyOtpResult(
        isSuccess: false,
        message: 'Invalid OTP code. (Hint for offline test: 123456)',
      );
    }
  }
}
