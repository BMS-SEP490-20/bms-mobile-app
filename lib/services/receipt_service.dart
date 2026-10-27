import 'dart:convert';
import 'api.dart';

/// Service responsible for calculating laboratory service fees and generating itemized payment receipts.
/// Utilized by Receptionists on mobile devices to process patient checkout.
class ReceiptService {
  /// Generates an itemized payment receipt or electronic invoice for requested test packages.
  /// Automatically calculates subtotal, tax amount, and net payable total.
  /// 
  /// [payload] contains appointmentId, patientId, paymentMethod, tax, and itemized packages.
  /// Returns a Map containing the generated receipt metadata.
  static Future<Map<String, dynamic>> generateReceipt(Map<String, dynamic> payload) async {
    try {
      final response = await Api.post('/gateway/payments/receipt', payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'] ?? data,
          'message': data['message'] ?? 'Biên lai đã được tạo thành công.',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Lỗi khi tạo biên lai thanh toán.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Không thể kết nối đến máy chủ thanh toán: $e',
      };
    }
  }

  /// Retrieves an existing electronic receipt by receipt number reference.
  static Future<Map<String, dynamic>> getReceiptByNumber(String receiptNumber) async {
    try {
      final response = await Api.get('/gateway/payments/receipt/$receiptNumber');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'] ?? data,
        };
      } else {
        return {
          'success': false,
          'message': 'Không tìm thấy biên lai thanh toán.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi khi tải thông tin biên lai: $e',
      };
    }
  }

  /// Fetches available test packages for billing selection.
  static Future<List<Map<String, dynamic>>> getTestPackages() async {
    try {
      final response = await Api.get('/gateway/testorder/testpackage');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final list = json['data'] ?? json;
        if (list is List) {
          return List<Map<String, dynamic>>.from(list);
        }
      }
    } catch (_) {}
    
    // Fallback standard test packages
    return [
      {'packageId': 'PKG001', 'packageName': 'Tổng phân tích tế bào máu ngoại vi', 'price': 250000},
      {'packageId': 'PKG002', 'packageName': 'Xét nghiệm sinh hóa máu tổng quát', 'price': 450000},
      {'packageId': 'PKG003', 'packageName': 'Bộ xét nghiệm chức năng gan thận', 'price': 350000},
      {'packageId': 'PKG004', 'packageName': 'Gói xét nghiệm tầm soát mỡ máu', 'price': 300000},
    ];
  }
}
