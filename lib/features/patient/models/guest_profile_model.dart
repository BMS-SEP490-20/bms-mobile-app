/// Models for Create Guest Profile (UC25 – Mobile) and View Patient Information (UC30 – Mobile).
///
/// Maps JSON payloads for `POST /api/patients/guests` and `GET /api/patients`.
library;

/// Vital signs measurements for a patient / guest profile.
class PatientVitalsModel {
  final double? heightCm;
  final double? weightKg;
  final String? bloodPressure;
  final int? heartRateBpm;
  final double? temperatureC;
  final int? spo2Percent;

  const PatientVitalsModel({
    this.heightCm,
    this.weightKg,
    this.bloodPressure,
    this.heartRateBpm,
    this.temperatureC,
    this.spo2Percent,
  });

  double? get bmi {
    if (heightCm == null ||
        weightKg == null ||
        heightCm! <= 0 ||
        weightKg! <= 0) {
      return null;
    }
    final hm = heightCm! / 100.0;
    return double.parse((weightKg! / (hm * hm)).toStringAsFixed(1));
  }

  factory PatientVitalsModel.fromJson(Map<String, dynamic> json) {
    return PatientVitalsModel(
      heightCm: (json['heightCm'] as num?)?.toDouble() ??
          (json['HeightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble() ??
          (json['WeightKg'] as num?)?.toDouble(),
      bloodPressure:
          (json['bloodPressure'] ?? json['BloodPressure'])?.toString(),
      heartRateBpm:
          (json['heartRateBpm'] as num?)?.toInt() ??
          (json['HeartRateBpm'] as num?)?.toInt(),
      temperatureC: (json['temperatureC'] as num?)?.toDouble() ??
          (json['TemperatureC'] as num?)?.toDouble(),
      spo2Percent:
          (json['spo2Percent'] as num?)?.toInt() ??
          (json['Spo2Percent'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (heightCm != null) 'heightCm': heightCm,
        if (weightKg != null) 'weightKg': weightKg,
        if (bloodPressure != null && bloodPressure!.trim().isNotEmpty)
          'bloodPressure': bloodPressure!.trim(),
        if (heartRateBpm != null) 'heartRateBpm': heartRateBpm,
        if (temperatureC != null) 'temperatureC': temperatureC,
        if (spo2Percent != null) 'spo2Percent': spo2Percent,
      };
}

/// Request payload for `POST /api/patients/guests` (Create Guest Profile).
class CreateGuestProfileRequestModel {
  final String fullName;
  final String dateOfBirth; // YYYY-MM-DD
  final String gender; // Male, Female, Other
  final String phoneNumber;
  final String? email;
  final String? identityNumber;
  final String? address;
  final String? bloodType;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? medicalHistory;
  final List<String> allergies;
  final PatientVitalsModel? vitals;

  const CreateGuestProfileRequestModel({
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    required this.phoneNumber,
    this.email,
    this.identityNumber,
    this.address,
    this.bloodType = 'Unknown',
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.medicalHistory,
    this.allergies = const [],
    this.vitals,
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName.trim(),
        'dateOfBirth': dateOfBirth.trim(),
        'gender': gender.trim(),
        'phoneNumber': phoneNumber.trim(),
        if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
        if (identityNumber != null && identityNumber!.trim().isNotEmpty)
          'identityNumber': identityNumber!.trim(),
        if (address != null && address!.trim().isNotEmpty)
          'address': address!.trim(),
        if (bloodType != null && bloodType!.trim().isNotEmpty)
          'bloodType': bloodType!.trim(),
        if (emergencyContactName != null &&
            emergencyContactName!.trim().isNotEmpty)
          'emergencyContactName': emergencyContactName!.trim(),
        if (emergencyContactPhone != null &&
            emergencyContactPhone!.trim().isNotEmpty)
          'emergencyContactPhone': emergencyContactPhone!.trim(),
        if (medicalHistory != null && medicalHistory!.trim().isNotEmpty)
          'medicalHistory': medicalHistory!.trim(),
        'allergies': allergies
            .map((a) => a.trim())
            .where((a) => a.isNotEmpty)
            .toList(),
        if (vitals != null && vitals!.toJson().isNotEmpty)
          'vitals': vitals!.toJson(),
      };
}

/// Response DTO representing a created or retrieved Patient / Guest Profile (`PatientInformationDto`).
class PatientProfileModel {
  final String id;
  final String patientCode;
  final bool isGuest;
  final String fullName;
  final DateTime? dateOfBirth;
  final int? age;
  final String gender;
  final String phoneNumber;
  final String? email;
  final String? identityNumber;
  final String? address;
  final String bloodType;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? medicalHistory;
  final List<String> allergies;
  final PatientVitalsModel? vitals;
  final DateTime? createdAt;

  const PatientProfileModel({
    required this.id,
    required this.patientCode,
    required this.isGuest,
    required this.fullName,
    this.dateOfBirth,
    this.age,
    required this.gender,
    required this.phoneNumber,
    this.email,
    this.identityNumber,
    this.address,
    this.bloodType = 'Unknown',
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.medicalHistory,
    this.allergies = const [],
    this.vitals,
    this.createdAt,
  });

  factory PatientProfileModel.fromJson(Map<String, dynamic> json) {
    final rawAllergies = json['allergies'] as List<dynamic>? ??
        json['Allergies'] as List<dynamic>? ??
        const [];

    final rawVitals = json['vitals'] ?? json['Vitals'];

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    final idVal = (json['id'] ?? json['Id'] ?? '').toString();
    final codeVal =
        (json['patientCode'] ?? json['PatientCode'] ?? idVal).toString();

    return PatientProfileModel(
      id: idVal,
      patientCode: codeVal,
      isGuest: json['isGuest'] as bool? ?? json['IsGuest'] as bool? ?? true,
      fullName: (json['fullName'] ?? json['FullName'] ?? '').toString(),
      dateOfBirth: parseDate(json['dateOfBirth'] ?? json['DateOfBirth']),
      age: (json['age'] as num?)?.toInt() ?? (json['Age'] as num?)?.toInt(),
      gender: (json['gender'] ?? json['Gender'] ?? 'Unspecified').toString(),
      phoneNumber: (json['phoneNumber'] ??
              json['PhoneNumber'] ??
              json['phone'] ??
              '')
          .toString(),
      email: (json['email'] ?? json['Email'])?.toString(),
      identityNumber: (json['identityNumber'] ??
              json['IdentityNumber'] ??
              json['identityCard'])
          ?.toString(),
      address: (json['address'] ?? json['Address'])?.toString(),
      bloodType:
          (json['bloodType'] ?? json['BloodType'] ?? 'Unknown').toString(),
      emergencyContactName:
          (json['emergencyContactName'] ?? json['EmergencyContactName'])
              ?.toString(),
      emergencyContactPhone:
          (json['emergencyContactPhone'] ?? json['EmergencyContactPhone'])
              ?.toString(),
      medicalHistory:
          (json['medicalHistory'] ?? json['MedicalHistory'])?.toString(),
      allergies: rawAllergies.map((e) => e.toString()).toList(),
      vitals: rawVitals is Map<String, dynamic>
          ? PatientVitalsModel.fromJson(rawVitals)
          : null,
      createdAt: parseDate(json['createdAt'] ?? json['CreatedAt']),
    );
  }

  String get genderLabelVi {
    switch (gender.toLowerCase()) {
      case 'male':
      case 'nam':
        return 'Nam';
      case 'female':
      case 'nữ':
      case 'nu':
        return 'Nữ';
      case 'other':
        return 'Khác';
      default:
        return gender;
    }
  }
}
