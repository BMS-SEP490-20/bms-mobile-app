import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'http://10.0.2.2:5000/api'; // Android emulator localhost

  static String? userToken;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (userToken != null) 'Authorization': 'Bearer $userToken',
  };

  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : {'data': data};
    } catch (e) {
      // Offline fallback demo
      return {
        'success': true,
        'message': 'Thực hiện thành công (Chế độ mô phỏng thiết bị)',
      };
    }
  }

  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : {'data': data};
    } catch (e) {
      return {'success': true, 'data': {}};
    }
  }
}
