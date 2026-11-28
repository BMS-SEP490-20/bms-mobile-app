import '../../../core/network/bms_http_client.dart';

/// Unified Lightweight Mobile API client for Internal Staff roles
/// (Doctor, Lab, Receptionist, Manager, Admin).
class StaffPortalApi {
  final BmsHttpClient _http;

  const StaffPortalApi({BmsHttpClient? http})
    : _http = http ?? const BmsHttpClient();

  List<Map<String, dynamic>> _toMapList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (raw is Map<String, dynamic>) {
      for (final key in const [
        'items',
        'Items',
        'data',
        'shifts',
        'devices',
        'alerts',
        'results',
      ]) {
        if (raw[key] is List) {
          return (raw[key] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return const [];
  }

  /// `GET /api/users/me`
  Future<Map<String, dynamic>?> getMyProfile() async {
    final res = await _http.get('/api/users/me');
    if (!res.isSuccess) return null;
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/shifts` (server automatically scopes Doctor/Lab/Receptionist to own shifts,
  /// and returns all non-Admin hospital shifts for Manager/Admin).
  Future<List<Map<String, dynamic>>> getShifts({
    required String fromDate,
    required String toDate,
  }) async {
    final res = await _http.get(
      '/api/shifts',
      query: {'fromDate': fromDate, 'toDate': toDate},
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tải lịch ca trực.'),
        statusCode: res.statusCode,
      );
    }
    return _toMapList(res.data);
  }

  /// `GET /api/dashboard/admin-ops` (Admin IT & Governance KPIs — ZERO patient PHI)
  Future<Map<String, dynamic>> getAdminOpsDashboard() async {
    final res = await _http.get('/api/dashboard/admin-ops');
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể tải bảng điều hành hệ thống.'),
        statusCode: res.statusCode,
      );
    }
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/dashboard/stats` (Manager KPI overview)
  Future<Map<String, dynamic>> getManagerStats() async {
    final res = await _http.get('/api/dashboard/stats');
    if (!res.isSuccess) return {};
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/revenue/report`
  Future<Map<String, dynamic>> getRevenueSummary({
    required String fromDate,
    required String toDate,
  }) async {
    final res = await _http.get(
      '/api/revenue/report',
      query: {'fromDate': fromDate, 'toDate': toDate},
    );
    if (!res.isSuccess) return {};
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/tat/statistics/report`
  Future<Map<String, dynamic>> getTatSummary({
    required String fromDate,
    required String toDate,
  }) async {
    final res = await _http.get(
      '/api/tat/statistics/report',
      query: {'fromDate': fromDate, 'toDate': toDate},
    );
    if (!res.isSuccess) return {};
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /api/iot/status/all`
  Future<List<Map<String, dynamic>>> getIotDevices() async {
    final res = await _http.get('/api/iot/status/all');
    if (!res.isSuccess) return const [];
    return _toMapList(res.data);
  }

  /// `GET /api/iot/alerts`
  Future<List<Map<String, dynamic>>> getIotAlerts() async {
    final res = await _http.get('/api/iot/alerts');
    if (!res.isSuccess) return const [];
    return _toMapList(res.data);
  }

  /// `POST /api/iot/alerts/{id}/acknowledge` (Manager only)
  Future<void> acknowledgeIotAlert(String alertId, {String? note}) async {
    final res = await _http.post(
      '/api/iot/alerts/${Uri.encodeComponent(alertId)}/acknowledge',
      body: {
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    if (!res.isSuccess) {
      throw BmsApiException(
        res.extractMessage('Không thể xác nhận cảnh báo IoT.'),
        statusCode: res.statusCode,
      );
    }
  }

  /// `GET /TestOrder/feedback/statistics`
  Future<Map<String, dynamic>> getFeedbackStatistics() async {
    final res = await _http.get('/TestOrder/feedback/statistics');
    if (!res.isSuccess) return {};
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : res.bodyAsMap;
  }

  /// `GET /TestOrder/feedback` (Read-only overview for Manager)
  Future<List<Map<String, dynamic>>> getRecentFeedbacks() async {
    final res = await _http.get('/TestOrder/feedback');
    if (!res.isSuccess) return const [];
    return _toMapList(res.data);
  }
}
