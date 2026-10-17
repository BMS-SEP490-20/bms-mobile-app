/// Models for UC16 – View Doctor Schedule (Mobile).
library;

/// A single time-slot cell.
class ScheduleSlot {
  final String startTime;
  final String endTime;
  final String activity;
  final String roomName;
  final String detail;
  final bool isBreak;
  final bool isAvailable;

  const ScheduleSlot({
    required this.startTime,
    required this.endTime,
    required this.activity,
    required this.roomName,
    required this.detail,
    this.isBreak = false,
    this.isAvailable = false,
  });

  factory ScheduleSlot.fromJson(Map<String, dynamic> json) {
    return ScheduleSlot(
      startTime: json['startTime'] as String? ?? json['StartTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? json['EndTime'] as String? ?? '',
      activity: json['activity'] as String? ?? json['Activity'] as String? ?? '',
      roomName: json['roomName'] as String? ?? json['RoomName'] as String? ?? '',
      detail: json['detail'] as String? ?? json['Detail'] as String? ?? '',
      isBreak: json['isBreak'] as bool? ?? json['IsBreak'] as bool? ?? false,
      isAvailable: json['isAvailable'] as bool? ?? json['IsAvailable'] as bool? ?? false,
    );
  }
}

/// One doctor's column.
class DoctorColumn {
  final String doctorId;
  final String fullName;
  final String specialty;
  final String status;
  final String roomName;
  final List<ScheduleSlot> slots;

  const DoctorColumn({
    required this.doctorId,
    required this.fullName,
    required this.specialty,
    required this.status,
    required this.roomName,
    required this.slots,
  });

  factory DoctorColumn.fromJson(Map<String, dynamic> json) {
    final rawSlots =
        json['slots'] as List<dynamic>? ?? json['Slots'] as List<dynamic>? ?? [];
    return DoctorColumn(
      doctorId: json['doctorId'] as String? ?? json['DoctorId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? json['FullName'] as String? ?? '',
      specialty: json['specialty'] as String? ?? json['Specialty'] as String? ?? '',
      status: json['status'] as String? ?? json['Status'] as String? ?? 'Approved',
      roomName: json['roomName'] as String? ?? json['RoomName'] as String? ?? '',
      slots: rawSlots
          .map((e) => ScheduleSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Full day-schedule response.
class DoctorScheduleResponse {
  final String date;
  final String dateLabel;
  final List<String> timeRows;
  final List<DoctorColumn> doctors;
  final int totalDoctors;
  final String? note;

  const DoctorScheduleResponse({
    required this.date,
    required this.dateLabel,
    required this.timeRows,
    required this.doctors,
    required this.totalDoctors,
    this.note,
  });

  factory DoctorScheduleResponse.fromJson(Map<String, dynamic> json) {
    final rawDoctors =
        json['doctors'] as List<dynamic>? ?? json['Doctors'] as List<dynamic>? ?? [];
    final rawRows =
        json['timeRows'] as List<dynamic>? ?? json['TimeRows'] as List<dynamic>? ?? [];

    return DoctorScheduleResponse(
      date: json['date'] as String? ?? json['Date'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? json['DateLabel'] as String? ?? '',
      timeRows: rawRows.map((e) => e.toString()).toList(),
      doctors: rawDoctors
          .map((e) => DoctorColumn.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalDoctors:
          json['totalDoctors'] as int? ?? json['TotalDoctors'] as int? ?? rawDoctors.length,
      note: json['note'] as String? ?? json['Note'] as String?,
    );
  }
}