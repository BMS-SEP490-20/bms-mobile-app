import '../../../../core/network/bms_http_client.dart';
import '../../../../services/bms_auth.dart';
import '../domain/appointment_models.dart';

/// Unified Appointment Repository backed strictly by [BmsHttpClient].
class AppointmentRepository {
  final BmsHttpClient _http;

  AppointmentRepository({BmsHttpClient? http})
    : _http = http ?? const BmsHttpClient();

  static String? currentPatientId() {
    final u = BmsAuth.user;
    if (u == null) return null;
    return (u['patientId'] ??
            u['PatientId'] ??
            u['patient_id'] ??
            u['id'] ??
            u['userId'] ??
            u['UserId'])
        ?.toString();
  }

  Future<BookAppointmentResponse> bookAppointment(
    BookAppointmentRequest request,
  ) async {
    if (!BmsAuth.isLoggedIn) {
      throw AppointmentException('Vui lòng đăng nhập trước khi đặt lịch.');
    }

    final res = await _http.post('/api/appointments', body: request.toJson());
    if (res.isSuccess) {
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : res.bodyAsMap;
      return BookAppointmentResponse.fromJson(data);
    }

    throw AppointmentException(
      res.extractMessage('Đặt lịch hẹn thất bại (${res.statusCode}).'),
      code: res.bodyAsMap['code']?.toString(),
    );
  }

  Future<AvailableSlotsResponse> getAvailableSlots(
    String doctorId,
    String date,
  ) async {
    final res = await _http.get(
      '/api/appointments/slots',
      query: {'doctorId': doctorId, 'date': date},
    );
    if (res.isSuccess) {
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : res.bodyAsMap;
      return AvailableSlotsResponse.fromJson(data);
    }
    throw AppointmentException(
      res.extractMessage('Không thể tải khung giờ khám.'),
    );
  }

  Future<List<DoctorOption>> getAvailableDoctors(
    String date, {
    String? specialty,
  }) async {
    final res = await _http.get(
      '/api/appointments/doctors',
      query: {
        'date': date,
        if (specialty != null && specialty.isNotEmpty) 'specialty': specialty,
      },
    );
    if (res.isSuccess) {
      return res.bodyAsList
          .whereType<Map>()
          .map((e) => DoctorOption.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw AppointmentException(
      res.extractMessage('Không thể tải danh sách bác sĩ trực.'),
    );
  }

  Future<Map<String, dynamic>> getAppointmentConfirmation(
    String appointmentIdOrCode,
  ) async {
    final res = await _http.get(
      '/api/appointments/${Uri.encodeComponent(appointmentIdOrCode)}/confirmation',
    );
    if (res.isSuccess) {
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
    }
    throw AppointmentException(
      res.extractMessage('Không thể tải phiếu xác nhận lịch hẹn.'),
    );
  }
}

class AppointmentException implements Exception {
  final String message;
  final String? code;

  AppointmentException(this.message, {this.code});

  @override
  String toString() => message;
}
