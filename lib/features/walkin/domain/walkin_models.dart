class RegisterWalkInRequest {
  final String fullName;
  final String dateOfBirth; // YYYY-MM-DD
  final String gender;
  final String phone;
  final String identityNumber;
  final String? email;
  final String? address;
  final String? bloodType;
  final String? medicalHistory;
  final String priority;

  const RegisterWalkInRequest({
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    required this.phone,
    required this.identityNumber,
    this.email,
    this.address,
    this.bloodType,
    this.medicalHistory,
    this.priority = 'NORMAL',
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'phone': phone,
        'identityNumber': identityNumber,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        if (bloodType != null) 'bloodType': bloodType,
        if (medicalHistory != null) 'medicalHistory': medicalHistory,
        'priority': priority,
      };
}

class RegisterWalkInResponse {
  final String patientId;
  final String fullName;
  final String identityNumber;
  final String phone;
  final String priority;
  final String message;

  const RegisterWalkInResponse({
    required this.patientId,
    required this.fullName,
    required this.identityNumber,
    required this.phone,
    required this.priority,
    required this.message,
  });

  factory RegisterWalkInResponse.fromJson(Map<String, dynamic> json) {
    return RegisterWalkInResponse(
      patientId: json['patientId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      identityNumber: json['identityNumber'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      priority: json['priority'] as String? ?? 'NORMAL',
      message: json['message'] as String? ?? '',
    );
  }
}

class PatientLookupResponse {
  final bool exists;
  final String? patientId;
  final String? fullName;
  final String? identityNumber;
  final String? phone;
  final String? dateOfBirth;
  final String? gender;

  const PatientLookupResponse({
    required this.exists,
    this.patientId,
    this.fullName,
    this.identityNumber,
    this.phone,
    this.dateOfBirth,
    this.gender,
  });

  factory PatientLookupResponse.fromJson(Map<String, dynamic> json) {
    return PatientLookupResponse(
      exists: json['exists'] as bool? ?? false,
      patientId: json['patientId'] as String?,
      fullName: json['fullName'] as String?,
      identityNumber: json['identityNumber'] as String?,
      phone: json['phone'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      gender: json['gender'] as String?,
    );
  }
}

