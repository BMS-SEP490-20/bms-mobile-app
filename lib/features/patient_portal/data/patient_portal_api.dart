import '../../../core/network/bms_http_client.dart';
import '../../../services/bms_auth.dart';

/// Real-API client for Patient mobile portal endpoints.
class PatientPortalApi {
  final BmsHttpClient _http;

  const PatientPortalApi({BmsHttpClient? http})
    : _http = http ?? const BmsHttpClient();

  List<Map<String, dynamic>> _toMapList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (raw is Map<String, dynamic>) {
      final nested = raw['items'] ?? raw['Items'] ?? raw['data'];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return const [];
  }

  /// `GET /api/users/me`
  Future<Map<String, dynamic>?> getUserProfile() async {
    final res = await _http.get('/api/users/me');
    if (!res.isSuccess) return null;
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  /// `GET /api/patients/me` — returns null when 404 (incomplete medical profile).
  Future<Map<String, dynamic>?> getMedicalProfile() async {
    final res = await _http.get('/api/patients/me');
    if (res.statusCode == 404) return null;
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tải hồ sơ y tế bệnh nhân.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return res.bodyAsMap.isNotEmpty ? res.bodyAsMap : null;
  }

  /// `PUT /api/patients/me`
  Future<Map<String, dynamic>> updateMedicalProfile(
    Map<String, dynamic> payload,
  ) async {
    final res = await _http.put('/api/patients/me', body: payload);
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể cập nhật hồ sơ y tế.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `PUT /api/users/{id}` — sends ONLY `{fullName, email, phoneNumber}`.
  Future<void> updateAccountContact({
    required String userId,
    required String fullName,
    required String email,
    String? phoneNumber,
  }) async {
    final res = await _http.put(
      '/api/users/$userId',
      body: {
        'fullName': fullName.trim(),
        'email': email.trim(),
        if (phoneNumber != null) 'phoneNumber': phoneNumber.trim(),
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể cập nhật thông tin liên hệ.'),
        statusCode: res.statusCode,
      );
    }
  }

  /// `GET /api/dashboard/stats`
  Future<Map<String, dynamic>> getDashboardStats() async {
    final res = await _http.get('/api/dashboard/stats');
    if (!res.isSuccess) return {};
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/appointments`
  Future<List<Map<String, dynamic>>> getAppointments({
    int page = 1,
    int pageSize = 30,
    String? status,
  }) async {
    final res = await _http.get(
      '/api/appointments',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tải danh sách lịch hẹn.'),
        statusCode: res.statusCode,
      );
    }
    return _toMapList(res.data);
  }

  /// `GET /api/appointments/{id}/confirmation`
  Future<Map<String, dynamic>> getAppointmentConfirmation(
    String appointmentIdOrCode,
  ) async {
    final res = await _http.get(
      '/api/appointments/${Uri.encodeComponent(appointmentIdOrCode)}/confirmation',
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tải phiếu xác nhận QR lịch hẹn.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/appointments/doctors`
  Future<List<Map<String, dynamic>>> getAvailableDoctors(
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
    if (!res.isSuccess) return const [];
    return _toMapList(res.body);
  }

  /// `GET /api/appointments/slots`
  Future<List<Map<String, dynamic>>> getAvailableSlots({
    required String doctorId,
    required String date,
  }) async {
    final res = await _http.get(
      '/api/appointments/slots',
      query: {'doctorId': doctorId, 'date': date},
    );
    if (!res.isSuccess) return const [];
    final map = res.bodyAsMap;
    return _toMapList(map['slots'] ?? res.data);
  }

  /// `POST /api/appointments`
  Future<Map<String, dynamic>> bookAppointment({
    required String patientId,
    required String doctorId,
    required String appointmentDate,
    required String slotTime,
    required List<String> packageIds,
    String type = 'ClinicVisit',
    String? collectionAddress,
    String? notes,
  }) async {
    final res = await _http.post(
      '/api/appointments',
      body: {
        'patientId': patientId,
        'doctorId': doctorId,
        'appointmentDate': appointmentDate,
        'slotTime': slotTime,
        'packageIds': packageIds,
        'type': type,
        if (collectionAddress != null && collectionAddress.trim().isNotEmpty)
          'collectionAddress': collectionAddress.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Đặt lịch hẹn thất bại.'),
        statusCode: res.statusCode,
      );
    }
    return res.bodyAsMap;
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

  /// `GET /api/v1/test-packages/search`
  Future<List<Map<String, dynamic>>> searchTestPackages({
    String? keyword,
    String? category,
    int page = 1,
    int pageSize = 50,
  }) async {
    final res = await _http.get(
      '/api/v1/test-packages/search',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        'isActive': 'true',
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
      },
    );
    if (!res.isSuccess) return const [];
    return _toMapList(res.body);
  }

  /// `GET /api/tracking/patient/{patientId}`
  Future<List<Map<String, dynamic>>> getPatientTrackings(
    String patientId,
  ) async {
    if (patientId.trim().isEmpty) return const [];
    final res = await _http.get(
      '/api/tracking/patient/${Uri.encodeComponent(patientId.trim())}',
    );
    if (!res.isSuccess) return const [];
    return _toMapList(res.data);
  }

  /// `GET /api/tracking/{identifier}`
  Future<Map<String, dynamic>> lookupTrackingByCode(String identifier) async {
    final res = await _http.get(
      '/api/tracking/${Uri.encodeComponent(identifier.trim())}',
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không tìm thấy tiến trình mẫu cho mã này.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/test-results/patient/{patientId}`
  Future<List<Map<String, dynamic>>> getReleasedResults(
    String patientId,
  ) async {
    if (patientId.trim().isEmpty) return const [];
    final res = await _http.get(
      '/api/test-results/patient/${Uri.encodeComponent(patientId.trim())}',
    );
    if (!res.isSuccess) return const [];
    return _toMapList(res.data);
  }

  /// `GET /api/test-results/patient/order/{orderId}`
  Future<Map<String, dynamic>> getOrderResultDetail(String orderId) async {
    final res = await _http.get(
      '/api/test-results/patient/order/${Uri.encodeComponent(orderId.trim())}',
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không tìm thấy chi tiết phiếu kết quả.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/test-results/patient/order/{orderId}/export-pdf`
  Future<Map<String, dynamic>> exportOrderResultPdf(String orderId) async {
    final res = await _http.get(
      '/api/test-results/patient/order/${Uri.encodeComponent(orderId.trim())}/export-pdf',
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể xuất bản PDF cho phiếu kết quả này.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `POST /api/test-results/patient/order/{orderId}/share`
  Future<Map<String, dynamic>> shareOrderResult(String orderId) async {
    final res = await _http.post(
      '/api/test-results/patient/order/${Uri.encodeComponent(orderId.trim())}/share',
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tạo liên kết chia sẻ bảo mật.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/invoices`
  Future<List<Map<String, dynamic>>> getInvoices({
    int page = 1,
    int pageSize = 30,
    String? status,
  }) async {
    final res = await _http.get(
      '/api/invoices',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tải danh sách hóa đơn viện phí.'),
        statusCode: res.statusCode,
      );
    }
    return _toMapList(res.data);
  }

  /// `GET /api/payments/checkout/{invoiceId}`
  Future<Map<String, dynamic>?> getCheckoutSummary(String invoiceId) async {
    final res = await _http.get(
      '/api/payments/checkout/${Uri.encodeComponent(invoiceId)}',
    );
    if (!res.isSuccess) return null;
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/payments/sepay/checkout/{appointmentId}` — gracefully reports 503 when SePay env is unconfigured.
  Future<({Map<String, dynamic>? checkout, String? unavailableReason})>
  getSePayCheckout(String appointmentId) async {
    final res = await _http.get(
      '/api/payments/sepay/checkout/${Uri.encodeComponent(appointmentId)}',
    );
    if (res.isSuccess) {
      final data = res.data;
      return (
        checkout: data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap,
        unavailableReason: null,
      );
    }
    if (res.statusCode == 503) {
      return (
        checkout: null,
        unavailableReason: res.extractMessage(
          'Cổng chuyển khoản SePay hiện chưa cấu hình tài khoản ngân hàng trên máy chủ.',
        ),
      );
    }
    return (
      checkout: null,
      unavailableReason: res.extractMessage(
        'Không thể khởi tạo mã QR chuyển khoản lúc này.',
      ),
    );
  }

  /// `POST /api/payments/process`
  Future<Map<String, dynamic>> processSePayPayment(String invoiceId) async {
    final res = await _http.post(
      '/api/payments/process',
      body: {
        'invoiceId': invoiceId,
        'paymentMethod': 'SePay',
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Xử lý thanh toán không thành công.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/notifications/test-results/patient/{patientId}/unread-count`
  Future<int> getUnreadResultNotificationCount(String patientId) async {
    if (patientId.trim().isEmpty) return 0;
    final res = await _http.get(
      '/api/notifications/test-results/patient/${Uri.encodeComponent(patientId.trim())}/unread-count',
    );
    if (!res.isSuccess) return 0;
    final data = res.data;
    if (data is num) return data.toInt();
    return int.tryParse(data?.toString() ?? '') ?? 0;
  }

  /// Fetches and combines all 3 notification feeds for the signed-in patient.
  Future<List<Map<String, dynamic>>> getCombinedNotifications({
    required String patientId,
  }) async {
    final userId = BmsAuth.currentUserId;
    final merged = <Map<String, dynamic>>[];

    // 1. Test result notifications
    if (patientId.isNotEmpty) {
      try {
        final res = await _http.get(
          '/api/notifications/test-results/patient/${Uri.encodeComponent(patientId)}',
        );
        if (res.isSuccess) {
          for (final item in _toMapList(res.data)) {
            merged.add({
              'id': (item['notificationId'] ?? item['id'] ?? '').toString(),
              'source': 'test_result',
              'title': (item['title'] ?? 'Thông báo kết quả xét nghiệm')
                  .toString(),
              'message': (item['message'] ?? '').toString(),
              'createdAt':
                  (item['sentAt'] ?? item['createdAt'] ?? '').toString(),
              'isRead':
                  (item['status'] ?? '').toString().toLowerCase() == 'read' ||
                  item['readAt'] != null,
              'isPanic': item['isCriticalPanicValue'] == true,
              'orderId': (item['testOrderId'] ?? '').toString(),
              'raw': item,
            });
          }
        }
      } catch (_) {}
    }

    // 2. Appointment notifications
    try {
      final res = await _http.get('/api/notifications/appointments');
      if (res.isSuccess) {
        for (final item in _toMapList(res.data)) {
          merged.add({
            'id': (item['id'] ?? item['notificationId'] ?? '').toString(),
            'source': 'appointment',
            'title': (item['title'] ?? 'Nhắc lịch hẹn khám').toString(),
            'message': (item['message'] ?? item['content'] ?? '').toString(),
            'createdAt': (item['sentAt'] ?? item['createdAt'] ?? '').toString(),
            'isRead': item['isRead'] == true,
            'isPanic': false,
            'appointmentId': (item['appointmentId'] ?? '').toString(),
            'raw': item,
          });
        }
      }
    } catch (_) {}

    // 3. System / push inbox notifications
    if (userId.isNotEmpty) {
      try {
        final res = await _http.get(
          '/api/v1/notifications/user/${Uri.encodeComponent(userId)}',
        );
        if (res.isSuccess) {
          for (final item in _toMapList(res.data)) {
            merged.add({
              'id': (item['id'] ?? item['notificationId'] ?? '').toString(),
              'source': 'user',
              'title': (item['title'] ?? 'Thông báo hệ thống').toString(),
              'message': (item['message'] ?? item['body'] ?? '').toString(),
              'createdAt':
                  (item['createdAt'] ?? item['sentAt'] ?? '').toString(),
              'isRead':
                  item['isRead'] == true ||
                  (item['status'] ?? '').toString().toLowerCase() == 'read',
              'isPanic':
                  (item['priority'] ?? '').toString().toLowerCase() ==
                  'critical',
              'raw': item,
            });
          }
        }
      } catch (_) {}
    }

    merged.sort((a, b) {
      final da = DateTime.tryParse(a['createdAt']?.toString() ?? '');
      final db = DateTime.tryParse(b['createdAt']?.toString() ?? '');
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    return merged;
  }

  /// Marks a single notification item as read according to its feed source.
  Future<void> markNotificationRead({
    required String id,
    required String source,
  }) async {
    if (id.trim().isEmpty) return;
    final encoded = Uri.encodeComponent(id.trim());
    switch (source) {
      case 'test_result':
        await _http.put('/api/notifications/test-results/$encoded/read');
        break;
      case 'appointment':
        await _http.put('/api/notifications/$encoded/read');
        break;
      case 'user':
      default:
        await _http.patch('/api/v1/notifications/$encoded/read');
        break;
    }
  }

  /// Marks all user push notifications read.
  Future<void> markAllUserNotificationsRead(String userId) async {
    if (userId.trim().isEmpty) return;
    await _http.patch(
      '/api/v1/notifications/user/${Uri.encodeComponent(userId.trim())}/read-all',
    );
  }
}
