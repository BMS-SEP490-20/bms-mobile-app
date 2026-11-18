import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../services/bms_auth.dart';

/// Structured HTTP response wrapper for BMS Backend API calls.
class BmsApiResponse {
  final int statusCode;
  final dynamic body;
  final Map<String, String> headers;

  const BmsApiResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  Map<String, dynamic> get bodyAsMap =>
      body is Map<String, dynamic> ? body as Map<String, dynamic> : {};

  dynamic get data {
    if (body is Map<String, dynamic>) {
      final map = body as Map<String, dynamic>;
      if (map.containsKey('data')) return map['data'];
    }
    return body;
  }

  String extractMessage([String fallback = 'Yêu cầu không thành công.']) {
    if (body is Map<String, dynamic>) {
      final map = body as Map<String, dynamic>;
      if (map['errors'] is Map) {
        final errs = (map['errors'] as Map).values
            .expand((v) => v is Iterable ? v : [v])
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (errs.isNotEmpty) return errs.join(' ');
      }
      final candidate =
          map['message'] ?? map['detail'] ?? map['title'] ?? map['error'];
      if (candidate != null && candidate.toString().trim().isNotEmpty) {
        return candidate.toString().trim();
      }
    }
    if (body is String && (body as String).trim().isNotEmpty) {
      return (body as String).trim();
    }
    return fallback;
  }
}

/// Transport or HTTP status exception thrown by [BmsHttpClient].
class BmsApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const BmsApiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => message;
}

/// Platform-aware HTTP client communicating exclusively with the real .NET 9 BMS API.
class BmsHttpClient {
  static const String _envApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _envBmsBaseUrl = String.fromEnvironment(
    'BMS_API_BASE_URL',
  );

  static String? _cachedBaseUrl;

  /// Returns ordered candidate base URLs according to runtime platform.
  static List<String> get candidateBaseUrls {
    if (_envApiBaseUrl.isNotEmpty) {
      return [_stripTrailingSlash(_envApiBaseUrl)];
    }
    if (_envBmsBaseUrl.isNotEmpty) {
      return [_stripTrailingSlash(_envBmsBaseUrl)];
    }
    if (_cachedBaseUrl != null && _cachedBaseUrl!.isNotEmpty) {
      final others = _platformDefaultCandidates
          .where((u) => u != _cachedBaseUrl)
          .toList();
      return [_cachedBaseUrl!, ...others];
    }
    return _platformDefaultCandidates;
  }

  /// Active resolved base URL for synchronous consumers.
  static String get resolvedBaseUrl => candidateBaseUrls.first;

  static List<String> get _platformDefaultCandidates {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return const ['http://10.0.2.2:5000', 'http://localhost:5000'];
    }
    return const ['http://localhost:5000', 'http://10.0.2.2:5000'];
  }

  static void resetCachedHost() {
    _cachedBaseUrl = null;
  }

  static void cacheWorkingHost(String baseUrl) {
    _cachedBaseUrl = _stripTrailingSlash(baseUrl);
  }

  static String _stripTrailingSlash(String url) {
    var clean = url.trim();
    if (clean.endsWith('/api')) {
      clean = clean.substring(0, clean.length - 4);
    }
    return clean.replaceFirst(RegExp(r'/+$'), '');
  }

  final http.Client? _injectedClient;
  final String? baseUrlOverride;

  const BmsHttpClient({http.Client? client, this.baseUrlOverride})
    : _injectedClient = client;

  List<String> get _hosts {
    if (baseUrlOverride != null && baseUrlOverride!.trim().isNotEmpty) {
      return [_stripTrailingSlash(baseUrlOverride!)];
    }
    return candidateBaseUrls;
  }

  Map<String, String> _buildHeaders({
    bool includeAuth = true,
    Map<String, String>? extraHeaders,
  }) {
    final token = BmsAuth.accessToken;
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (includeAuth && token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
      ...?extraHeaders,
    };
  }

  Future<BmsApiResponse> get(
    String path, {
    Map<String, String>? query,
    bool includeAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _send(
      method: 'GET',
      path: path,
      query: query,
      includeAuth: includeAuth,
      timeout: timeout,
    );
  }

  Future<BmsApiResponse> post(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool includeAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _send(
      method: 'POST',
      path: path,
      body: body,
      query: query,
      includeAuth: includeAuth,
      timeout: timeout,
    );
  }

  Future<BmsApiResponse> put(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool includeAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _send(
      method: 'PUT',
      path: path,
      body: body,
      query: query,
      includeAuth: includeAuth,
      timeout: timeout,
    );
  }

  Future<BmsApiResponse> patch(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool includeAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _send(
      method: 'PATCH',
      path: path,
      body: body,
      query: query,
      includeAuth: includeAuth,
      timeout: timeout,
    );
  }

  Future<BmsApiResponse> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool includeAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _send(
      method: 'DELETE',
      path: path,
      body: body,
      query: query,
      includeAuth: includeAuth,
      timeout: timeout,
    );
  }

  Future<BmsApiResponse> _send({
    required String method,
    required String path,
    Object? body,
    Map<String, String>? query,
    bool includeAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final filteredQuery = query == null
        ? null
        : (Map<String, String>.from(
            query,
          )..removeWhere((_, v) => v.trim().isEmpty));

    final client = _injectedClient ?? http.Client();
    Object? lastTransportError;

    try {
      for (final host in _hosts) {
        final baseUri = Uri.parse('$host$normalizedPath');
        final uri = (filteredQuery != null && filteredQuery.isNotEmpty)
            ? baseUri.replace(queryParameters: filteredQuery)
            : baseUri;
        final headers = _buildHeaders(includeAuth: includeAuth);
        final encodedBody = body == null
            ? null
            : (body is String ? body : jsonEncode(body));

        try {
          late http.Response raw;
          switch (method) {
            case 'GET':
              raw = await client.get(uri, headers: headers).timeout(timeout);
              break;
            case 'POST':
              raw = await client
                  .post(uri, headers: headers, body: encodedBody)
                  .timeout(timeout);
              break;
            case 'PUT':
              raw = await client
                  .put(uri, headers: headers, body: encodedBody)
                  .timeout(timeout);
              break;
            case 'PATCH':
              raw = await client
                  .patch(uri, headers: headers, body: encodedBody)
                  .timeout(timeout);
              break;
            case 'DELETE':
              raw = await client
                  .delete(uri, headers: headers, body: encodedBody)
                  .timeout(timeout);
              break;
            default:
              throw ArgumentError('Unsupported HTTP method: $method');
          }

          if (baseUrlOverride == null) {
            cacheWorkingHost(host);
          }

          dynamic decoded;
          final rawText = utf8.decode(raw.bodyBytes);
          if (rawText.trim().isNotEmpty) {
            try {
              decoded = jsonDecode(rawText);
            } catch (_) {
              decoded = rawText;
            }
          } else {
            decoded = <String, dynamic>{};
          }

          return BmsApiResponse(
            statusCode: raw.statusCode,
            body: decoded,
            headers: raw.headers,
          );
        } catch (err) {
          lastTransportError = err;
        }
      }
    } finally {
      if (_injectedClient == null) {
        client.close();
      }
    }

    throw BmsApiException(
      'Không thể kết nối đến máy chủ BMS. Vui lòng kiểm tra kết nối mạng (${lastTransportError ?? 'offline'}).',
    );
  }
}
