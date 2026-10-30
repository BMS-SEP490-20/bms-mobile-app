/// Domain model for UC22 – Appointment Confirmation & Notification details (Flutter).
/// Consumes GET /api/appointments/{id}/confirmation.

library;

class TimelineItemModel {
  final String title;
  final String scheduledTime;
  final String description;
  final bool isDone;

  const TimelineItemModel({
    required this.title,
    required this.scheduledTime,
    required this.description,
    required this.isDone,
  });

  factory TimelineItemModel.fromJson(Map<String, dynamic> json) {
    return TimelineItemModel(
      title: json['title']?.toString() ?? '',
      scheduledTime: json['scheduledTime']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isDone: json['isDone'] == true,
    );
  }
}

class DeliveryStatusModel {
  final bool emailSent;
  final String? emailSentAt;
  final bool pushSent;
  final String? pushSentAt;
  final bool smsConfigured;

  const DeliveryStatusModel({
    this.emailSent = true,
    this.emailSentAt,
    this.pushSent = true,
    this.pushSentAt,
    this.smsConfigured = false,
  });

  factory DeliveryStatusModel.fromJson(Map<String, dynamic> json) {
    return DeliveryStatusModel(
      emailSent: json['emailSent'] != false,
      emailSentAt: json['emailSentAt']?.toString(),
      pushSent: json['pushSent'] != false,
      pushSentAt: json['pushSentAt']?.toString(),
      smsConfigured: json['smsConfigured'] == true,
    );
  }
}

class AppointmentConfirmationModel {
  final String appointmentId;
  final String appointmentCode;
  final String patientId;
  final String patientName;
  final String patientEmail;
  final String packageName;
  final double price;
  final String? doctorName;
  final String dateFormatted;
  final String timeFormatted;
  final String location;
  final String status;
  final String paymentStatus;
  final String fastingInstructions;
  final String qrCodeData;
  final DeliveryStatusModel deliveryStatus;
  final List<TimelineItemModel> reminderSchedule;

  const AppointmentConfirmationModel({
    required this.appointmentId,
    required this.appointmentCode,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    required this.packageName,
    required this.price,
    this.doctorName,
    required this.dateFormatted,
    required this.timeFormatted,
    required this.location,
    required this.status,
    required this.paymentStatus,
    required this.fastingInstructions,
    required this.qrCodeData,
    required this.deliveryStatus,
    required this.reminderSchedule,
  });

  factory AppointmentConfirmationModel.fromJson(Map<String, dynamic> json) {
    final scheduleRaw = json['reminderSchedule'] as List<dynamic>? ?? [];
    return AppointmentConfirmationModel(
      appointmentId: json['appointmentId']?.toString() ?? '',
      appointmentCode: json['appointmentCode']?.toString() ?? '',
      patientId: json['patientId']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? '',
      patientEmail: json['patientEmail']?.toString() ?? '',
      packageName: json['packageName']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      doctorName: json['doctorName']?.toString(),
      dateFormatted: json['dateFormatted']?.toString() ?? '',
      timeFormatted: json['timeFormatted']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      paymentStatus: json['paymentStatus']?.toString() ?? '',
      fastingInstructions: json['fastingInstructions']?.toString() ?? '',
      qrCodeData: json['qrCodeData']?.toString() ?? (json['appointmentCode']?.toString() ?? ''),
      deliveryStatus: json['deliveryStatus'] is Map<String, dynamic>
          ? DeliveryStatusModel.fromJson(json['deliveryStatus'] as Map<String, dynamic>)
          : const DeliveryStatusModel(),
      reminderSchedule: scheduleRaw
          .map((e) => TimelineItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
