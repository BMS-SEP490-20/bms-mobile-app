/// UC76 metadata from the server; only an available detail contains clinical values.
class TestHistorySummary {
  final String id, resultCode, patientId, sampleId, packageName;
  final DateTime? createdAt, approvedAt;
  final bool available;
  const TestHistorySummary({
    required this.id,
    required this.resultCode,
    required this.patientId,
    required this.sampleId,
    required this.packageName,
    this.createdAt,
    this.approvedAt,
    required this.available,
  });
  factory TestHistorySummary.fromJson(Map<String, dynamic> json) =>
      TestHistorySummary(
        id: json['id'] as String,
        resultCode: json['resultCode'] as String? ?? '',
        patientId: json['patientId'] as String? ?? '',
        sampleId: json['sampleId'] as String? ?? '',
        packageName: json['packageName'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
        approvedAt: DateTime.tryParse(json['approvedAt']?.toString() ?? ''),
        available: json['available'] == true,
      );
}

/// Stored measurements and reference text are displayed without recalculating ranges or clinical flags.
class TestHistoryItem {
  final String code, name, value, unit, referenceRange, flag;
  const TestHistoryItem({
    required this.code,
    required this.name,
    required this.value,
    required this.unit,
    required this.referenceRange,
    required this.flag,
  });
  factory TestHistoryItem.fromJson(Map<String, dynamic> json) =>
      TestHistoryItem(
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        value: json['value'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
        referenceRange: json['referenceRange'] as String? ?? '',
        flag: json['flag'] as String? ?? '',
      );
}

/// A fresh detail response; unavailable results intentionally contain no clinical values.
class TestHistoryDetail {
  final TestHistorySummary summary;
  final List<TestHistoryItem> items;
  final String? conclusion;
  const TestHistoryDetail(this.summary, this.items, this.conclusion);
  factory TestHistoryDetail.fromJson(Map<String, dynamic> json) {
    final summary = TestHistorySummary.fromJson(
      json['summary'] as Map<String, dynamic>,
    );
    // Defense in depth: never render values if the detail is withheld, even from a malformed response.
    return TestHistoryDetail(
      summary,
      summary.available
          ? (json['items'] as List)
                .map((e) => TestHistoryItem.fromJson(e as Map<String, dynamic>))
                .toList()
          : [],
      summary.available ? json['conclusion'] as String? : null,
    );
  }
}

/// Server-counted page of history metadata, without cached measurements.
class TestHistoryPage {
  final List<TestHistorySummary> items;
  final int total, page, totalPages;
  const TestHistoryPage(this.items, this.total, this.page, this.totalPages);
  factory TestHistoryPage.fromJson(Map<String, dynamic> json) =>
      TestHistoryPage(
        (json['items'] as List)
            .map((e) => TestHistorySummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        (json['total'] as num).toInt(),
        (json['page'] as num).toInt(),
        (json['totalPages'] as num).toInt(),
      );
}
