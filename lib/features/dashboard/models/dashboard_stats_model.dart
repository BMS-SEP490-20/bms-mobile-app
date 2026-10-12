class StatCardModel {
  final String key;
  final String title;
  final String value;
  final String icon;
  final String colorVariant;
  final String? subtitle;

  StatCardModel({
    required this.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.colorVariant,
    this.subtitle,
  });

  factory StatCardModel.fromJson(Map<String, dynamic> json) {
    return StatCardModel(
      key: json['key'] ?? '',
      title: json['title'] ?? '',
      value: json['value']?.toString() ?? '0',
      icon: json['icon'] ?? 'analytics',
      colorVariant: json['colorVariant'] ?? 'primary',
      subtitle: json['subtitle'],
    );
  }
}

class DashboardStatsModel {
  final String role;
  final String userName;
  final DateTime timestamp;
  final List<StatCardModel> summaryCards;
  final Map<String, dynamic>? rawRoleData;

  DashboardStatsModel({
    required this.role,
    required this.userName,
    required this.timestamp,
    required this.summaryCards,
    this.rawRoleData,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    var cardsList = <StatCardModel>[];
    if (json['summaryCards'] is List) {
      cardsList = (json['summaryCards'] as List)
          .map((item) => StatCardModel.fromJson(item))
          .toList();
    }

    return DashboardStatsModel(
      role: json['role'] ?? 'Patient',
      userName: json['userName'] ?? 'Võ Gia Huy',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      summaryCards: cardsList,
      rawRoleData: json,
    );
  }
}
