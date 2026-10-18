/// Models representing laboratory test packages, biomarker criteria, and search responses
/// for UC01 (View Service Catalog) and UC20 (Search Test Packages – Mobile).
///
/// Maps JSON responses from `/api/v1/test-packages/search`, `/api/v1/test-packages/{id}`,
/// and `/api/v1/catalog/services`.
library;

/// Individual biomarker / test criterion included in a test package.
class TestCriterionItemModel {
  final String code;
  final String name;
  final String unit;
  final double? minVal;
  final double? maxVal;
  final String? referenceText;
  final String dataType;

  const TestCriterionItemModel({
    required this.code,
    required this.name,
    required this.unit,
    this.minVal,
    this.maxVal,
    this.referenceText,
    this.dataType = 'Number',
  });

  factory TestCriterionItemModel.fromJson(Map<String, dynamic> json) {
    return TestCriterionItemModel(
      code: (json['code'] ?? json['Code'] ?? json['testCode'] ?? '').toString(),
      name: (json['name'] ?? json['Name'] ?? json['testName'] ?? '').toString(),
      unit: (json['unit'] ?? json['Unit'] ?? '').toString(),
      minVal: (json['minVal'] as num?)?.toDouble() ??
          (json['MinVal'] as num?)?.toDouble(),
      maxVal: (json['maxVal'] as num?)?.toDouble() ??
          (json['MaxVal'] as num?)?.toDouble(),
      referenceText:
          (json['referenceText'] ?? json['ReferenceText'])?.toString(),
      dataType: (json['dataType'] ?? json['DataType'] ?? 'Number').toString(),
    );
  }

  String get displayReferenceRange {
    if (referenceText != null && referenceText!.trim().isNotEmpty) {
      return referenceText!.trim();
    }
    if (minVal != null && maxVal != null) {
      return '$minVal - $maxVal';
    }
    if (minVal != null) return '>= $minVal';
    if (maxVal != null) return '<= $maxVal';
    return 'Theo chuẩn lâm sàng';
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'unit': unit,
        'minVal': minVal,
        'maxVal': maxVal,
        'referenceText': referenceText,
        'dataType': dataType,
      };
}

/// Model representing a laboratory test package.
class TestPackageModel {
  /// Package identifier (PKG-xxx).
  final String id;

  /// Short package code (CBC-01, PKG_GEN_01...).
  final String packageCode;

  /// Full name of the test package.
  final String packageName;

  /// Service category (Huyết học, Sinh hóa, Miễn dịch...).
  final String category;

  /// Service price in VND.
  final double price;

  /// Short clinical description.
  final String description;

  /// Sample tube type (EDTA, Heparin, Serum...).
  final String sampleTube;

  /// Minimum sample volume (ml).
  final double sampleVolumeMl;

  /// Estimated turnaround time (e.g., "60 - 90 Phút").
  final String tat;

  /// Pre-analytical patient preparation instructions (e.g., fasting notes).
  final String preparationNotes;

  /// Whether the package is currently active.
  final bool isActive;

  /// List of biomarker criteria included in this package.
  final List<TestCriterionItemModel> criteria;

  /// Convenience alias for packageCode.
  String get code => packageCode;

  /// Convenience alias for packageName.
  String get name => packageName;

  /// Count of included biomarker criteria.
  int get includedCriteriaCount => criteria.length;

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
    this.tat = '60 - 90 phút',
    this.preparationNotes = '',
    this.criteria = const [],
  });

  factory TestPackageModel.fromJson(Map<String, dynamic> json) {
    final rawCriteria = json['criteria'] as List<dynamic>? ??
        json['Criteria'] as List<dynamic>? ??
        json['tests'] as List<dynamic>? ??
        json['Tests'] as List<dynamic>? ??
        const [];

    final parsedCriteria = rawCriteria
        .whereType<Map<String, dynamic>>()
        .map(TestCriterionItemModel.fromJson)
        .toList();

    return TestPackageModel(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      packageCode: (json['packageCode'] ??
              json['PackageCode'] ??
              json['code'] ??
              json['id'] ??
              '')
          .toString(),
      packageName: (json['packageName'] ??
              json['PackageName'] ??
              json['name'] ??
              '')
          .toString(),
      category:
          (json['category'] ?? json['Category'] ?? 'Xét nghiệm tổng quát')
              .toString(),
      price: (json['price'] as num?)?.toDouble() ??
          (json['Price'] as num?)?.toDouble() ??
          0,
      description:
          (json['description'] ?? json['Description'] ?? '').toString(),
      sampleTube:
          (json['sampleTube'] ?? json['SampleTube'] ?? 'EDTA / Serum')
              .toString(),
      sampleVolumeMl: (json['sampleVolumeMl'] as num?)?.toDouble() ??
          (json['SampleVolumeMl'] as num?)?.toDouble() ??
          2.0,
      tat: (json['tat'] ??
              json['Tat'] ??
              json['turnaroundTime'] ??
              '60 - 90 phút')
          .toString(),
      preparationNotes: (json['preparationNotes'] ??
              json['PreparationNotes'] ??
              'Nhịn ăn sáng 8-12 giờ trước khi lấy mẫu máu.')
          .toString(),
      isActive: json['isActive'] as bool? ?? json['IsActive'] as bool? ?? true,
      criteria: parsedCriteria,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'packageCode': packageCode,
        'packageName': packageName,
        'category': category,
        'price': price,
        'description': description,
        'sampleTube': sampleTube,
        'sampleVolumeMl': sampleVolumeMl,
        'tat': tat,
        'preparationNotes': preparationNotes,
        'isActive': isActive,
        'criteria': criteria.map((c) => c.toJson()).toList(),
      };
}

/// Paginated response wrapper for UC20 Search Test Packages API (`/api/v1/test-packages/search`).
class TestPackageSearchResponse {
  final List<TestPackageModel> items;
  final List<String> categories;
  final List<String> sampleTubes;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;

  const TestPackageSearchResponse({
    required this.items,
    required this.categories,
    required this.sampleTubes,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory TestPackageSearchResponse.fromJson(Map<String, dynamic> json) {
    final payload = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    final rawItems = payload['items'] as List<dynamic>? ??
        payload['Items'] as List<dynamic>? ??
        payload['packages'] as List<dynamic>? ??
        payload['Packages'] as List<dynamic>? ??
        const [];

    final rawCategories = payload['categories'] as List<dynamic>? ??
        payload['Categories'] as List<dynamic>? ??
        const [];

    final rawTubes = payload['sampleTubes'] as List<dynamic>? ??
        payload['SampleTubes'] as List<dynamic>? ??
        const [];

    final parsedItems = rawItems
        .whereType<Map<String, dynamic>>()
        .map(TestPackageModel.fromJson)
        .toList();

    final total = payload['totalCount'] as int? ??
        payload['TotalCount'] as int? ??
        payload['totalItems'] as int? ??
        parsedItems.length;
    final pg = payload['page'] as int? ?? payload['Page'] as int? ?? 1;
    final pgSize = payload['pageSize'] as int? ??
        payload['PageSize'] as int? ??
        (parsedItems.isEmpty ? 20 : parsedItems.length);
    final totPages = payload['totalPages'] as int? ??
        payload['TotalPages'] as int? ??
        (pgSize > 0 ? ((total + pgSize - 1) ~/ pgSize) : 1);

    return TestPackageSearchResponse(
      items: parsedItems,
      categories: rawCategories.map((e) => e.toString()).toList(),
      sampleTubes: rawTubes.map((e) => e.toString()).toList(),
      totalCount: total,
      page: pg,
      pageSize: pgSize,
      totalPages: totPages < 1 ? 1 : totPages,
    );
  }
}

/// Legacy response wrapper for GetServiceCatalog API (kept for compatibility).
class ServiceCatalogResponse {
  final List<TestPackageModel> packages;
  final List<String> categories;
  final int totalCount;

  const ServiceCatalogResponse({
    required this.packages,
    required this.categories,
    required this.totalCount,
  });

  factory ServiceCatalogResponse.fromJson(Map<String, dynamic> json) {
    final searchRes = TestPackageSearchResponse.fromJson(json);
    return ServiceCatalogResponse(
      packages: searchRes.items,
      categories: searchRes.categories,
      totalCount: searchRes.totalCount,
    );
  }
}