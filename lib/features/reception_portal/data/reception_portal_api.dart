import '../../../core/network/bms_http_client.dart';

/// Real-API client for Receptionist mobile portal endpoints.
class ReceptionPortalApi {
  final BmsHttpClient _http;

  const ReceptionPortalApi({BmsHttpClient? http})
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

  /// `GET /api/appointments`
  Future<List<Map<String, dynamic>>> getAppointments({
    String? fromDate,
    String? toDate,
    String? keyword,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    final res = await _http.get(
      '/api/appointments',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        if (fromDate != null && fromDate.isNotEmpty) 'fromDate': fromDate,
        if (toDate != null && toDate.isNotEmpty) 'toDate': toDate,
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
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

  /// `GET /api/appointments/{codeOrId}`
  Future<Map<String, dynamic>> getAppointmentByCodeOrId(String codeOrId) async {
    final res = await _http.get(
      '/api/appointments/${Uri.encodeComponent(codeOrId.trim())}',
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không tìm thấy lịch hẹn với mã "$codeOrId".'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `PUT /api/appointments/{id}` — Check-in or update appointment.
  Future<void> checkInAppointment(
    String appointmentId, {
    String notes = 'Check-in QR trên ứng dụng Lễ tân',
  }) async {
    final res = await _http.put(
      '/api/appointments/${Uri.encodeComponent(appointmentId.trim())}',
      body: {
        'status': 'CheckedIn',
        'notes': notes,
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể xác nhận check-in lịch hẹn.'),
        statusCode: res.statusCode,
      );
    }
  }

  /// `POST /api/appointments` — Book appointment on behalf of patient.
  Future<Map<String, dynamic>> bookAppointmentForPatient({
    required String patientId,
    required String doctorId,
    required String appointmentDate,
    required String slotTime,
    required List<String> packageIds,
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
        'type': 'ClinicVisit',
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể đặt lịch khám hộ bệnh nhân.'),
        statusCode: res.statusCode,
      );
    }
    return res.bodyAsMap;
  }

  /// `GET /api/appointments/doctors`
  Future<List<Map<String, dynamic>>> getAvailableDoctors(String date) async {
    final res = await _http.get(
      '/api/appointments/doctors',
      query: {'date': date},
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

  /// `GET /api/walk-in/lookup/identity/{cccd}`
  Future<Map<String, dynamic>?> lookupWalkInByIdentity(String cccd) async {
    final res = await _http.get(
      '/api/walk-in/lookup/identity/${Uri.encodeComponent(cccd.trim())}',
    );
    if (!res.isSuccess) return null;
    return res.bodyAsMap;
  }

  /// `GET /api/walk-in/lookup/phone/{phone}`
  Future<Map<String, dynamic>?> lookupWalkInByPhone(String phone) async {
    final res = await _http.get(
      '/api/walk-in/lookup/phone/${Uri.encodeComponent(phone.trim())}',
    );
    if (!res.isSuccess) return null;
    return res.bodyAsMap;
  }

  /// `POST /api/walk-in/register` (or `POST /api/patients/guests` when CCCD is omitted).
  Future<Map<String, dynamic>> registerWalkInPatient({
    required String fullName,
    required DateTime dateOfBirth,
    required String gender,
    required String phone,
    String? identityNumber,
    String? email,
    String? address,
    String? bloodType,
    String priority = 'NORMAL',
  }) async {
    final trimmedId = identityNumber?.trim() ?? '';
    if (trimmedId.length == 12) {
      final res = await _http.post(
        '/api/walk-in/register',
        body: {
          'fullName': fullName.trim(),
          'dateOfBirth': dateOfBirth.toUtc().toIso8601String(),
          'gender': gender,
          'phone': phone.trim(),
          'identityNumber': trimmedId,
          'priority': priority,
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          if (address != null && address.trim().isNotEmpty)
            'address': address.trim(),
          if (bloodType != null && bloodType.trim().isNotEmpty)
            'bloodType': bloodType.trim(),
        },
      );
      if (!res.isSuccess) {
        throw BmsApiException(
          res.extractMessage('Không thể đăng ký khách vãng lai.'),
          statusCode: res.statusCode,
        );
      }
      return res.bodyAsMap;
    }

    final res = await _http.post(
      '/api/patients/guests',
      body: {
        'fullName': fullName.trim(),
        'dateOfBirth': dateOfBirth.toUtc().toIso8601String(),
        'gender': gender,
        'phoneNumber': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
        if (bloodType != null && bloodType.trim().isNotEmpty)
          'bloodType': bloodType.trim(),
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tạo hồ sơ khách vãng lai.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/patients`
  Future<List<Map<String, dynamic>>> searchPatients({
    String? search,
    bool? isGuest,
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
        if (isGuest != null) 'isGuest': isGuest.toString(),
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tra cứu danh mục bệnh nhân.'),
        statusCode: res.statusCode,
      );
    }
    return _toMapList(res.body);
  }

  /// `GET /api/patients/{id}`
  Future<Map<String, dynamic>> getPatientById(String id) async {
    final res = await _http.get(
      '/api/patients/${Uri.encodeComponent(id.trim())}',
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tải chi tiết hồ sơ bệnh nhân.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/reception/queue`
  Future<Map<String, dynamic>> getLiveQueueBoard() async {
    final res = await _http.get('/api/reception/queue');
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tải bảng hàng đợi trực tuyến.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `POST /api/reception/queue/issue`
  Future<Map<String, dynamic>> issueQueueTicket({
    String? patientId,
    required String patientName,
    String? patientCode,
    String? packageName,
    bool isWalkIn = true,
    String priority = 'Routine',
  }) async {
    final res = await _http.post(
      '/api/reception/queue/issue',
      body: {
        if (patientId != null && patientId.isNotEmpty) 'patientId': patientId,
        'patientName': patientName.trim(),
        if (patientCode != null && patientCode.isNotEmpty)
          'patientCode': patientCode,
        if (packageName != null && packageName.isNotEmpty)
          'packageName': packageName,
        'isWalkIn': isWalkIn,
        'priority': priority,
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể cấp số thứ tự mới.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `POST /api/reception/queue/call-next`
  Future<Map<String, dynamic>?> callNextQueueTicket(String counterName) async {
    final res = await _http.post(
      '/api/reception/queue/call-next',
      body: {'counterName': counterName},
    );
    if (res.statusCode == 204) return null;
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể gọi số tiếp theo.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `PUT /api/reception/queue/{id}/call`
  Future<void> callTicketToCounter(String id, String counterName) async {
    final res = await _http.put(
      '/api/reception/queue/${Uri.encodeComponent(id)}/call',
      body: {'counterName': counterName},
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể gọi số vào quầy.'),
        statusCode: res.statusCode,
      );
    }
  }

  /// `PUT /api/reception/queue/{id}/status`
  Future<void> updateQueueTicketStatus(
    String id, {
    required String status,
    String? counterName,
  }) async {
    final res = await _http.put(
      '/api/reception/queue/${Uri.encodeComponent(id)}/status',
      body: {
        'status': status,
        if (counterName != null && counterName.isNotEmpty)
          'counterName': counterName,
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể cập nhật trạng thái phiếu thứ tự.'),
        statusCode: res.statusCode,
      );
    }
  }

  /// `GET /api/invoices`
  Future<List<Map<String, dynamic>>> getInvoices({
    String? status,
    int page = 1,
    int pageSize = 30,
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
        res.extractMessage('Không thể tải sổ hóa đơn viện phí.'),
        statusCode: res.statusCode,
      );
    }
    return _toMapList(res.data);
  }

  /// `POST /api/invoices`
  Future<Map<String, dynamic>> createInvoice({
    required String patientId,
    required String patientName,
    String? patientPhone,
    String? appointmentId,
    required List<Map<String, dynamic>> items,
    double discountAmount = 0,
  }) async {
    final res = await _http.post(
      '/api/invoices',
      body: {
        'patientId': patientId,
        'patientName': patientName,
        if (patientPhone != null && patientPhone.isNotEmpty)
          'patientPhone': patientPhone,
        if (appointmentId != null && appointmentId.isNotEmpty)
          'appointmentId': appointmentId,
        'items': items,
        'discountAmount': discountAmount,
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tạo hóa đơn viện phí.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `POST /api/invoices/{id}/pay`
  Future<Map<String, dynamic>> payInvoice(
    String invoiceId, {
    required String paymentMethod,
    String? transactionReference,
  }) async {
    final res = await _http.post(
      '/api/invoices/${Uri.encodeComponent(invoiceId)}/pay',
      body: {
        'paymentMethod': paymentMethod,
        if (transactionReference != null &&
            transactionReference.trim().isNotEmpty)
          'transactionReference': transactionReference.trim(),
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể xác nhận thu viện phí.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/receipts/{invoiceId}/print-data`
  Future<Map<String, dynamic>> getReceiptPrintData(String invoiceId) async {
    final res = await _http.get(
      '/api/receipts/${Uri.encodeComponent(invoiceId)}/print-data',
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể xuất dữ liệu biên lai nhiệt K80.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
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

  /// `POST /api/billing/validate-voucher`
  Future<Map<String, dynamic>> validateVoucher({
    required String voucherCode,
    required double currentSubTotal,
    String serviceType = 'Clinic',
  }) async {
    final res = await _http.post(
      '/api/billing/validate-voucher',
      body: {
        'voucherCode': voucherCode.trim().toUpperCase(),
        'currentSubTotal': currentSubTotal,
        'serviceType': serviceType,
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể kiểm tra mã ưu đãi.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `POST /api/billing/calculate-fee`
  Future<Map<String, dynamic>> calculateFee({
    required List<String> packageIds,
    String serviceType = 'Clinic',
    String? insuranceCardNumber,
    String? voucherCode,
    bool isPriorityPatient = false,
  }) async {
    final res = await _http.post(
      '/api/billing/calculate-fee',
      body: {
        'packageIds': packageIds,
        'serviceType': serviceType,
        if (insuranceCardNumber != null &&
            insuranceCardNumber.trim().isNotEmpty)
          'insuranceCardNumber': insuranceCardNumber.trim().toUpperCase(),
        if (voucherCode != null && voucherCode.trim().isNotEmpty)
          'voucherCode': voucherCode.trim().toUpperCase(),
        'isPriorityPatient': isPriorityPatient,
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tính dự toán chi phí BHYT.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/view-shifts`
  Future<List<Map<String, dynamic>>> getShifts({
    String? from,
    String? to,
    String? employeeId,
  }) async {
    final res = await _http.get(
      '/api/view-shifts',
      query: {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (employeeId != null && employeeId.isNotEmpty)
          'doctorId': employeeId,
        'pageSize': '100',
      },
    );
    if (!res.isSuccess) return const [];
    return _toMapList(res.body);
  }
}
