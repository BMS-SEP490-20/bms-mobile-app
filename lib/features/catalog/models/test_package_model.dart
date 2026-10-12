/// Model representing a laboratory test package (UC01 – Service Catalog).
///
/// Maps from the JSON response of API `/api/v1/catalog/services`.
class TestPackageModel {
  /// Package identifier (PKG-xxx).
  final String id;

  /// Short package code (CBC-01...).
  final String packageCode;

  /// Full name of the test package.
  final String packageName;

  /// Service category (Hematology, Biochemistry...).
  final String category;

  /// Service price in VND.
  final double price;

  /// Short description.
  final String description;

  /// Sample tube type.
  final String sampleTube;

  /// Minimum sample volume (ml).
  final double sampleVolumeMl;

  /// Whether the package is currently offered.
  final bool isActive;

  /// Creates an instance from individual fields.
  const TestPackageModel({
    required this.id,
    required this.packageCode,
    required this.packageName,
    required this.category,
    required this.price,
    required this.description,
    required this.sampleTube,
    required this.sampleVolumeMl,
    required this.isActive,
  });

  /// Parses from JSON (supports both camelCase from .NET).
  factory TestPackageModel.fromJson(Map<String, dynamic> json) {
    return TestPackageModel(
      id: json['id'] as String? ?? json['Id'] as String? ?? '',
      packageCode:
          json['packageCode'] as String? ?? json['PackageCode'] as String? ?? '',
      packageName:
          json['packageName'] as String? ?? json['PackageName'] as String? ?? '',
      category: json['category'] as String? ?? json['Category'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ??
          (json['Price'] as num?)?.toDouble() ??
          0,
      description:
          json['description'] as String? ?? json['Description'] as String? ?? '',
      sampleTube:
          json['sampleTube'] as String? ?? json['SampleTube'] as String? ?? '',
      sampleVolumeMl: (json['sampleVolumeMl'] as num?)?.toDouble() ??
          (json['SampleVolumeMl'] as num?)?.toDouble() ??
          0,
      isActive: json['isActive'] as bool? ?? json['IsActive'] as bool? ?? true,
    );
  }

  /// Converts to a Map (for debug / cache).
  Map<String, dynamic> toJson() => {
        'id': id,
        'packageCode': packageCode,
        'packageName': packageName,
        'category': category,
        'price': price,
        'description': description,
        'sampleTube': sampleTube,
        'sampleVolumeMl': sampleVolumeMl,
        'isActive': isActive,
      };
}

/// Response wrapper for the GetServiceCatalog API.
class ServiceCatalogResponse {
  /// List of packages.
  final List<TestPackageModel> packages;

  /// Distinct category list.
  final List<String> categories;

  /// Total record count.
  final int totalCount;

  const ServiceCatalogResponse({
    required this.packages,
    required this.categories,
    required this.totalCount,
  });

  factory ServiceCatalogResponse.fromJson(Map<String, dynamic> json) {
    final rawPackages =
        json['packages'] as List<dynamic>? ?? json['Packages'] as List<dynamic>? ?? [];
    final rawCategories =
        json['categories'] as List<dynamic>? ?? json['Categories'] as List<dynamic>? ?? [];

    return ServiceCatalogResponse(
      packages: rawPackages
          .map((e) => TestPackageModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: rawCategories.map((e) => e.toString()).toList(),
      totalCount: json['totalCount'] as int? ??
          json['TotalCount'] as int? ??
          rawPackages.length,
    );
  }
}