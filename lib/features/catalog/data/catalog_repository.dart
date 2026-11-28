import '../../../core/network/bms_http_client.dart';
import '../models/test_package_model.dart';

/// Unified Catalog Repository backed strictly by [BmsHttpClient].
/// Connects to `/api/v1/test-packages/*` and `/TestOrder/feedback/package-ratings`.
class CatalogRepository {
  final BmsHttpClient _http;

  const CatalogRepository({BmsHttpClient? http})
    : _http = http ?? const BmsHttpClient();

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
    int pageSize = 50,
  }) async {
    final normalizedSortBy = sortBy == 'packageName' ? 'name' : sortBy;
    final query = <String, String>{
      'sortBy': normalizedSortBy,
      'sortDir': sortDir,
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      if (keyword != null && keyword.trim().isNotEmpty)
        'keyword': keyword.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (sampleTube != null && sampleTube.trim().isNotEmpty)
        'sampleTube': sampleTube.trim(),
      if (minPrice != null && minPrice >= 0)
        'minPrice': minPrice.toStringAsFixed(0),
      if (maxPrice != null && maxPrice >= 0)
        'maxPrice': maxPrice.toStringAsFixed(0),
      if (isActive != null) 'isActive': isActive.toString(),
    };

    final res = await _http.get(
      '/api/v1/test-packages/search',
      query: query,
      includeAuth: false,
    );
    if (res.isSuccess) {
      return TestPackageSearchResponse.fromJson(res.bodyAsMap);
    }
    throw CatalogException(
      res.extractMessage(
        'Không thể tải danh mục gói xét nghiệm (HTTP ${res.statusCode}).',
      ),
      statusCode: res.statusCode,
    );
  }

  Future<TestPackageModel?> getById(String id) async {
    final encoded = Uri.encodeComponent(id.trim());
    final res = await _http.get(
      '/api/v1/test-packages/$encoded',
      includeAuth: false,
    );
    if (res.statusCode == 404) return null;
    if (res.isSuccess) {
      final data = res.data;
      if (data is Map) {
        return TestPackageModel.fromJson(Map<String, dynamic>.from(data));
      }
      return TestPackageModel.fromJson(res.bodyAsMap);
    }
    throw CatalogException(
      res.extractMessage('Không thể tải chi tiết gói xét nghiệm.'),
      statusCode: res.statusCode,
    );
  }

  /// Public summary of star ratings & review counts by package (`GET /TestOrder/feedback/package-ratings`).
  Future<Map<String, PackageRatingSummary>> getPackageRatingsMap() async {
    try {
      final res = await _http.get(
        '/TestOrder/feedback/package-ratings',
        includeAuth: false,
      );
      if (!res.isSuccess) return const {};
      final map = <String, PackageRatingSummary>{};
      for (final raw in res.bodyAsList) {
        if (raw is! Map) continue;
        final item = PackageRatingSummary.fromJson(
          Map<String, dynamic>.from(raw),
        );
        for (final k in [
          item.key,
          item.servicePackageId,
          item.servicePackageCode,
        ]) {
          final norm = k.trim().toLowerCase();
          if (norm.isNotEmpty) map[norm] = item;
        }
      }
      return map;
    } catch (_) {
      return const {};
    }
  }

  /// Public anonymized reviews for a specific package (`GET /TestOrder/feedback/packages/{code}`).
  Future<Map<String, dynamic>?> getPackageReviews(
    String packageIdOrCode,
  ) async {
    try {
      final res = await _http.get(
        '/TestOrder/feedback/packages/${Uri.encodeComponent(packageIdOrCode.trim())}',
        includeAuth: false,
      );
      if (!res.isSuccess) return null;
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
    } catch (_) {
      return null;
    }
  }

  static PackageRatingSummary? lookupRating(
    Map<String, PackageRatingSummary> ratingsMap,
    TestPackageModel pkg,
  ) {
    for (final c in [pkg.id, pkg.packageCode]) {
      final hit = ratingsMap[c.trim().toLowerCase()];
      if (hit != null) return hit;
    }
    return null;
  }
}

class CatalogException implements Exception {
  final String message;
  final int? statusCode;
  CatalogException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
