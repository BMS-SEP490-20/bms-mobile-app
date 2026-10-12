import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/test_package_model.dart';

/// Repository that calls the View Service Catalog API (UC01 – Mobile).
///
/// Default base URL: `http://10.0.2.2:5000` (Android emulator → host machine).
/// Can be overridden via the constructor.
class CatalogRepository {
  /// Backend API base URL.
  final String baseUrl;

  /// HTTP client (inject a mock for unit tests).
  final http.Client _client;

  /// Creates the repository.
  ///
  /// [baseUrl] – e.g. `http://10.0.2.2:5000` (emulator) or `http://192.168.x.x:5000` (device).
  CatalogRepository({
    this.baseUrl = 'http://localhost:5000',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Fetches the laboratory service catalog.
  ///
  /// [category] – filter by category group (null = all).
  /// [search] – keyword to search in package name/code.
  ///
  /// Throws [CatalogException] on network errors or non-200 HTTP status.
  Future<ServiceCatalogResponse> getServiceCatalog({
    String? category,
    String? search,
  }) async {
    final query = <String, String>{};
    if (category != null && category.isNotEmpty) {
      query['category'] = category;
    }
    if (search != null && search.isNotEmpty) {
      query['search'] = search;
    }

    final uri = Uri.parse('$baseUrl/api/v1/catalog/services')
        .replace(queryParameters: query.isEmpty ? null : query);

    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw CatalogException(
          'Failed to load service catalog (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ServiceCatalogResponse.fromJson(json);
    } on CatalogException {
      rethrow;
    } catch (e) {
      throw CatalogException('Connection error: $e');
    }
  }

  /// Fetches a single package by [id].
  ///
  /// Returns `null` on 404.
  Future<TestPackageModel?> getById(String id) async {
    final uri = Uri.parse('$baseUrl/api/v1/catalog/services/$id');

    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw CatalogException(
          'Failed to load package details (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return TestPackageModel.fromJson(json);
    } on CatalogException {
      rethrow;
    } catch (e) {
      throw CatalogException('Connection error: $e');
    }
  }

  /// Releases the HTTP client.
  void dispose() {
    _client.close();
  }
}

/// Exception specific to the Catalog module.
class CatalogException implements Exception {
  /// Error message.
  final String message;

  /// HTTP status code (if available).
  final int? statusCode;

  CatalogException(this.message, {this.statusCode});

  @override
  String toString() => message;
}