/// Domain model for UC22 – Appointment Confirmation & Notification details (Flutter).
/// Consumes GET /api/appointments/{id}/confirmation.

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
      appointmentCode: json['appointmentCode']?.toString() ?? 'APT-261010-0342',
      patientId: json['patientId']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? 'Nguyễn Văn An',
      patientEmail: json['patientEmail']?.toString() ?? 'an.nguyen@example.com',
      packageName: json['packageName']?.toString() ?? 'Lipid Profile',
      price: (json['price'] as num?)?.toDouble() ?? 250000,
      doctorName: json['doctorName']?.toString(),
      dateFormatted: json['dateFormatted']?.toString() ?? 'Fri 10 Oct',
      timeFormatted: json['timeFormatted']?.toString() ?? '08:00',
      location: json['location']?.toString() ?? 'Lab Room 02',
      status: json['status']?.toString() ?? 'Confirmed',
      paymentStatus: json['paymentStatus']?.toString() ?? 'Paid',
      fastingInstructions: json['fastingInstructions']?.toString() ??
          'Do not eat or drink anything except water for 12 hours before your collection.',
      qrCodeData: json['qrCodeData']?.toString() ?? 'APT-261010-0342|CONFIRMED',
      deliveryStatus: json['deliveryStatus'] is Map<String, dynamic>
          ? DeliveryStatusModel.fromJson(json['deliveryStatus'] as Map<String, dynamic>)
          : const DeliveryStatusModel(),
      reminderSchedule: scheduleRaw
          .map((e) => TimelineItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static AppointmentConfirmationModel defaultMock(String code) {
    return AppointmentConfirmationModel(
      appointmentId: 'mock-appt-01',
      appointmentCode: code.isNotEmpty ? code : 'APT-261010-0342',
      patientId: 'USR-PAT-01',
      patientName: 'Nguyễn Văn An',
      patientEmail: 'an.nguyen@example.com',
      packageName: 'Lipid Profile — Standard',
      price: 250000,
      doctorName: 'BS. Nguyễn Văn An',
      dateFormatted: 'Fri 10 Oct',
      timeFormatted: '08:00',
      location: 'Lab Room 02',
      status: 'Confirmed',
      paymentStatus: 'Paid',
      fastingInstructions:
          'Fasting 12h. Do not eat or drink anything except water. Last meal by 20:00 on 09 Oct.',
      qrCodeData: '$code|CONFIRMED|2026-10-10|USR-PAT-01',
      deliveryStatus: const DeliveryStatusModel(
        emailSent: true,
        emailSentAt: '11:46',
        pushSent: true,
        pushSentAt: '11:46',
      ),
      reminderSchedule: const [
        TimelineItemModel(
          title: 'Booking confirmed',
          scheduledTime: '06 Oct · 11:46',
          description: 'Email + Push notification sent',
          isDone: true,
        ),
        TimelineItemModel(
          title: '48-hour reminder',
          scheduledTime: '08 Oct · 08:00',
          description: 'Email + Push · Fasting instructions',
          isDone: false,
        ),
        TimelineItemModel(
          title: 'Evening reminder',
          scheduledTime: '09 Oct · 20:00',
          description: 'Push notification · Begin fasting now',
          isDone: false,
        ),
        TimelineItemModel(
          title: 'Morning of appointment',
          scheduledTime: '10 Oct · 07:00',
          description: 'Push · Arrive by 07:45',
          isDone: false,
        ),
      ],
    );
  }
}
