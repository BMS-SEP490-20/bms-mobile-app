/// Data model representing a laboratory diagnostic test result notification in BMS Mobile (UC60 / BR-184).
/// Conforms to: Production Medical Standards, Clinical Emergency Escalation & AGENTS-CODE.md.
class TestResultNotificationModel {
  final String id;
  final String notificationId;
  final String testOrderId;
  final String? specimenBarcode;
  final String patientId;
  final String patientName;
  final String? patientPhone;
  final String? patientEmail;
  final String title;
  final String message;
  final String channel;
  final String priority;
  final String status;
  final bool isCriticalPanicValue;
  final List<String> criticalParameters;
  final bool requiresImmediateAction;
  final String? clinicalRecommendation;
  final String? testPackageName;
  final String? sentAt;
  final String? deliveredAt;
  final String? readAt;
  final String? failureReason;
  final int retryCount;
  final String createdAt;

  TestResultNotificationModel({
    required this.id,
    required this.notificationId,
    required this.testOrderId,
    this.specimenBarcode,
    required this.patientId,
    required this.patientName,
    this.patientPhone,
    this.patientEmail,
    required this.title,
    required this.message,
    required this.channel,
    required this.priority,
    required this.status,
    required this.isCriticalPanicValue,
    required this.criticalParameters,
    required this.requiresImmediateAction,
    this.clinicalRecommendation,
    this.testPackageName,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.failureReason,
    required this.retryCount,
    required this.createdAt,
  });

  bool get isRead => status.toLowerCase() == 'read';

  factory TestResultNotificationModel.fromJson(Map<String, dynamic> json) {
    return TestResultNotificationModel(
      id: json['id']?.toString() ?? '',
      notificationId: json['notificationId']?.toString() ?? '',
      testOrderId: json['testOrderId']?.toString() ?? '',
      specimenBarcode: json['specimenBarcode']?.toString(),
      patientId: json['patientId']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? '',
      patientPhone: json['patientPhone']?.toString(),
      patientEmail: json['patientEmail']?.toString(),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      channel: json['channel']?.toString() ?? 'InApp',
      priority: json['priority']?.toString() ?? 'Normal',
      status: json['status']?.toString() ?? 'Delivered',
      isCriticalPanicValue: json['isCriticalPanicValue'] == true,
      criticalParameters: (json['criticalParameters'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      requiresImmediateAction: json['requiresImmediateAction'] == true,
      clinicalRecommendation: json['clinicalRecommendation']?.toString(),
      testPackageName: json['testPackageName']?.toString(),
      sentAt: json['sentAt']?.toString(),
      deliveredAt: json['deliveredAt']?.toString(),
      readAt: json['readAt']?.toString(),
      failureReason: json['failureReason']?.toString(),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'notificationId': notificationId,
      'testOrderId': testOrderId,
      'specimenBarcode': specimenBarcode,
      'patientId': patientId,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'patientEmail': patientEmail,
      'title': title,
      'message': message,
      'channel': channel,
      'priority': priority,
      'status': status,
      'isCriticalPanicValue': isCriticalPanicValue,
      'criticalParameters': criticalParameters,
      'requiresImmediateAction': requiresImmediateAction,
      'clinicalRecommendation': clinicalRecommendation,
      'testPackageName': testPackageName,
      'sentAt': sentAt,
      'deliveredAt': deliveredAt,
      'readAt': readAt,
      'failureReason': failureReason,
      'retryCount': retryCount,
      'createdAt': createdAt,
    };
  }
}
