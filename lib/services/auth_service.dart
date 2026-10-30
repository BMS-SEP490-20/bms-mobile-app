import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final response = await Api.post('/gateway/iam/auth/login', {
        'username': username,
        'password': password,
      });

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        String? token;
        if (responseData['data'] != null) {
          if (responseData['data']['Token'] != null) {
            token = responseData['data']['Token'];
          } else if (responseData['data']['token'] != null) {
            token = responseData['data']['token'];
          } else if (responseData['data'] is String) {
            token = responseData['data'];
          }
        } else if (responseData['Token'] != null) {
          token = responseData['Token'];
        } else if (responseData['token'] != null) {
          token = responseData['token'];
        }

        if (token == null) {
          return {
            'success': false,
            'message':
                responseData['message'] ??
                'Đăng nhập thất bại - không nhận được token',
          };
        }

        Map<String, dynamic> userInfo = {'username': username};

        try {
          Map<String, dynamic> payload = JwtDecoder.decode(token);

          final nameId =
              payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] ??
              payload['nameidentifier'] ??
              payload['nameid'] ??
              payload['sub'] ??
              payload['userId'];
          final nameClaim =
              payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'] ??
              payload['name'] ??
              payload['unique_name'] ??
              payload['username'] ??
              username;

          dynamic roleClaim =
              payload['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ??
              payload['role'];
          String roleValue = 'patient';
          if (roleClaim is List && roleClaim.isNotEmpty) {
            roleValue = roleClaim[0].toString();
          } else if (roleClaim != null) {
            roleValue = roleClaim.toString();
          }

          int? roleIdNumber = int.tryParse(roleValue);

          userInfo = {
            'id': nameId,
            'username': nameClaim,
            'role': roleValue,
            'roleId': roleIdNumber ?? roleValue,
            'fullName': nameClaim,
          };
        } catch (e) {
          // Error decoding token
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('user', jsonEncode(userInfo));

        return {'success': true, 'user': userInfo, 'token': token};
      } else if (response.statusCode == 404 || response.statusCode == 400) {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Thông tin không hợp lệ',
        };
      } else {
        return {
          'success': false,
          'message': 'Lỗi đăng nhập: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối máy chủ'};
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  static Future<Map<String, dynamic>> register(String email) async {
    try {
      final response = await Api.post(
        '/gateway/iam/auth/register',
        email,
      ); // Assuming the API takes the email directly in body or adjust accordingly
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['message'] != null) {
          return {'success': true, 'message': data['message']};
        }
      }
      if (response.statusCode == 404) {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Tài khoản đã tồn tại',
        };
      }
      return {'success': false, 'message': 'Đăng ký thất bại'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi tạo tài khoản'};
    }
  }

  static Future<Map<String, dynamic>> sendOTP(String email) async {
    try {
      final response = await Api.post('/gateway/iam/auth/otp/sendotp', email);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['isSuccess'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'OTP đã được gửi',
          };
        }
        return {'success': false, 'message': data['message'] ?? 'Lỗi gửi OTP'};
      }
      return {'success': false, 'message': 'Lỗi gửi OTP'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối server'};
    }
  }

  static Future<Map<String, dynamic>> verifyOTP(
    String email,
    String otp,
  ) async {
    try {
      final response = await Api.post('/gateway/iam/auth/otp/verifyotp', {
        'Email': email,
        'OtpCode': otp,
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['isSuccess'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'Xác thực thành công',
          };
        }
        return {
          'success': false,
          'message': data['message'] ?? 'OTP không hợp lệ',
        };
      }
      return {'success': false, 'message': 'Lỗi xác thực'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối server'};
    }
  }
}
