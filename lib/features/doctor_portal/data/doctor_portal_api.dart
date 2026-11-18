import '../../../core/network/bms_http_client.dart';

/// Real-API client for Doctor clinical mobile workstation endpoints.
class DoctorPortalApi {
  final BmsHttpClient _http;

  const DoctorPortalApi({BmsHttpClient? http})
    : _http = http ?? const BmsHttpClient();

  List<Map<String, dynamic>> _toMapList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final nested = map['items'] ?? map['Items'] ?? map['data'];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (nested is Map) {
        final inner = Map<String, dynamic>.from(nested);
        final innerItems = inner['items'] ?? inner['Items'];
        if (innerItems is List) {
          return innerItems
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return const [];
  }

  /// `GET /api/dashboard/stats`
  Future<Map<String, dynamic>> getDashboardStats() async {
    final res = await _http.get('/api/dashboard/stats');
    if (!res.isSuccess) return {};
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/users/me`
  Future<Map<String, dynamic>?> getStaffProfile() async {
    final res = await _http.get('/api/users/me');
    if (!res.isSuccess) return null;
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/view-shifts`
  Future<List<Map<String, dynamic>>> getShifts({
    String? from,
    String? to,
    String? doctorId,
  }) async {
    final res = await _http.get(
      '/api/view-shifts',
      query: {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (doctorId != null && doctorId.isNotEmpty) 'doctorId': doctorId,
        'pageSize': '100',
      },
    );
    if (!res.isSuccess) return const [];
    return _toMapList(res.body);
  }

  /// `GET /api/appointments`
  Future<List<Map<String, dynamic>>> getAppointments({
    String? doctorId,
    String? fromDate,
    String? toDate,
    String? status,
    int page = 1,
    int pageSize = 40,
  }) async {
    final res = await _http.get(
      '/api/appointments',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        if (doctorId != null && doctorId.isNotEmpty) 'doctorId': doctorId,
        if (fromDate != null && fromDate.isNotEmpty) 'fromDate': fromDate,
        if (toDate != null && toDate.isNotEmpty) 'toDate': toDate,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    if (!res.isSuccess) return const [];
    return _toMapList(res.data);
  }

  /// `PUT /api/appointments/{id}`
  Future<void> updateAppointment(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _http.put(
      '/api/appointments/${Uri.encodeComponent(id)}',
      body: payload,
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể cập nhật lịch hẹn.'),
        statusCode: res.statusCode,
      );
    }
  }

  /// `GET /api/shifts/rooms` — returns clinic consultation rooms with standard fallback IDs.
  Future<List<Map<String, dynamic>>> getConsultationRooms() async {
    try {
      final res = await _http.get('/api/shifts/rooms');
      if (res.isSuccess) {
        final all = _toMapList(res.data);
        final clinicRooms = all
            .where(
              (r) =>
                  (r['type'] ?? 'Clinic').toString().toLowerCase() ==
                      'clinic' ||
                  (r['id'] ?? '').toString().startsWith('ROOM-'),
            )
            .toList();
        if (clinicRooms.isNotEmpty) return clinicRooms;
        if (all.isNotEmpty) return all;
      }
    } catch (_) {}
    return const [
      {'id': 'ROOM-101', 'name': 'Phòng khám 101', 'roomNumber': '101'},
      {'id': 'ROOM-102', 'name': 'Phòng khám 102', 'roomNumber': '102'},
      {'id': 'ROOM-103', 'name': 'Phòng khám 103', 'roomNumber': '103'},
    ];
  }

  /// `GET /api/reception/queue-status`
  Future<Map<String, dynamic>> getRoomQueueStatus({
    required String roomId,
    required String doctorId,
  }) async {
    final res = await _http.get(
      '/api/reception/queue-status',
      query: {'roomId': roomId, 'doctorId': doctorId},
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tải hàng đợi bàn khám.'),
        statusCode: res.statusCode,
      );
    }
    return res.bodyAsMap;
  }

  /// `POST /api/reception/call-next`
  Future<Map<String, dynamic>> callNextPatient({
    required String roomId,
    required String doctorId,
  }) async {
    final res = await _http.post(
      '/api/reception/call-next',
      body: {'roomId': roomId, 'doctorId': doctorId},
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể gọi bệnh nhân tiếp theo.'),
        statusCode: res.statusCode,
      );
    }
    return res.bodyAsMap;
  }

  /// `POST /api/reception/recall`
  Future<String> recallPatient({
    required String appointmentId,
    required String roomId,
  }) async {
    final res = await _http.post(
      '/api/reception/recall',
      body: {'appointmentId': appointmentId, 'roomId': roomId},
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể gọi lại bệnh nhân.'),
        statusCode: res.statusCode,
      );
    }
    return res.extractMessage('Đã phát lại thông báo gọi số.');
  }

  /// `POST /api/reception/skip`
  Future<String> skipPatient({
    required String appointmentId,
    String? reason,
  }) async {
    final res = await _http.post(
      '/api/reception/skip',
      body: {
        'appointmentId': appointmentId,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể đánh dấu vắng mặt.'),
        statusCode: res.statusCode,
      );
    }
    return res.extractMessage('Đã đánh dấu vắng mặt.');
  }

  /// `POST /api/reception/complete`
  Future<String> completeConsultation({
    required String appointmentId,
    String? notes,
  }) async {
    final res = await _http.post(
      '/api/reception/complete',
      body: {
        'appointmentId': appointmentId,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể hoàn tất lượt khám.'),
        statusCode: res.statusCode,
      );
    }
    return res.extractMessage('Đã hoàn tất lượt khám.');
  }

  /// `GET /api/patients`
  Future<List<Map<String, dynamic>>> searchPatients({
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _http.get(
      '/api/patients',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        if (search != null && search.trim().isNotEmpty)
          'search': search.trim(),
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tìm kiếm bệnh nhân.'),
        statusCode: res.statusCode,
      );
    }
    return _toMapList(res.body);
  }

  /// `GET /api/patients/{id}`
  Future<Map<String, dynamic>?> getPatientDetail(String patientId) async {
    final res = await _http.get(
      '/api/patients/${Uri.encodeComponent(patientId.trim())}',
    );
    if (!res.isSuccess) return null;
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/medical-records/patient/{patientId}`
  Future<List<Map<String, dynamic>>> getPatientMedicalRecords(
    String patientId,
  ) async {
    final res = await _http.get(
      '/api/medical-records/patient/${Uri.encodeComponent(patientId.trim())}',
    );
    if (!res.isSuccess) return const [];
    return _toMapList(res.data);
  }

  /// `POST /api/medical-records`
  Future<Map<String, dynamic>> createMedicalRecord(
    Map<String, dynamic> payload,
  ) async {
    final res = await _http.post('/api/medical-records', body: payload);
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tạo bệnh án điện tử.'),
        statusCode: res.statusCode,
      );
    }
    return res.bodyAsMap;
  }

  /// `PUT /api/medical-records/{id}`
  Future<Map<String, dynamic>> updateMedicalRecord(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _http.put(
      '/api/medical-records/${Uri.encodeComponent(id)}',
      body: payload,
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể cập nhật bệnh án.'),
        statusCode: res.statusCode,
      );
    }
    return res.bodyAsMap;
  }

  /// `GET /api/medical-assessments/patient/{patientId}`
  Future<List<Map<String, dynamic>>> getPatientAssessments(
    String patientId,
  ) async {
    final res = await _http.get(
      '/api/medical-assessments/patient/${Uri.encodeComponent(patientId.trim())}',
    );
    if (!res.isSuccess) return const [];
    return _toMapList(res.data);
  }

  /// `POST /api/medical-assessments`
  Future<Map<String, dynamic>> createMedicalAssessment(
    Map<String, dynamic> payload,
  ) async {
    final res = await _http.post('/api/medical-assessments', body: payload);
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể lưu chẩn đoán lâm sàng.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `PATCH /api/medical-assessments/{id}/finalize`
  Future<void> finalizeAssessment(String id, {String? finalNotes}) async {
    final res = await _http.patch(
      '/api/medical-assessments/${Uri.encodeComponent(id)}/finalize',
      body: {
        if (finalNotes != null && finalNotes.trim().isNotEmpty)
          'finalNotes': finalNotes.trim(),
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể khóa hồ sơ chẩn đoán.'),
        statusCode: res.statusCode,
      );
    }
  }

  /// `GET /api/testorders`
  Future<List<Map<String, dynamic>>> getTestOrders({
    String? patientId,
    String? doctorId,
    String? status,
  }) async {
    final res = await _http.get(
      '/api/testorders',
      query: {
        if (patientId != null && patientId.isNotEmpty) 'patientId': patientId,
        if (doctorId != null && doctorId.isNotEmpty) 'doctorId': doctorId,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    if (!res.isSuccess) return const [];
    return _toMapList(res.data);
  }

  /// `GET /api/v1/test-packages/search`
  Future<List<Map<String, dynamic>>> searchTestPackages({
    String? keyword,
    int pageSize = 50,
  }) async {
    final res = await _http.get(
      '/api/v1/test-packages/search',
      query: {
        'page': '1',
        'pageSize': '$pageSize',
        'isActive': 'true',
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
      },
    );
    if (!res.isSuccess) return const [];
    return _toMapList(res.body);
  }

  /// `POST /api/testorders`
  Future<Map<String, dynamic>> createTestOrder(
    Map<String, dynamic> payload,
  ) async {
    final res = await _http.post('/api/testorders', body: payload);
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tạo phiếu chỉ định xét nghiệm.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `PUT /api/testorders/{id}/status`
  Future<void> cancelTestOrder(String id, {String? notes}) async {
    final res = await _http.put(
      '/api/testorders/${Uri.encodeComponent(id)}/status',
      body: {
        'status': 'Cancelled',
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể hủy phiếu chỉ định xét nghiệm.'),
        statusCode: res.statusCode,
      );
    }
  }

  /// `GET /api/test-results` — handles `data` being either a single `Map` or a `List`!
  Future<List<Map<String, dynamic>>> searchBiochemicalResults({
    String? search,
  }) async {
    final res = await _http.get(
      '/api/test-results',
      query: {
        if (search != null && search.trim().isNotEmpty)
          'search': search.trim(),
      },
    );
    if (res.statusCode == 404) return const [];
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tra cứu kết quả sinh hóa.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      return [Map<String, dynamic>.from(data)];
    }
    return const [];
  }

  /// `GET /api/test-results/{id}`
  Future<Map<String, dynamic>> getBiochemicalResultDetail(String id) async {
    final res = await _http.get(
      '/api/test-results/${Uri.encodeComponent(id.trim())}',
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tải chi tiết kết quả sinh hóa.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/laboratory/criteria`
  Future<List<Map<String, dynamic>>> getLabCriteria({
    String? search,
    String? category,
    int page = 1,
    int pageSize = 40,
  }) async {
    final res = await _http.get(
      '/api/laboratory/criteria',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        if (search != null && search.trim().isNotEmpty)
          'search': search.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
      },
    );
    if (!res.isSuccess) return const [];
    return _toMapList(res.data);
  }

  /// `GET /api/reference-intervals/criterion/{code}`
  Future<List<Map<String, dynamic>>> getCriterionIntervals(String code) async {
    final res = await _http.get(
      '/api/reference-intervals/criterion/${Uri.encodeComponent(code.trim())}',
    );
    if (!res.isSuccess) return const [];
    return _toMapList(res.data);
  }

  /// `POST /api/reference-intervals/evaluate`
  Future<Map<String, dynamic>> evaluateCriterionValue({
    required String criterionCode,
    required double numericValue,
    required double patientAge,
    required String patientGender,
  }) async {
    final res = await _http.post(
      '/api/reference-intervals/evaluate',
      body: {
        'criterionCode': criterionCode.trim().toUpperCase(),
        'numericValue': numericValue,
        'patientAge': patientAge,
        'patientAgeUnit': 'Years',
        'patientGender': patientGender,
        'condition': 'General',
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể đánh giá chỉ số theo dải tham chiếu.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }
}
