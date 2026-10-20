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
      ticketNumber: json['ticketNumber']?.toString() ?? 'Q-001',
      patientName: json['patientName']?.toString() ?? 'Bệnh nhân',
      patientCode: json['patientCode']?.toString() ?? 'PT-000000',
      packageName: json['packageName']?.toString() ?? 'Tổng quát',
      isWalkIn: json['isWalkIn'] == true,
      checkedInTime: json['checkedInTime']?.toString() ?? '08:00',
      waitTimeMinutes: (json['waitTimeMinutes'] as num?)?.toInt() ?? 5,
      priority: json['priority']?.toString() ?? 'Routine',
      status: json['status']?.toString() ?? 'Waiting',
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
    this.inQueueNow = 7,
    this.avgWaitMinutes = 12,
    this.longestWaitMinutes = 16,
    this.servedToday = 18,
    this.countersActive = '2 / 3',
  });

  factory QueueStatsModel.fromJson(Map<String, dynamic> json) {
    return QueueStatsModel(
      inQueueNow: (json['inQueueNow'] as num?)?.toInt() ?? 7,
      avgWaitMinutes: (json['avgWaitMinutes'] as num?)?.toInt() ?? 12,
      longestWaitMinutes: (json['longestWaitMinutes'] as num?)?.toInt() ?? 16,
      servedToday: (json['servedToday'] as num?)?.toInt() ?? 18,
      countersActive: json['countersActive']?.toString() ?? '2 / 3',
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
      nextNumber: json['nextNumber']?.toString() ?? 'Q-019',
      stats: json['stats'] is Map<String, dynamic>
          ? QueueStatsModel.fromJson(json['stats'] as Map<String, dynamic>)
          : const QueueStatsModel(),
    );
  }

  static QueueBoardModel defaultMock() {
    return const QueueBoardModel(
      currentQueue: [
        QueueTicketModel(
          id: 'TKT-012',
          ticketNumber: 'Q-012',
          patientName: 'Lê Hoàng Nam',
          patientCode: 'PT-012056',
          packageName: 'Thyroid',
          checkedInTime: '08:48',
          waitTimeMinutes: 5,
          priority: 'Routine',
          status: 'Called',
          counterName: 'Counter 1',
        ),
        QueueTicketModel(
          id: 'TKT-013',
          ticketNumber: 'Q-013',
          patientName: 'Trần Thị Mai',
          patientCode: 'PT-008214',
          packageName: 'CBC',
          checkedInTime: '08:52',
          waitTimeMinutes: 8,
          priority: 'Routine',
          status: 'Waiting',
        ),
        QueueTicketModel(
          id: 'TKT-014',
          ticketNumber: 'Q-014',
          patientName: 'Hoàng Văn Kiên',
          patientCode: 'PT-010334',
          packageName: 'Lipid',
          isWalkIn: true,
          checkedInTime: '08:55',
          waitTimeMinutes: 11,
          priority: 'Routine',
          status: 'Waiting',
        ),
        QueueTicketModel(
          id: 'TKT-016',
          ticketNumber: 'Q-016',
          patientName: 'Phạm Minh Ơn',
          patientCode: 'PT-004987',
          packageName: 'Liver Function',
          checkedInTime: '09:08',
          waitTimeMinutes: 8,
          priority: 'Urgent',
          status: 'Waiting',
        ),
        QueueTicketModel(
          id: 'TKT-017',
          ticketNumber: 'Q-017',
          patientName: 'Lý Thị Hoa',
          patientCode: 'PT-009876',
          packageName: 'Thyroid + Liver',
          checkedInTime: '09:12',
          waitTimeMinutes: 4,
          priority: 'STAT',
          status: 'Waiting',
        ),
      ],
      nextNumber: 'Q-019',
      stats: QueueStatsModel(),
    );
  }
}
