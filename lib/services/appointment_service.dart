import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

class AppointmentService {
  /// Retrieves all appointments for administrative or general listing.
  static Future<Map<String, dynamic>> getAllAppointments({int page = 1, int pageSize = 50}) async {
    try {
      final response = await Api.get('/gateway/testorder/appointment?page=$page&pageSize=$pageSize');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> list = decoded['data'] ?? [];
        return {
          'success': true,
          'data': list,
          'total': decoded['total'] ?? list.length,
          'page': decoded['page'] ?? page,
        };
      } else if (response.statusCode == 404) {
        return {'success': true, 'data': [], 'total': 0};
      }
      return {'success': false, 'message': 'Không thể tải danh sách cuộc hẹn (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  /// Retrieves appointments for a specific patient.
  static Future<Map<String, dynamic>> getAppointmentsByPatient(String patientId, {int page = 1, int pageSize = 50}) async {
    try {
      final response = await Api.get('/gateway/testorder/appointment/patient/$patientId?page=$page&pageSize=$pageSize');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> list = decoded['data'] ?? [];
        return {
          'success': true,
          'data': list,
          'total': decoded['total'] ?? list.length,
        };
      } else if (response.statusCode == 404) {
        return {'success': true, 'data': [], 'total': 0};
      }
      // Fallback: fetch all and filter by patient ID if patient-specific endpoint is unavailable
      final allResp = await getAllAppointments(page: 1, pageSize: 100);
      if (allResp['success'] == true) {
        final List<dynamic> all = allResp['data'];
        final filtered = all.where((item) {
          final cb = item['createdBy']?.toString() ?? '';
          final pid = item['patientId']?.toString() ?? '';
          return cb == patientId || pid == patientId;
        }).toList();
        return {'success': true, 'data': filtered, 'total': filtered.length};
      }
      return {'success': false, 'message': 'Lỗi tải cuộc hẹn của bệnh nhân'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  /// Retrieves appointment details by ID.
  static Future<Map<String, dynamic>> getAppointmentById(String id) async {
    try {
      final response = await Api.get('/gateway/testorder/appointment/$id');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final data = decoded is Map<String, dynamic> && decoded.containsKey('data') ? decoded['data'] : decoded;
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': 'Không tìm thấy cuộc hẹn ID: $id'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  /// Creates a new test appointment from the mobile application.
  /// Feature Task: Create Appointments (Mobile).
  /// 
  /// Sends a `POST` request to `/gateway/testorder/appointment` with the [payload]
  /// containing package ID, date, time, and patient/guest details.
  /// Returns a [Map] containing operation `success`, created `data`, and response `message`.
  static Future<Map<String, dynamic>> createAppointment(Map<String, dynamic> payload) async {
    try {
      final response = await Api.post('/gateway/testorder/appointment', payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'data': decoded,
          'message': 'Đặt lịch hẹn thành công!',
        };
      }
      final err = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': false,
        'message': err['message'] ?? 'Không thể tạo cuộc hẹn (${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  /// Updates existing appointment details from the mobile application.
  /// Feature Task: Update Appointments (Mobile).
  /// 
  /// Sends a `PUT` request to `/gateway/testorder/appointment/$id` with the modified [payload],
  /// allowing date rescheduling, test package change, or status updates.
  /// Returns a [Map] indicating operation `success` and outcome `message`.
  static Future<Map<String, dynamic>> updateAppointment(String id, Map<String, dynamic> payload) async {
    try {
      final response = await Api.put('/gateway/testorder/appointment/$id', payload);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'success': true,
          'message': 'Cập nhật lịch hẹn thành công!',
        };
      }
      final err = response.body.isNotEmpty ? jsonDecode(utf8.decode(response.bodyBytes)) : null;
      return {
        'success': false,
        'message': err != null ? (err['message'] ?? 'Lỗi cập nhật lịch hẹn') : 'Không thể cập nhật cuộc hẹn (${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  /// Deletes an appointment by its unique [id] from the mobile application.
  /// Feature Task: Delete Appointments (Mobile).
  /// 
  /// Sends a `DELETE` request to `/gateway/testorder/appointment/$id`.
  /// Returns a [Map] with `success` flag and user-facing status `message`.
  static Future<Map<String, dynamic>> deleteAppointment(String id) async {
    try {
      final response = await Api.delete('/gateway/testorder/appointment/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'success': true,
          'message': 'Xóa lịch hẹn thành công!',
        };
      }
      return {
        'success': false,
        'message': 'Không thể xóa cuộc hẹn (${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  /// Performs mobile QR check-in by updating the appointment status to `checked_in`.
  /// Feature Task: Scan QR Check-in (Mobile).
  /// 
  /// First queries the appointment via [getAppointmentById] to check its current state.
  /// If valid, sends a `PUT` request to `/gateway/testorder/appointment/$id` setting
  /// status to `checked_in` and optional check-in [notes].
  /// Returns a [Map] indicating `success`, updated `data`, or `alreadyCheckedIn` flag.
  static Future<Map<String, dynamic>> checkInAppointment(String id, {String? notes}) async {
    try {
      // 1. Verify current appointment status
      final checkResp = await getAppointmentById(id);
      if (!checkResp['success']) {
        return {'success': false, 'message': 'Không tìm thấy thông tin lịch hẹn để check-in'};
      }

      final apt = checkResp['data'];
      final currentStatus = apt['status']?.toString().toLowerCase();

      if (currentStatus == 'checked_in') {
        return {
          'success': false,
          'message': 'Lịch hẹn này đã được check-in trước đó!',
          'alreadyCheckedIn': true,
          'data': apt,
        };
      }

      // 2. Send check-in PUT request
      final updateData = {
        'testPackageId': apt['testPackageId'],
        'doctorShiftId': apt['doctorShiftId'],
        'status': 'checked_in',
        'appointmentTime': apt['appointmentTime'],
        'appointmentType': apt['appointmentType'],
        'guestName': apt['guestName'],
        'guestPhone': apt['guestPhone'],
        'reasonForRescheduling': notes ?? apt['reasonForRescheduling'],
      };

      final response = await Api.put('/gateway/testorder/appointment/$id', updateData);
      if (response.statusCode == 200 || response.statusCode == 204) {
        // Fetch latest updated data
        final updated = await getAppointmentById(id);
        return {
          'success': true,
          'message': 'Check-in thành công!',
          'data': updated['success'] ? updated['data'] : apt,
        };
      }

      return {
        'success': false,
        'message': 'Lỗi khi gửi yêu cầu check-in (${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối check-in: $e'};
    }
  }

  /// Retrieves test packages for selection when creating or updating appointments.
  static Future<List<Map<String, dynamic>>> getTestPackages() async {
    try {
      final response = await Api.get('/gateway/testorder/testpackage?page=1&pageSize=50');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> list = decoded['data'] ?? [];
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Retrieves current authenticated user or patient from local storage.
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('user');
      if (userStr != null) {
        return jsonDecode(userStr);
      }
    } catch (_) {}
    return null;
  }
}
