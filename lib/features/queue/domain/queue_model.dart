/// Domain models for UC27 – Reception Queue Management (Flutter).

class QueueTicketModel {
  final String id;
  final String ticketNumber;
  final String patientName;
  final String patientCode;
  final String packageName;
  final bool isWalkIn;
  final String checkedInTime;
  final int waitTimeMinutes;
  final String priority;
  final String status;
  final String? counterName;

  const QueueTicketModel({
    required this.id,
    required this.ticketNumber,
    required this.patientName,
    required this.patientCode,
    required this.packageName,
    this.isWalkIn = false,
    required this.checkedInTime,
    required this.waitTimeMinutes,
    required this.priority,
    required this.status,
    this.counterName,
  });

  factory QueueTicketModel.fromJson(Map<String, dynamic> json) {
    return QueueTicketModel(
      id: json['id']?.toString() ?? '',
      ticketNumber: json['ticketNumber']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? '',
      patientCode: json['patientCode']?.toString() ?? '',
      packageName: json['packageName']?.toString() ?? '',
      isWalkIn: json['isWalkIn'] == true,
      checkedInTime: json['checkedInTime']?.toString() ?? '',
      waitTimeMinutes: (json['waitTimeMinutes'] as num?)?.toInt() ?? 0,
      priority: json['priority']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      counterName: json['counterName']?.toString(),
    );
  }
}

class QueueStatsModel {
  final int inQueueNow;
  final int avgWaitMinutes;
  final int longestWaitMinutes;
  final int servedToday;
  final String countersActive;

  const QueueStatsModel({
    this.inQueueNow = 0,
    this.avgWaitMinutes = 0,
    this.longestWaitMinutes = 0,
    this.servedToday = 0,
    this.countersActive = '',
  });

  factory QueueStatsModel.fromJson(Map<String, dynamic> json) {
    return QueueStatsModel(
      inQueueNow: (json['inQueueNow'] as num?)?.toInt() ?? 0,
      avgWaitMinutes: (json['avgWaitMinutes'] as num?)?.toInt() ?? 0,
      longestWaitMinutes: (json['longestWaitMinutes'] as num?)?.toInt() ?? 0,
      servedToday: (json['servedToday'] as num?)?.toInt() ?? 0,
      countersActive: json['countersActive']?.toString() ?? '',
    );
  }
}

class QueueBoardModel {
  final List<QueueTicketModel> currentQueue;
  final String nextNumber;
  final QueueStatsModel stats;

  const QueueBoardModel({
    required this.currentQueue,
    required this.nextNumber,
    required this.stats,
  });

  factory QueueBoardModel.fromJson(Map<String, dynamic> json) {
    final list = json['currentQueue'] as List<dynamic>? ?? [];
    return QueueBoardModel(
      currentQueue: list
          .map((e) => QueueTicketModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextNumber: json['nextNumber']?.toString() ?? '',
      stats: json['stats'] is Map<String, dynamic>
          ? QueueStatsModel.fromJson(json['stats'] as Map<String, dynamic>)
          : const QueueStatsModel(),
    );
  }
}
