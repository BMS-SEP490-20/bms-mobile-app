/// Data models representing specimen 6-stage lifecycle progress for UC48 (Track Test Progress Mobile).
/// Conforms to: ISO 15189, HIPAA Privacy Standards & Clean Architecture.

class TrackStageItem {
  final int stageIndex;
  final String code;
  final String title;
  final String description;
  final bool isCompleted;
  final bool isCurrent;
  final bool isFailed;
  final DateTime? completedAt;
  final String? performedBy;

  TrackStageItem({
    required this.stageIndex,
    required this.code,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.isCurrent,
    required this.isFailed,
    this.completedAt,
    this.performedBy,
  });

  factory TrackStageItem.fromJson(Map<String, dynamic> json) {
    DateTime? parsedTime;
    final rawDate = json['completedAt'] ?? json['timestamp'];
    if (rawDate != null) {
      try {
        parsedTime = DateTime.parse(rawDate.toString());
      } catch (_) {}
    }

    return TrackStageItem(
      stageIndex: json['stageIndex'] is int
          ? json['stageIndex']
          : int.tryParse(json['stepNumber']?.toString() ?? '0') ?? 0,
      code: json['code']?.toString() ?? json['stepCode']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isCompleted: json['isCompleted'] == true || json['status'] == 'Completed',
      isCurrent: json['isCurrent'] == true || json['status'] == 'InProgress',
      isFailed: json['isFailed'] == true || json['status'] == 'Rejected',
      completedAt: parsedTime,
      performedBy: json['performedBy']?.toString() ?? json['handlerName']?.toString(),
    );
  }

  // Compatibility getters with TrackingStepModel
  int get stepNumber => stageIndex + 1;
  String get stepCode => code;
  String get status => isCompleted
      ? 'Completed'
      : (isCurrent ? 'InProgress' : (isFailed ? 'Rejected' : 'Pending'));
  String get statusText => isCompleted
      ? 'Hoàn thành'
      : (isCurrent ? 'Đang thực hiện' : (isFailed ? 'Lỗi/Từ chối' : 'Chờ xử lý'));
  DateTime? get timestamp => completedAt;
  String? get handlerName => performedBy;
  String? get department => null;
  String? get notes => null;
  bool get isInProgress => isCurrent;
  bool get isWarning => false;
  bool get isRejected => isFailed;
}

// Type alias for backward compatibility
typedef TrackingStepModel = TrackStageItem;

class TrackTestItem {
  final String testId;
  final String testName;
  final String category;
  final String status;
  final String statusDescription;
  final String tubeType;

  TrackTestItem({
    required this.testId,
    required this.testName,
    required this.category,
    required this.status,
    required this.statusDescription,
    required this.tubeType,
  });

  factory TrackTestItem.fromJson(Map<String, dynamic> json) {
    return TrackTestItem(
      testId: json['testId']?.toString() ?? '',
      testName: json['testName']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      statusDescription: json['statusDescription']?.toString() ?? '',
      tubeType: json['tubeType']?.toString() ?? '',
    );
  }
}

class TrackProgressModel {
  final String orderId;
  final String orderCode;
  final String? barcode;
  final String patientId;
  final String patientNameMasked;
  final bool isStat;
  final String currentStage;
  final String currentStageName;
  final int currentStageIndex;
  final int totalStages;
  final String overallStatus;
  final DateTime orderedAt;
  final DateTime estimatedCompletionTime;
  final bool isOverdue;
  final bool isRejected;
  final String? rejectionReason;
  final bool isRerun;
  final String? rerunReason;
  final List<TrackStageItem> stages;
  final List<TrackTestItem> tests;

  TrackProgressModel({
    required this.orderId,
    required this.orderCode,
    this.barcode,
    required this.patientId,
    required this.patientNameMasked,
    required this.isStat,
    required this.currentStage,
    required this.currentStageName,
    required this.currentStageIndex,
    required this.totalStages,
    required this.overallStatus,
    required this.orderedAt,
    required this.estimatedCompletionTime,
    required this.isOverdue,
    required this.isRejected,
    this.rejectionReason,
    required this.isRerun,
    this.rerunReason,
    required this.stages,
    required this.tests,
  });

  factory TrackProgressModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return fallback;
      }
    }

    final rawStages = json['stages'] ?? json['steps'];
    final stageList = <TrackStageItem>[];
    if (rawStages is List) {
      for (final s in rawStages) {
        if (s is Map<String, dynamic>) {
          stageList.add(TrackStageItem.fromJson(s));
        }
      }
    }

    final rawTests = json['tests'];
    final testList = <TrackTestItem>[];
    if (rawTests is List) {
      for (final t in rawTests) {
        if (t is Map<String, dynamic>) {
          testList.add(TrackTestItem.fromJson(t));
        }
      }
    }

    final rawStat = json['isStat'];
    final priorityStr = json['priority']?.toString().toLowerCase() ?? '';
    final isStatFlag = rawStat == true || priorityStr == 'stat' || priorityStr == 'urgent';

    return TrackProgressModel(
      orderId: json['orderId']?.toString() ?? json['orderNumber']?.toString() ?? '',
      orderCode: json['orderCode']?.toString() ?? json['orderNumber']?.toString() ?? '',
      barcode: json['barcode']?.toString(),
      patientId: json['patientId']?.toString() ?? '',
      patientNameMasked: json['patientNameMasked']?.toString() ?? json['patientName']?.toString() ?? 'Bệnh nhân',
      isStat: isStatFlag,
      currentStage: json['currentStage']?.toString() ?? '',
      currentStageName: json['currentStageName']?.toString() ?? json['currentStepName']?.toString() ?? '',
      currentStageIndex: json['currentStageIndex'] is int
          ? json['currentStageIndex']
          : int.tryParse(json['currentStepNumber']?.toString() ?? '0') ?? 0,
      totalStages: json['totalStages'] is int ? json['totalStages'] : 6,
      overallStatus: json['overallStatus']?.toString() ?? 'Pending',
      orderedAt: parseDate(json['orderedAt'], DateTime.now()),
      estimatedCompletionTime: parseDate(json['estimatedCompletionTime'], DateTime.now()),
      isOverdue: json['isOverdue'] == true,
      isRejected: json['isRejected'] == true,
      rejectionReason: json['rejectionReason']?.toString(),
      isRerun: json['isRerun'] == true || json['isRerunRequested'] == true,
      rerunReason: json['rerunReason']?.toString(),
      stages: stageList,
      tests: testList,
    );
  }

  // Backward compatibility getters
  String get orderNumber => orderCode.isNotEmpty ? orderCode : orderId;
  String get patientName => patientNameMasked;
  String? get patientGender => null;
  int? get patientAge => null;
  String get priority => isStat ? 'STAT' : 'Normal';
  List<String> get testPackageNames => tests.map((t) => t.testName).toList();
  int get currentStepNumber => currentStageIndex + 1;
  String get currentStepName => currentStageName;
  double get elapsedMinutes => 0.0;
  bool get isCompleted => currentStage == 'Approved' || currentStageIndex >= 5;
  bool get isRerunRequested => isRerun;
  List<TrackStageItem> get steps => stages;
}
