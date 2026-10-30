import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../services/bms_auth.dart';
import '../domain/appointment_models.dart';

/// Data layer for UC21 – uses [BmsAuth] for base URL + JWT.
class AppointmentRepository {
  /// Optional override; defaults to [apiBaseUrl] from bms_auth.dart.
  final String? baseUrlOverride;

  AppointmentRepository({this.baseUrlOverride});

  /// Tries localhost then Android emulator host (same order as BmsAuth login).
  List<String> get _bases {
    if (baseUrlOverride != null && baseUrlOverride!.isNotEmpty) {
      return [baseUrlOverride!];
    }
    return const [
      apiBaseUrl, // http://localhost:5000
      'http://10.0.2.2:5000',
    ];
  }

  Map<String, String> get _headers {
    final token = BmsAuth.accessToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Patient id from session (Patient role) or explicit override.
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

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    Object? lastError;
    for (final base in _bases) {
      try {
        final res = await http
            .post(
              Uri.parse('$base$path'),
              headers: _headers,
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 15));
        return res;
      } catch (e) {
        lastError = e;
      }
    }
    throw AppointmentException('Cannot reach API: $lastError');
  }

  Future<http.Response> _get(String path, [Map<String, String>? query]) async {
    Object? lastError;
    for (final base in _bases) {
      try {
        final uri = Uri.parse('$base$path').replace(queryParameters: query);
        final res = await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 15));
        return res;
      } catch (e) {
        lastError = e;
      }
    }
    throw AppointmentException('Cannot reach API: $lastError');
  }

  Future<BookAppointmentResponse> bookAppointment(
    BookAppointmentRequest request,
  ) async {
    if (!BmsAuth.isLoggedIn) {
      throw AppointmentException('Please sign in before booking.');
    }

    final res = await _post('/api/appointments', request.toJson());

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}

    if (res.statusCode == 201 || res.statusCode == 200) {
      return BookAppointmentResponse.fromJson(body ?? {});
    }

    throw AppointmentException(
      body?['message']?.toString() ?? 'Booking failed (${res.statusCode})',
      code: body?['code']?.toString(),
    );
  }

  Future<AvailableSlotsResponse> getAvailableSlots(
    String doctorId,
    String date,
  ) async {
    final res = await _get('/api/appointments/slots', {
      'doctorId': doctorId,
      'date': date,
    });

    if (res.statusCode == 200) {
      return AvailableSlotsResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw AppointmentException('Could not load available slots.');
  }

  Future<List<DoctorOption>> getAvailableDoctors(
    String date, {
    String? specialty,
  }) async {
    final params = <String, String>{'date': date};
    if (specialty != null && specialty.isNotEmpty) {
      params['specialty'] = specialty;
    }
    final res = await _get('/api/appointments/doctors', params);

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list
          .map((e) => DoctorOption.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw AppointmentException('Could not load doctors.');
  }

  /// UC22 – Retrieves appointment confirmation receipt and check-in QR payload.
  Future<Map<String, dynamic>> getAppointmentConfirmation(String appointmentIdOrCode) async {
    final res = await _get('/api/appointments/$appointmentIdOrCode/confirmation');
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : decoded;
      }
    }
    throw AppointmentException('Could not load appointment confirmation.');
  }

  /// UC22 – Triggers notification delivery (Email, Push, In-App).
  Future<bool> sendNotification(
    String appointmentId, {
    int channel = 1,
    int type = 1,
    String? customMessage,
  }) async {
    final res = await _post('/api/appointments/$appointmentId/notify', {
      'channel': channel,
      'type': type,
      'customMessage': ?customMessage,
    });
    return res.statusCode == 200;
  }
}

class AppointmentException implements Exception {
  final String message;
  final String? code;

  AppointmentException(this.message, {this.code});

  @override
  String toString() => message;
}
