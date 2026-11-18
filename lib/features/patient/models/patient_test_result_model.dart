/// Model representing an individual laboratory parameter test result.
class PatientResultParameter {
  final String parameterName;
  final String value;
  final String unit;
  final String referenceRange;
  final String? deltaPrevious;
  final String flag;
  final bool isAbnormal;
  final String flagSeverity;

  PatientResultParameter({
    required this.parameterName,
    required this.value,
    required this.unit,
    required this.referenceRange,
    this.deltaPrevious,
    this.flag = 'N',
    this.isAbnormal = false,
    this.flagSeverity = 'normal',
  });

  factory PatientResultParameter.fromJson(Map<String, dynamic> json) {
    return PatientResultParameter(
      parameterName: json['parameterName'] ?? json['ParameterName'] ?? '',
      value: (json['value'] ?? json['Value'] ?? '').toString(),
      unit: json['unit'] ?? json['Unit'] ?? '',
      referenceRange: json['referenceRange'] ?? json['ReferenceRange'] ?? '',
      deltaPrevious: json['deltaPrevious'] ?? json['DeltaPrevious'],
      flag: json['flag'] ?? json['Flag'] ?? 'N',
      isAbnormal: json['isAbnormal'] ?? json['IsAbnormal'] ?? false,
      flagSeverity: json['flagSeverity'] ?? json['FlagSeverity'] ?? 'normal',
    );
  }

  Map<String, dynamic> toJson() => {
        'parameterName': parameterName,
        'value': value,
        'unit': unit,
        'referenceRange': referenceRange,
        'deltaPrevious': deltaPrevious,
        'flag': flag,
        'isAbnormal': isAbnormal,
        'flagSeverity': flagSeverity,
      };
}

/// Model representing a patient diagnostic test result packet for mobile display & PDF export.
class PatientTestResultModel {
  final String orderId;
  final String orderCode;
  final String packageName;
  final String category;
  final String patientId;
  final String patientName;
  final String dobAgeSex;
  final String collectionTime;
  final String releasedDate;
  final String approvedByDoctor;
  final String doctorSpecialty;
  final String doctorAssessment;
  final String overallStatus;
  final int abnormalCount;
  final String referenceIntervalNotes;
  final List<PatientResultParameter> parameters;
  final String verificationHash;
  final String shareToken;
  final String shareUrl;

  PatientTestResultModel({
    required this.orderId,
    required this.orderCode,
    required this.packageName,
    this.category = 'Sinh hóa - Huyết học',
    required this.patientId,
    required this.patientName,
    required this.dobAgeSex,
    required this.collectionTime,
    required this.releasedDate,
    required this.approvedByDoctor,
    this.doctorSpecialty = 'Đa khoa - Xét nghiệm',
    required this.doctorAssessment,
    this.overallStatus = 'Approved',
    this.abnormalCount = 0,
    this.referenceIntervalNotes = '',
    required this.parameters,
    this.verificationHash = '',
    this.shareToken = '',
    this.shareUrl = '',
  });

  factory PatientTestResultModel.fromJson(Map<String, dynamic> json) {
    final rawParams =
        (json['parameters'] ?? json['Parameters']) as List<dynamic>? ?? [];
    final params = rawParams
        .whereType<Map>()
        .map((p) => PatientResultParameter.fromJson(Map<String, dynamic>.from(p)))
        .toList();

    return PatientTestResultModel(
      orderId: (json['orderId'] ?? json['OrderId'] ?? '').toString(),
      orderCode: (json['orderCode'] ??
              json['OrderCode'] ??
              json['orderId'] ??
              '')
          .toString(),
      packageName:
          (json['packageName'] ?? json['PackageName'] ?? 'Phiếu kết quả xét nghiệm')
              .toString(),
      category:
          (json['category'] ?? json['Category'] ?? 'Sinh hóa - Huyết học')
              .toString(),
      patientId: (json['patientId'] ?? json['PatientId'] ?? '').toString(),
      patientName:
          (json['patientName'] ?? json['PatientName'] ?? 'Bệnh nhân').toString(),
      dobAgeSex: (json['dobAgeSex'] ?? json['DobAgeSex'] ?? 'Chưa ghi nhận')
          .toString(),
      collectionTime:
          (json['collectionTime'] ?? json['CollectionTime'] ?? '').toString(),
      releasedDate:
          (json['releasedDate'] ?? json['ReleasedDate'] ?? '').toString(),
      approvedByDoctor: (json['approvedByDoctor'] ??
              json['ApprovedByDoctor'] ??
              'Bác sĩ duyệt kết quả')
          .toString(),
      doctorSpecialty: (json['doctorSpecialty'] ??
              json['DoctorSpecialty'] ??
              'Khoa Xét Nghiệm')
          .toString(),
      doctorAssessment:
          (json['doctorAssessment'] ?? json['DoctorAssessment'] ?? '')
              .toString(),
      overallStatus:
          (json['overallStatus'] ?? json['OverallStatus'] ?? 'Approved')
              .toString(),
      abnormalCount:
          int.tryParse((json['abnormalCount'] ?? json['AbnormalCount'] ?? '0').toString()) ?? 0,
      referenceIntervalNotes: (json['referenceIntervalNotes'] ??
              json['ReferenceIntervalNotes'] ??
              '')
          .toString(),
      parameters: params,
      verificationHash:
          (json['verificationHash'] ?? json['VerificationHash'] ?? '')
              .toString(),
      shareToken: (json['shareToken'] ?? json['ShareToken'] ?? '').toString(),
      shareUrl: (json['shareUrl'] ?? json['ShareUrl'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'orderCode': orderCode,
        'packageName': packageName,
        'category': category,
        'patientId': patientId,
        'patientName': patientName,
        'dobAgeSex': dobAgeSex,
        'collectionTime': collectionTime,
        'releasedDate': releasedDate,
        'approvedByDoctor': approvedByDoctor,
        'doctorSpecialty': doctorSpecialty,
        'doctorAssessment': doctorAssessment,
        'overallStatus': overallStatus,
        'abnormalCount': abnormalCount,
        'referenceIntervalNotes': referenceIntervalNotes,
        'parameters': parameters.map((p) => p.toJson()).toList(),
        'verificationHash': verificationHash,
        'shareToken': shareToken,
        'shareUrl': shareUrl,
      };
}
