/// Models representing laboratory test packages, biomarker criteria, and search responses
/// aligned 1-1 with BMS Backend `/api/v1/test-packages/*` and Web `ServiceCatalogPage.jsx`.
library;

class TestCriterionItemModel {
  final String code;
  final String name;
  final String unit;
  final double? minVal;
  final double? maxVal;
  final String? referenceRange;
  final String dataType;

  const TestCriterionItemModel({
    required this.code,
    required this.name,
    required this.unit,
    this.minVal,
    this.maxVal,
    this.referenceRange,
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
      referenceRange:
          (json['referenceRange'] ??
                  json['ReferenceRange'] ??
                  json['referenceText'] ??
                  json['ReferenceText'])
              ?.toString(),
      dataType: (json['dataType'] ?? json['DataType'] ?? 'Number').toString(),
    );
  }

  String get displayReferenceRange {
    if (referenceRange != null && referenceRange!.trim().isNotEmpty) {
      return referenceRange!.trim();
    }
    if (minVal != null && maxVal != null) {
      return '$minVal - $maxVal';
    }
    if (minVal != null) return '>= $minVal';
    if (maxVal != null) return '<= $maxVal';
    return 'Theo chuẩn lâm sàng';
  }
}

class PackageRatingSummary {
  final String key;
  final String servicePackageId;
  final String servicePackageCode;
  final double averageRating;
  final int reviewCount;

  const PackageRatingSummary({
    required this.key,
    required this.servicePackageId,
    required this.servicePackageCode,
    required this.averageRating,
    required this.reviewCount,
  });

  factory PackageRatingSummary.fromJson(Map<String, dynamic> json) {
    return PackageRatingSummary(
      key: (json['key'] ?? '').toString(),
      servicePackageId: (json['servicePackageId'] ?? '').toString(),
      servicePackageCode: (json['servicePackageCode'] ?? '').toString(),
      averageRating:
          (json['averageRating'] ?? json['avgRating'] ?? 0 as num).toDouble(),
      reviewCount:
          ((json['reviewCount'] ?? json['totalReviews'] ?? json['count'] ?? 0)
                  as num)
              .toInt(),
    );
  }
}

class TestPackageModel {
  final String id;
  final String packageCode;
  final String packageName;
  final String category;
  final double price;
  final String description;
  final String sampleTube;
  final double sampleVolumeMl;
  final String tat;
  final String fastingRule;
  final String preparationNotes;
  final bool isActive;
  final List<TestCriterionItemModel> criteria;

  String get code => packageCode;
  String get name => packageName;
  int get includedCriteriaCount => criteria.length;

  bool get requiresFasting {
    final blob = '$fastingRule $preparationNotes $packageName'.toLowerCase();
    return blob.contains('nhịn ăn') ||
        blob.contains('fasting') ||
        blob.contains('8-12') ||
        blob.contains('8 - 12');
  }

  String get displayPreparation =>
      fastingRule.trim().isNotEmpty ? fastingRule.trim() : preparationNotes;

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
    this.fastingRule = '',
    this.preparationNotes = '',
    this.criteria = const [],
  });

  factory TestPackageModel.fromJson(Map<String, dynamic> json) {
    final rawCriteria =
        json['criteria'] as List<dynamic>? ??
        json['Criteria'] as List<dynamic>? ??
        json['tests'] as List<dynamic>? ??
        json['Tests'] as List<dynamic>? ??
        const [];

    final parsedCriteria = rawCriteria
        .whereType<Map>()
        .map((m) => TestCriterionItemModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    final fasting =
        (json['fastingRule'] ??
                json['FastingRule'] ??
                json['fastingInstructions'] ??
                '')
            .toString()
            .trim();
    final prep =
        (json['preparationNotes'] ??
                json['PreparationNotes'] ??
                (fasting.isNotEmpty
                    ? fasting
                    : 'Không yêu cầu nhịn ăn bắt buộc (uống đủ nước lọc trước khi lấy mẫu).'))
            .toString()
            .trim();

    return TestPackageModel(
      id: (json['id'] ?? json['Id'] ?? json['_id'] ?? '').toString(),
      packageCode:
          (json['packageCode'] ??
                  json['PackageCode'] ??
                  json['code'] ??
                  json['id'] ??
                  '')
              .toString(),
      packageName:
          (json['packageName'] ?? json['PackageName'] ?? json['name'] ?? '')
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
      tat:
          (json['tat'] ??
                  json['Tat'] ??
                  json['turnaroundTime'] ??
                  '60 - 90 phút')
              .toString(),
      fastingRule: fasting,
      preparationNotes: prep,
      isActive: json['isActive'] as bool? ?? json['IsActive'] as bool? ?? true,
      criteria: parsedCriteria,
    );
  }
}

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

    final rawItems =
        payload['items'] as List<dynamic>? ??
        payload['Items'] as List<dynamic>? ??
        payload['packages'] as List<dynamic>? ??
        payload['Packages'] as List<dynamic>? ??
        const [];

    final rawCategories =
        payload['categories'] as List<dynamic>? ??
        payload['Categories'] as List<dynamic>? ??
        const [];

    final rawTubes =
        payload['sampleTubes'] as List<dynamic>? ??
        payload['SampleTubes'] as List<dynamic>? ??
        const [];

    final parsedItems = rawItems
        .whereType<Map>()
        .map((m) => TestPackageModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    final total =
        (payload['totalCount'] ??
                payload['TotalCount'] ??
                payload['totalItems'] ??
                parsedItems.length)
            as num;
    final pg = (payload['page'] ?? payload['Page'] ?? 1) as num;
    final pgSize =
        (payload['pageSize'] ??
                payload['PageSize'] ??
                (parsedItems.isEmpty ? 20 : parsedItems.length))
            as num;
    final totPages =
        (payload['totalPages'] ??
                payload['TotalPages'] ??
                (pgSize > 0 ? ((total.toInt() + pgSize.toInt() - 1) ~/ pgSize.toInt()) : 1))
            as num;

    return TestPackageSearchResponse(
      items: parsedItems,
      categories: rawCategories.map((e) => e.toString()).toList(),
      sampleTubes: rawTubes.map((e) => e.toString()).toList(),
      totalCount: total.toInt(),
      page: pg.toInt(),
      pageSize: pgSize.toInt(),
      totalPages: totPages.toInt() < 1 ? 1 : totPages.toInt(),
    );
  }
}
