/// Domain models for UC21 Book Appointment (Flutter).
/// Aligned with BMS.Core.Entities.Appointment (no qrToken / priority / packageIds list on entity).

library;

class BookAppointmentRequest {
  final String patientId;
  final String doctorId;
  final String appointmentDate; // YYYY-MM-DD
  final String slotTime; // HH:mm
  final List<String> packageIds;
  final String? notes;
  final String type;
  final String? collectionAddress;

  const BookAppointmentRequest({
    required this.patientId,
    required this.doctorId,
    required this.appointmentDate,
    required this.slotTime,
    required this.packageIds,
    this.notes,
    this.type = 'ClinicVisit',
    this.collectionAddress,
  });

  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        'doctorId': doctorId,
        'appointmentDate': appointmentDate,
        'slotTime': slotTime,
        'packageIds': packageIds,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'type': type,
        if (collectionAddress != null) 'collectionAddress': collectionAddress,
      };
}

class BookAppointmentResponse {
  final String appointmentId;
  final String appointmentCode;
  final String patientId;
  final String? doctorId;
  final String doctorName;
  final String specialty;
  final String appointmentDate;
  final String slotTime;
  final String? endTime;
  final String status;
  final String? type;
  final String? packageId;
  final String message;

  const BookAppointmentResponse({
    required this.appointmentId,
    required this.appointmentCode,
    required this.patientId,
    this.doctorId,
    required this.doctorName,
    required this.specialty,
    required this.appointmentDate,
    required this.slotTime,
    this.endTime,
    required this.status,
    this.type,
    this.packageId,
    required this.message,
  });

  factory BookAppointmentResponse.fromJson(Map<String, dynamic> json) {
    return BookAppointmentResponse(
      appointmentId: json['appointmentId'] as String? ?? '',
      appointmentCode: json['appointmentCode'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      doctorId: json['doctorId'] as String?,
      doctorName: json['doctorName'] as String? ?? '',
      specialty: json['specialty'] as String? ?? '',
      appointmentDate: json['appointmentDate'] as String? ?? '',
      slotTime: json['slotTime'] as String? ?? '',
      endTime: json['endTime'] as String?,
      status: json['status'] as String? ?? '',
      type: json['type'] as String?,
      packageId: json['packageId'] as String?,
      message: json['message'] as String? ?? 'Appointment booked successfully.',
    );
  }
}

class AvailableSlot {
  final String slotTime;
  final int remainingCapacity;
  final bool isAvailable;

  const AvailableSlot({
    required this.slotTime,
    required this.remainingCapacity,
    required this.isAvailable,
  });

  factory AvailableSlot.fromJson(Map<String, dynamic> json) {
    return AvailableSlot(
      slotTime: json['slotTime'] as String? ?? '',
      remainingCapacity: json['remainingCapacity'] as int? ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? false,
    );
  }
}

class AvailableSlotsResponse {
  final String doctorId;
  final String doctorName;
  final String date;
  final List<AvailableSlot> slots;

  const AvailableSlotsResponse({
    required this.doctorId,
    required this.doctorName,
    required this.date,
    required this.slots,
  });

  factory AvailableSlotsResponse.fromJson(Map<String, dynamic> json) {
    return AvailableSlotsResponse(
      doctorId: json['doctorId'] as String? ?? '',
      doctorName: json['doctorName'] as String? ?? '',
      date: json['date'] as String? ?? '',
      slots: (json['slots'] as List<dynamic>?)
              ?.map((e) => AvailableSlot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class DoctorOption {
  final String doctorId;
  final String doctorName;
  final String specialty;

  const DoctorOption({
    required this.doctorId,
    required this.doctorName,
    required this.specialty,
  });

  factory DoctorOption.fromJson(Map<String, dynamic> json) {
    return DoctorOption(
      doctorId: json['doctorId'] as String? ?? '',
      doctorName: json['doctorName'] as String? ?? '',
      specialty: json['specialty'] as String? ?? '',
    );
  }
}

class TestPackageOption {
  final String packageId;
  final String packageName;
  final int price;
  final String? description;

  const TestPackageOption({
    required this.packageId,
    required this.packageName,
    required this.price,
    this.description,
  });
}
