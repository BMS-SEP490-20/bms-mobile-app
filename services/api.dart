import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Api {
  static const String baseUrl = 'http://192.168.1.20:7001';

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> post(String endpoint, dynamic body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    _handleUnauthorized(response, endpoint);
    return response;
  }

  static Future<http.Response> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    
    final response = await http.get(
      url,
      headers: headers,
    ).timeout(const Duration(seconds: 30));

    _handleUnauthorized(response, endpoint);
    return response;
  }

  static Future<http.Response> put(String endpoint, dynamic body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    
    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    _handleUnauthorized(response, endpoint);
    return response;
  }

  static Future<http.Response> delete(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    
    final response = await http.delete(
      url,
      headers: headers,
    ).timeout(const Duration(seconds: 30));

    _handleUnauthorized(response, endpoint);
    return response;
  }

  static void _handleUnauthorized(http.Response response, String endpoint) async {
    if (response.statusCode == 401) {
      const skipLogoutEndpoints = [
        '/gateway/admin/accounts', 
        '/gateway/admin/users',    
        '/roles',                   
        '/rolePermissions'          
      ];

      final shouldLogout = !skipLogoutEndpoints.any((e) => endpoint.contains(e));

      if (shouldLogout) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        await prefs.remove('user');
        // Logic for navigation should be handled in the UI
      }
    }
  }
}
