import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/doctor_schedule_model.dart';
import 'package:bms_mobile_app/services/bms_auth.dart';

/// Repository for UC16 – View Doctor Schedule API.
class ScheduleRepository {
  final String baseUrl;
  final http.Client _client;

  ScheduleRepository({
    this.baseUrl = const String.fromEnvironment(
      'BMS_API_BASE_URL',
      defaultValue: 'http://10.0.2.2:5000',
    ),
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Fetches the day-view doctor schedule.
  Future<DoctorScheduleResponse> getDaySchedule({
    String? date,
    String? doctorId,
    String? search,
  }) async {
    final query = <String, String>{};
    if (date != null && date.isNotEmpty) query['date'] = date;
    if (doctorId != null && doctorId.isNotEmpty) query['doctorId'] = doctorId;
    if (search != null && search.isNotEmpty) query['search'] = search;

    final uri = Uri.parse(
      '$baseUrl/api/v1/schedules/doctors',
    ).replace(queryParameters: query.isEmpty ? null : query);

    try {
      final token = BmsAuth.accessToken;
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode != 200) {
        throw ScheduleException(
          'Failed to load schedule (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return DoctorScheduleResponse.fromJson(json);
    } on ScheduleException {
      rethrow;
    } catch (e) {
      throw ScheduleException('Connection error: $e');
    }
  }

  void dispose() => _client.close();
}

/// Exception for the schedule module.
class ScheduleException implements Exception {
  final String message;
  final int? statusCode;
  ScheduleException(this.message, {this.statusCode});
  @override
  String toString() => message;
}
