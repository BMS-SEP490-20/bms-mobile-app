import '../../../core/network/bms_http_client.dart';
import '../../../services/bms_auth.dart';

/// Unified Real-API client for Patient (1-1 Web) & Guest endpoints.
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
      final nested =
          raw['items'] ?? raw['Items'] ?? raw['data'] ?? raw['results'];
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

  /// `GET /api/appointments`
  Future<List<Map<String, dynamic>>> getAppointments({
    int page = 1,
    int pageSize = 50,
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

  /// `PUT /api/appointments/{id}` (cancel / reschedule)
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

  /// Public / Authenticated `GET /api/tracking/{identifier}` (works for Guest too!)
  Future<Map<String, dynamic>> lookupTrackingByCode(
    String identifier, {
    bool includeAuth = true,
  }) async {
    final res = await _http.get(
      '/api/tracking/${Uri.encodeComponent(identifier.trim())}',
      includeAuth: includeAuth,
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

  /// `GET /api/test-history`
  Future<List<Map<String, dynamic>>> getTestHistory({
    String? patientId,
    int page = 1,
    int pageSize = 30,
    String? keyword,
  }) async {
    final res = await _http.get(
      '/api/test-history',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        if (patientId != null && patientId.trim().isNotEmpty)
          'patientId': patientId.trim(),
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
      },
    );
    if (!res.isSuccess) return const [];
    return _toMapList(res.data);
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

  /// `GET /api/test-results/patient/order/{orderId}` (with `/api/testresults/patient/order/{orderId}` fallback)
  Future<Map<String, dynamic>> getOrderResultDetail(String orderId) async {
    final encoded = Uri.encodeComponent(orderId.trim());
    var res = await _http.get('/api/test-results/patient/order/$encoded');
    if (!res.isSuccess) {
      final alt = await _http.get('/api/testresults/patient/order/$encoded');
      if (alt.isSuccess) res = alt;
    }
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
    final encoded = Uri.encodeComponent(orderId.trim());
    var res = await _http.get(
      '/api/test-results/patient/order/$encoded/export-pdf',
    );
    if (!res.isSuccess) {
      final alt = await _http.get(
        '/api/testresults/patient/order/$encoded/export-pdf',
      );
      if (alt.isSuccess) res = alt;
    }
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
    final encoded = Uri.encodeComponent(orderId.trim());
    var res = await _http.post(
      '/api/test-results/patient/order/$encoded/share',
    );
    if (!res.isSuccess) {
      final alt = await _http.post(
        '/api/testresults/patient/order/$encoded/share',
      );
      if (alt.isSuccess) res = alt;
    }
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
    String? patientId,
    int page = 1,
    int pageSize = 50,
    String? status,
  }) async {
    final res = await _http.get(
      '/api/invoices',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        if (patientId != null && patientId.trim().isNotEmpty)
          'patientId': patientId.trim(),
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

  /// `GET /api/payments/patient/{patientId}` — Web fallback endpoint.
  Future<List<Map<String, dynamic>>> getPaymentsByPatient(
    String patientId,
  ) async {
    if (patientId.trim().isEmpty) return const [];
    final res = await _http.get(
      '/api/payments/patient/${Uri.encodeComponent(patientId.trim())}',
    );
    if (!res.isSuccess) return const [];
    return _toMapList(res.data);
  }

  /// Unified patient billing loader (1-1 parity with Web `PatientPaymentHistoryPage.jsx`):
  /// Resolves all candidate patient identifiers (`patient.id`, `patientCode`, `accountId`,
  /// `appointment.patientId`) because `AppointmentService.BookAsync` keys auto-created
  /// invoices by Mongo `patients._id` while `/api/invoices` without `patientId` defaults
  /// to `User.AccountId()`. Also reconciles paid appointments whose invoice wasn't synced.
  Future<List<Map<String, dynamic>>> getMyBillingInvoices({
    int page = 1,
    int pageSize = 50,
  }) async {
    final initResults = await Future.wait<dynamic>([
      getMedicalProfile().catchError((_) => null),
      getAppointments(
        page: 1,
        pageSize: pageSize,
      ).catchError((_) => <Map<String, dynamic>>[]),
    ]);

    final profile = initResults[0] as Map<String, dynamic>?;
    final appointments = initResults[1] as List<Map<String, dynamic>>;

    final candidateIds = <String>[];
    void addCandidate(dynamic raw) {
      final v = (raw ?? '').toString().trim();
      if (v.isNotEmpty && !candidateIds.contains(v)) {
        candidateIds.add(v);
      }
    }

    addCandidate(profile?['id']);
    addCandidate(profile?['patientCode']);
    addCandidate(profile?['accountId']);
    addCandidate(BmsAuth.user?['patientCode']);
    addCandidate(BmsAuth.currentUserId);
    for (final appt in appointments) {
      addCandidate(appt['patientId']);
    }

    final merged = <String, Map<String, dynamic>>{};
    BmsApiException? lastError;
    var anySuccess = false;

    void absorb(List<Map<String, dynamic>> items) {
      for (final raw in items) {
        final item = Map<String, dynamic>.from(raw);
        final key =
            (item['id'] ??
                    item['invoiceId'] ??
                    item['invoiceCode'] ??
                    item['appointmentId'] ??
                    '')
                .toString()
                .trim();
        if (key.isEmpty) continue;
        final existing = merged[key];
        if (existing == null) {
          merged[key] = item;
        } else {
          final existingStatus = (existing['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          final newStatus = (item['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          final existingTerminal =
              existingStatus == 'paid' ||
              existingStatus == '1' ||
              existingStatus == 'partiallyrefunded' ||
              existingStatus == '2' ||
              existingStatus == 'refunded' ||
              existingStatus == '3' ||
              existingStatus == 'voided' ||
              existingStatus == '4';
          final newTerminal =
              newStatus == 'paid' ||
              newStatus == '1' ||
              newStatus == 'partiallyrefunded' ||
              newStatus == '2' ||
              newStatus == 'refunded' ||
              newStatus == '3' ||
              newStatus == 'voided' ||
              newStatus == '4';
          if (newTerminal && !existingTerminal) {
            merged[key] = item;
          }
        }
      }
    }

    if (candidateIds.isEmpty) {
      try {
        absorb(await getInvoices(page: page, pageSize: pageSize));
        anySuccess = true;
      } on BmsApiException catch (e) {
        lastError = e;
      }
    } else {
      await Future.wait(
        candidateIds.map((pid) async {
          try {
            final list = await getInvoices(
              patientId: pid,
              page: page,
              pageSize: pageSize,
            );
            anySuccess = true;
            if (list.isNotEmpty) {
              absorb(list);
              return;
            }
          } on BmsApiException catch (e) {
            lastError = e;
          } catch (_) {}

          try {
            final fallback = await getPaymentsByPatient(pid);
            if (fallback.isNotEmpty) {
              anySuccess = true;
              absorb(fallback);
            }
          } catch (_) {}
        }),
      );
    }

    if (!anySuccess && merged.isEmpty && lastError != null) {
      throw lastError!;
    }

    // Build appointment lookup to enrich & reconcile paid SePay bookings
    final apptById = <String, Map<String, dynamic>>{};
    final apptByCode = <String, Map<String, dynamic>>{};
    for (final a in appointments) {
      final aid = (a['appointmentId'] ?? a['id'] ?? '').toString().trim();
      final acode = (a['appointmentCode'] ?? '').toString().trim();
      if (aid.isNotEmpty) apptById[aid] = a;
      if (acode.isNotEmpty) apptByCode[acode] = a;
    }

    final matchedApptKeys = <String>{};
    for (final inv in merged.values) {
      final invApptId = (inv['appointmentId'] ?? '').toString().trim();
      final invApptCode = (inv['appointmentCode'] ?? '').toString().trim();
      final appt =
          apptById[invApptId] ??
          apptByCode[invApptCode] ??
          apptByCode[invApptId] ??
          apptById[invApptCode];
      if (appt == null) continue;

      final aid = (appt['appointmentId'] ?? appt['id'] ?? invApptId)
          .toString()
          .trim();
      final acode = (appt['appointmentCode'] ?? invApptCode).toString().trim();
      if (aid.isNotEmpty) matchedApptKeys.add(aid);
      if (acode.isNotEmpty) matchedApptKeys.add(acode);

      if ((inv['appointmentCode'] ?? '').toString().trim().isEmpty &&
          acode.isNotEmpty) {
        inv['appointmentCode'] = acode;
      }
      if ((inv['packageName'] ?? '').toString().trim().isEmpty) {
        final pkg = (appt['packageName'] ?? appt['testPackageName'] ?? '')
            .toString();
        if (pkg.isNotEmpty) inv['packageName'] = pkg;
      }

      if ((inv['appointmentStatus'] ?? '').toString().trim().isEmpty &&
          (appt['status'] ?? '').toString().trim().isNotEmpty) {
        inv['appointmentStatus'] = appt['status'];
      }

      final st = (inv['status'] ?? inv['paymentStatus'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final isInvClosed =
          st == 'partiallyrefunded' ||
          st == '2' ||
          st == 'refunded' ||
          st == '3' ||
          st == 'voided' ||
          st == '4' ||
          st == 'cancelled';
      final isInvPaid =
          !isInvClosed &&
          (st == 'paid' ||
              st == '1' ||
              st == 'completed' ||
              inv['paidAt'] != null);
      final apptSt = (appt['status'] ?? '').toString().trim().toLowerCase();
      final apptPay = (appt['paymentStatus'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final apptLooksPaid =
          apptPay == 'paid' ||
          appt['paidAt'] != null ||
          apptSt == 'confirmed' ||
          apptSt == 'checkedin' ||
          apptSt == 'inprogress' ||
          apptSt == 'completed';

      if (!isInvPaid && !isInvClosed && apptLooksPaid && aid.isNotEmpty) {
        final sepay = await getSePayStatus(
          aid,
        ).catchError((_) => <String, dynamic>{});
        final sepayPaid =
            sepay['paid'] == true ||
            sepay['isPaid'] == true ||
            (sepay['paymentStatus'] ?? '').toString().toLowerCase() == 'paid' ||
            apptPay == 'paid' ||
            appt['paidAt'] != null;
        if (sepayPaid) {
          inv['status'] = 'Paid';
          inv['paymentStatus'] = 'Paid';
          inv['paymentMethod'] ??= 'BankingQR';
          inv['paidAt'] ??=
              sepay['paidAt'] ??
              appt['paidAt'] ??
              appt['updatedAt'] ??
              appt['createdAt'];
          if ((inv['transactionReference'] ?? '').toString().isEmpty &&
              (sepay['transactionId'] ?? '').toString().isNotEmpty) {
            inv['transactionReference'] = sepay['transactionId'];
          }
        }
      }
    }

    // Synthesize billing entries for paid appointments that have no invoice record yet
    // (e.g., if paid via webhook or created via /api/appointments/create)
    for (final appt in appointments) {
      final aid = (appt['appointmentId'] ?? appt['id'] ?? '').toString().trim();
      final acode = (appt['appointmentCode'] ?? '').toString().trim();
      if ((aid.isNotEmpty && matchedApptKeys.contains(aid)) ||
          (acode.isNotEmpty && matchedApptKeys.contains(acode))) {
        continue;
      }
      final apptSt = (appt['status'] ?? '').toString().toLowerCase();
      final apptPay = (appt['paymentStatus'] ?? '').toString().toLowerCase();
      final maybePaid =
          apptPay == 'paid' ||
          appt['paidAt'] != null ||
          apptSt == 'confirmed' ||
          apptSt == 'checkedin' ||
          apptSt == 'inprogress' ||
          apptSt == 'completed';
      if (!maybePaid || aid.isEmpty) continue;

      final checkoutRes = await getSePayCheckout(
        aid,
      ).catchError((_) => (checkout: null, unavailableReason: null));
      final c = checkoutRes.checkout;
      if (c == null) continue;
      final isPaid =
          c['paid'] == true ||
          c['isPaid'] == true ||
          apptPay == 'paid' ||
          appt['paidAt'] != null;
      if (!isPaid) continue;

      final amount = c['amount'] ?? 0;
      final pkgName =
          (c['packageName'] ??
                  appt['packageName'] ??
                  appt['testPackageName'] ??
                  'Gói xét nghiệm')
              .toString();
      final code = acode.isNotEmpty ? 'INV-$acode' : 'INV-${aid.toUpperCase()}';
      merged[code] = <String, dynamic>{
        'id': code,
        'invoiceCode': code,
        'appointmentId': aid,
        'appointmentCode': acode.isNotEmpty ? acode : aid,
        'packageName': pkgName,
        'totalAmount': amount,
        'subTotal': amount,
        'status': 'Paid',
        'paymentMethod': 'BankingQR',
        'transactionReference': c['transactionId'],
        'paidAt': c['paidAt'] ?? appt['paidAt'] ?? appt['createdAt'],
        'createdAt': appt['createdAt'] ?? c['paidAt'],
        'items': [
          {
            'itemName': pkgName,
            'quantity': 1,
            'unitPrice': amount,
            'totalPrice': amount,
          },
        ],
      };
    }

    final result = merged.values.toList();
    result.sort((a, b) {
      final da = DateTime.tryParse(
        (a['paidAt'] ?? a['createdAt'] ?? '').toString(),
      );
      final db = DateTime.tryParse(
        (b['paidAt'] ?? b['createdAt'] ?? '').toString(),
      );
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return result;
  }

  /// `GET /api/payments/sepay/checkout/{appointmentId}`
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
    return (
      checkout: null,
      unavailableReason: res.extractMessage(
        res.statusCode == 503
            ? 'Cổng chuyển khoản SePay hiện chưa cấu hình tài khoản ngân hàng trên máy chủ.'
            : 'Không thể khởi tạo mã QR chuyển khoản lúc này.',
      ),
    );
  }

  /// `GET /api/payments/sepay/status/{appointmentId}`
  Future<Map<String, dynamic>> getSePayStatus(String appointmentId) async {
    final res = await _http.get(
      '/api/payments/sepay/status/${Uri.encodeComponent(appointmentId)}',
    );
    if (!res.isSuccess) return {};
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `POST /api/payments/sepay/simulate/{appointmentId}` (Sandbox Demo 1-tap)
  Future<Map<String, dynamic>> simulateSePayPayment(
    String appointmentId,
  ) async {
    final res = await _http.post(
      '/api/payments/sepay/simulate/${Uri.encodeComponent(appointmentId)}',
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể giả lập thanh toán SePay.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  // ===================== FEEDBACK HUB (ROOT /TestOrder/feedback) =====================

  Future<List<Map<String, dynamic>>> getMyFeedbacks(String userId) async {
    if (userId.trim().isEmpty) return const [];
    final res = await _http.get(
      '/TestOrder/feedback/patient/${Uri.encodeComponent(userId.trim())}',
    );
    if (!res.isSuccess) return const [];
    return _toMapList(res.data);
  }

  Future<List<Map<String, dynamic>>> getMyEligiblePackages() async {
    final res = await _http.get('/TestOrder/feedback/my-eligible-packages');
    if (!res.isSuccess) return const [];
    return _toMapList(res.data);
  }

  Future<Map<String, dynamic>> checkFeedbackEligibility() async {
    final res = await _http.get('/TestOrder/feedback/eligibility');
    if (!res.isSuccess) {
      return {'isEligible': false, 'reason': res.extractMessage('')};
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  Future<Map<String, dynamic>> createFeedback(
    Map<String, dynamic> payload,
  ) async {
    final res = await _http.post('/TestOrder/feedback', body: payload);
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Gửi đánh giá không thành công.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  Future<Map<String, dynamic>> updateFeedback(
    String feedbackId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _http.put(
      '/TestOrder/feedback/${Uri.encodeComponent(feedbackId)}',
      body: payload,
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Cập nhật đánh giá không thành công.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  Future<void> deleteFeedback(String feedbackId) async {
    final res = await _http.delete(
      '/TestOrder/feedback/${Uri.encodeComponent(feedbackId)}',
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Xóa đánh giá không thành công.'),
        statusCode: res.statusCode,
      );
    }
  }

  Future<void> respondDeleteConsent(String feedbackId, bool approved) async {
    final res = await _http.post(
      '/TestOrder/feedback/${Uri.encodeComponent(feedbackId)}/consent-delete',
      body: {'approved': approved},
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể gửi xác nhận yêu cầu xóa.'),
        statusCode: res.statusCode,
      );
    }
  }

  // ===================== NOTIFICATIONS =====================

  Future<List<Map<String, dynamic>>> getCombinedNotifications({
    required String patientId,
  }) async {
    final userId = BmsAuth.currentUserId;
    final merged = <Map<String, dynamic>>[];

    if (patientId.isNotEmpty) {
      try {
        final res = await _http.get(
          '/api/notifications/test-results/patient/${Uri.encodeComponent(patientId)}',
        );
        if (res.isSuccess) {
          for (final item in _toMapList(res.data)) {
            final st = (item['status'] ?? '').toString().toUpperCase();
            merged.add({
              'id': (item['notificationId'] ?? item['id'] ?? '').toString(),
              'source': 'test_result',
              'title': (item['title'] ?? 'Thông báo kết quả xét nghiệm')
                  .toString(),
              'message': (item['message'] ?? '').toString(),
              'createdAt':
                  (item['sentAt'] ??
                          item['createdAt'] ??
                          item['dispatchedAt'] ??
                          '')
                      .toString(),
              'isRead':
                  st == 'READ' ||
                  item['readAt'] != null ||
                  item['isRead'] == true,
              'isPanic': item['isCriticalPanicValue'] == true,
              'orderId': (item['testOrderId'] ?? item['orderId'] ?? '')
                  .toString(),
              'raw': item,
            });
          }
        }
      } catch (_) {}
    }

    try {
      final res = await _http.get('/api/notifications/appointments');
      if (res.isSuccess) {
        for (final item in _toMapList(res.data)) {
          final st = (item['status'] ?? '').toString().toUpperCase();
          merged.add({
            'id': (item['id'] ?? item['notificationId'] ?? '').toString(),
            'source': 'appointment',
            'title': (item['title'] ?? 'Nhắc lịch hẹn khám').toString(),
            'message': (item['message'] ?? item['content'] ?? '').toString(),
            'createdAt':
                (item['sentAt'] ??
                        item['createdAt'] ??
                        item['dispatchedAt'] ??
                        '')
                    .toString(),
            'isRead':
                st == 'READ' ||
                item['readAt'] != null ||
                item['isRead'] == true,
            'isPanic': false,
            'appointmentId': (item['appointmentId'] ?? '').toString(),
            'raw': item,
          });
        }
      }
    } catch (_) {}

    if (userId.isNotEmpty) {
      try {
        final res = await _http.get(
          '/api/v1/notifications/user/${Uri.encodeComponent(userId)}',
        );
        if (res.isSuccess) {
          for (final item in _toMapList(res.data)) {
            final st = (item['status'] ?? '').toString().toUpperCase();
            merged.add({
              'id': (item['id'] ?? item['notificationId'] ?? '').toString(),
              'source': 'user',
              'title': (item['title'] ?? 'Thông báo hệ thống').toString(),
              'message': (item['message'] ?? item['body'] ?? '').toString(),
              'createdAt':
                  (item['createdAt'] ??
                          item['dispatchedAt'] ??
                          item['sentAt'] ??
                          '')
                      .toString(),
              'isRead':
                  st == 'READ' ||
                  item['readAt'] != null ||
                  item['isRead'] == true,
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

  Future<void> markAllUserNotificationsRead(String userId) async {
    if (userId.trim().isEmpty) return;
    await _http.patch(
      '/api/v1/notifications/user/${Uri.encodeComponent(userId.trim())}/read-all',
    );
  }
}
