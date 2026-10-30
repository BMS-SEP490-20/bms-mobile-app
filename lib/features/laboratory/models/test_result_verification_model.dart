/// Technical Test Result Verification models (UC72 / Verify Test Results / Issue I3-075).
/// Conforms to: Production Engineering Standards & AGENTS-CODE.md.

library;

class VerificationCheckItemModel {
  final String checkName;
  final String status;
  final String statusType;
  final String details;

  VerificationCheckItemModel({
    required this.checkName,
    required this.status,
    required this.statusType,
    required this.details,
  });

  factory VerificationCheckItemModel.fromJson(Map<String, dynamic> json) {
    return VerificationCheckItemModel(
      checkName: json['checkName'] as String? ?? '',
      status: json['status'] as String? ?? 'OK',
      statusType: json['statusType'] as String? ?? 'ok',
      details: json['details'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'checkName': checkName,
        'status': status,
        'statusType': statusType,
        'details': details,
      };
}

class TestResultVerificationDetailModel {
  final String specimenId;
  final String orderId;
  final String packageName;
  final String patientId;
  final String patientName;
  final List<VerificationCheckItemModel> checklist;
  String verifierComment;
  String status;
  String verifiedBy;
  DateTime? verifiedAt;
  String? returnedReason;
  final int flagCount;

  TestResultVerificationDetailModel({
    required this.specimenId,
    required this.orderId,
    required this.packageName,
    required this.patientId,
    required this.patientName,
    required this.checklist,
    required this.verifierComment,
    required this.status,
    required this.verifiedBy,
    this.verifiedAt,
    this.returnedReason,
    required this.flagCount,
  });

  factory TestResultVerificationDetailModel.fromJson(Map<String, dynamic> json) {
    var rawChecklist = json['checklist'] as List<dynamic>? ?? [];
    var parsedChecklist = rawChecklist
        .map((e) => VerificationCheckItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return TestResultVerificationDetailModel(
      specimenId: json['specimenId'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      packageName: json['packageName'] as String? ?? 'Lipid Profile',
      patientId: json['patientId'] as String? ?? '',
      patientName: json['patientName'] as String? ?? '',
      checklist: parsedChecklist,
      verifierComment: json['verifierComment'] as String? ?? '',
      status: json['status'] as String? ?? 'PendingVerification',
      verifiedBy: json['verifiedBy'] as String? ?? '',
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'] as String)
          : null,
      returnedReason: json['returnedReason'] as String?,
      flagCount: json['flagCount'] as int? ??
          parsedChecklist.where((c) => c.status.toLowerCase() == 'flag').length,
    );
  }
}
