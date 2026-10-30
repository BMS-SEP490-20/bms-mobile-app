import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../models/test_package_model.dart';

/// Repository that calls the Search Test Packages (UC20 – Mobile) and
/// View Service Catalog (UC01 – Mobile) Backend APIs.
///
/// Automatically tries `http://localhost:5000` (Web/Windows/iOS simulator)
/// and falls back to `http://10.0.2.2:5000` (Android emulator).
class CatalogRepository {
  /// Primary Backend API base URL.
  final String baseUrl;

  /// HTTP client (inject a mock for unit tests).
  final http.Client _client;

  CatalogRepository({
    this.baseUrl = 'http://localhost:5000',
    http.Client? client,
  }) : _client = client ?? http.Client();

  List<String> get _candidateBaseUrls {
    final urls = <String>[baseUrl];
    if (!urls.contains('http://10.0.2.2:5000')) {
      urls.add('http://10.0.2.2:5000');
    }
    if (!urls.contains('http://localhost:5000')) {
      urls.add('http://localhost:5000');
    }
    return urls;
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (ApiClient.userToken != null && ApiClient.userToken!.isNotEmpty)
          'Authorization': 'Bearer ${ApiClient.userToken}',
      };

  /// Searches and filters available test packages (UC20 – Search Test Packages).
  ///
  /// Connects to `GET /api/v1/test-packages/search`.
  Future<TestPackageSearchResponse> searchTestPackages({
    String? keyword,
    String? category,
    String? sampleTube,
    double? minPrice,
    double? maxPrice,
    bool? isActive = true,
    String sortBy = 'name',
    String sortDir = 'asc',
    int page = 1,
    int pageSize = 20,
  }) async {
    final normalizedSortBy = sortBy == 'packageName' ? 'name' : sortBy;
    final query = <String, String>{
      'sortBy': normalizedSortBy,
      'sortDir': sortDir,
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };

    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (category != null && category.trim().isNotEmpty) {
      query['category'] = category.trim();
    }
    if (sampleTube != null && sampleTube.trim().isNotEmpty) {
      query['sampleTube'] = sampleTube.trim();
    }
    if (minPrice != null && minPrice >= 0) {
      query['minPrice'] = minPrice.toStringAsFixed(0);
    }
    if (maxPrice != null && maxPrice >= 0) {
      query['maxPrice'] = maxPrice.toStringAsFixed(0);
    }
    if (isActive != null) {
      query['isActive'] = isActive.toString();
    }

    Object? lastError;

    for (final candidate in _candidateBaseUrls) {
      final uri = Uri.parse('$candidate/api/v1/test-packages/search')
          .replace(queryParameters: query);

      try {
        final response = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return TestPackageSearchResponse.fromJson(json);
        }

        final errMsg = _extractErrorMessage(
          response.body,
          'Không thể tìm kiếm gói xét nghiệm (HTTP ${response.statusCode}).',
        );
        throw CatalogException(errMsg, statusCode: response.statusCode);
      } on CatalogException {
        rethrow;
      } catch (e) {
        lastError = e;
      }
    }

    throw CatalogException(
      'Không thể kết nối máy chủ BMS Backend: $lastError',
    );
  }

  /// Fetches the laboratory service catalog (compatible wrapper around searchTestPackages).
  Future<ServiceCatalogResponse> getServiceCatalog({
    String? category,
    String? search,
  }) async {
    final res = await searchTestPackages(
      keyword: search,
      category: category,
      page: 1,
      pageSize: 50,
    );
    return ServiceCatalogResponse(
      packages: res.items,
      categories: res.categories,
      totalCount: res.totalCount,
    );
  }

  /// Fetches a single test package by [id] or [packageCode] including full biomarker criteria.
  ///
  /// Connects to `GET /api/v1/test-packages/{id}`.
  Future<TestPackageModel?> getById(String id) async {
    final encoded = Uri.encodeComponent(id.trim());
    Object? lastError;

    for (final candidate in _candidateBaseUrls) {
      final uri = Uri.parse('$candidate/api/v1/test-packages/$encoded');
      try {
        final response = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 404) return null;
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final dataMap = (decoded['data'] is Map<String, dynamic>)
              ? decoded['data'] as Map<String, dynamic>
              : decoded;
          return TestPackageModel.fromJson(dataMap);
        }

        throw CatalogException(
          _extractErrorMessage(
            response.body,
            'Không thể tải chi tiết gói xét nghiệm (${response.statusCode}).',
          ),
          statusCode: response.statusCode,
        );
      } on CatalogException {
        rethrow;
      } catch (e) {
        lastError = e;
      }
    }

    throw CatalogException('Lỗi kết nối máy chủ: $lastError');
  }

  String _extractErrorMessage(String rawBody, String fallback) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        if (decoded['errors'] is Map<String, dynamic>) {
          final errs = (decoded['errors'] as Map<String, dynamic>)
              .values
              .expand((v) => v is Iterable ? v : [v])
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
          if (errs.isNotEmpty) return errs.join(' ');
        }
        return (decoded['detail'] ??
                decoded['message'] ??
                decoded['title'] ??
                fallback)
            .toString();
      }
    } catch (_) {}
    return fallback;
  }

  /// Releases the HTTP client.
  void dispose() {
    _client.close();
  }
}

/// Exception specific to the Catalog module.
class CatalogException implements Exception {
  final String message;
  final int? statusCode;

  CatalogException(this.message, {this.statusCode});

  @override
  String toString() => message;
}