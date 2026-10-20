/// Model representing an individual laboratory parameter test result (UC62).
class PatientResultParameter {
  final String parameterName;
  final String value;
  final String unit;
  final String referenceRange;
  final String? deltaPrevious;
  final String flag; // 'HH', 'H', 'N', 'L', 'LL'
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

/// Model representing a patient diagnostic test result packet for mobile display & PDF export (UC62 / Issue I3-045).
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
    this.category = 'Biochemistry',
    required this.patientId,
    required this.patientName,
    required this.dobAgeSex,
    required this.collectionTime,
    required this.releasedDate,
    required this.approvedByDoctor,
    this.doctorSpecialty = 'Internal Medicine',
    required this.doctorAssessment,
    this.overallStatus = 'Released',
    this.abnormalCount = 0,
    this.referenceIntervalNotes = 'Adult reference intervals · Fasting verified',
    required this.parameters,
    this.verificationHash = '',
    this.shareToken = '',
    this.shareUrl = '',
  });

  factory PatientTestResultModel.fromJson(Map<String, dynamic> json) {
    var rawParams = json['parameters'] ?? json['Parameters'] as List? ?? [];
    var params = rawParams
        .map((p) => PatientResultParameter.fromJson(p as Map<String, dynamic>))
        .toList();

    return PatientTestResultModel(
      orderId: json['orderId'] ?? json['OrderId'] ?? '',
      orderCode: json['orderCode'] ?? json['OrderCode'] ?? json['orderId'] ?? '',
      packageName: json['packageName'] ?? json['PackageName'] ?? 'Lipid Profile',
      category: json['category'] ?? json['Category'] ?? 'Biochemistry',
      patientId: json['patientId'] ?? json['PatientId'] ?? '',
      patientName: json['patientName'] ?? json['PatientName'] ?? 'Nguyễn Văn An',
      dobAgeSex: json['dobAgeSex'] ?? json['DobAgeSex'] ?? 'Male 34y',
      collectionTime: json['collectionTime'] ?? json['CollectionTime'] ?? '',
      releasedDate: json['releasedDate'] ?? json['ReleasedDate'] ?? '',
      approvedByDoctor: json['approvedByDoctor'] ?? json['ApprovedByDoctor'] ?? 'Dr. Trần Thị Bình',
      doctorSpecialty: json['doctorSpecialty'] ?? json['DoctorSpecialty'] ?? 'Internal Medicine',
      doctorAssessment: json['doctorAssessment'] ?? json['DoctorAssessment'] ?? '',
      overallStatus: json['overallStatus'] ?? json['OverallStatus'] ?? 'Released',
      abnormalCount: json['abnormalCount'] ?? json['AbnormalCount'] ?? 0,
      referenceIntervalNotes: json['referenceIntervalNotes'] ?? json['ReferenceIntervalNotes'] ?? '',
      parameters: params,
      verificationHash: json['verificationHash'] ?? json['VerificationHash'] ?? '',
      shareToken: json['shareToken'] ?? json['ShareToken'] ?? '',
      shareUrl: json['shareUrl'] ?? json['ShareUrl'] ?? '',
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
