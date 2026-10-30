import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bms_mobile_app/services/receipt_service.dart';
import 'package:bms_mobile_app/services/appointment_service.dart';

/// Screen for Receptionists to calculate service fees and generate itemized electronic payment receipts.
/// Supports automated fee calculation, package selection, and electronic invoice display.
class GenerateReceiptScreen extends StatefulWidget {
  final Map<String, dynamic>? initialAppointment;

  const GenerateReceiptScreen({super.key, this.initialAppointment});

  @override
  State<GenerateReceiptScreen> createState() => _GenerateReceiptScreenState();
}

class _GenerateReceiptScreenState extends State<GenerateReceiptScreen> {
  List<dynamic> _appointments = [];
  List<Map<String, dynamic>> _packages = [];
  Map<String, dynamic>? _selectedAppointment;
  Map<String, dynamic>? _selectedPackage;

  int _quantity = 1;
  double _unitPrice = 350000;
  double _taxPercent = 8.0;
  double _discountAmount = 0.0;
  String _paymentMethod = 'Cash';
  final TextEditingController _notesController = TextEditingController();

  bool _loading = false;
  bool _submitting = false;
  Map<String, dynamic>? _generatedReceipt;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndData() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      _currentUser = jsonDecode(userStr);
    }

    final packages = await ReceiptService.getTestPackages();
    final aptResult = await AppointmentService.getAllAppointments();

    setState(() {
      _packages = packages;
      if (packages.isNotEmpty) {
        _selectedPackage = packages.first;
        _unitPrice = (_selectedPackage!['price'] as num?)?.toDouble() ?? 350000;
      }

      if (aptResult['success'] == true) {
        _appointments = (aptResult['data'] as List?) ?? [];
      }

      if (widget.initialAppointment != null) {
        _selectedAppointment = widget.initialAppointment;
      } else if (_appointments.isNotEmpty) {
        _selectedAppointment = _appointments.first as Map<String, dynamic>;
      }

      _loading = false;
    });
  }

  double get _subTotal => _unitPrice * _quantity;
  double get _taxAmount => (_subTotal * _taxPercent) / 100.0;
  double get _totalAmount {
    final total = _subTotal + _taxAmount - _discountAmount;
    return total > 0 ? total : 0;
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ';
  }

  Future<void> _handleGenerateReceipt() async {
    if (_selectedPackage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn gói xét nghiệm.')),
      );
      return;
    }

    setState(() => _submitting = true);

    final appointmentId = _selectedAppointment != null
        ? (_selectedAppointment!['appointmentId'] ?? _selectedAppointment!['id'] ?? '').toString()
        : '';
    final patientId = _selectedAppointment != null
        ? (_selectedAppointment!['patientId'] ?? _selectedAppointment!['createdBy'] ?? '00000000-0000-0000-0000-000000000000').toString()
        : '00000000-0000-0000-0000-000000000000';
    final patientName = _selectedAppointment != null
        ? (_selectedAppointment!['patientName'] ?? _selectedAppointment!['guestName'] ?? 'Bệnh nhân').toString()
        : 'Bệnh nhân';

    final payload = {
      'appointmentId': appointmentId,
      'patientId': patientId,
      'patientName': patientName,
      'patientPhone': _selectedAppointment?['phone'] ?? _selectedAppointment?['guestPhone'] ?? '',
      'receptionistId': _currentUser?['id'] ?? 'REC01',
      'receptionistName': _currentUser?['fullName'] ?? _currentUser?['username'] ?? 'Lễ tân tiếp đón',
      'paymentMethod': _paymentMethod,
      'taxPercent': _taxPercent,
      'discountAmount': _discountAmount,
      'notes': _notesController.text,
      'items': [
        {
          'packageId': _selectedPackage!['packageId'] ?? 'PKG001',
          'packageName': _selectedPackage!['packageName'] ?? 'Xét nghiệm máu',
          'quantity': _quantity,
          'unitPrice': _unitPrice,
        }
      ]
    };

    final result = await ReceiptService.generateReceipt(payload);

    setState(() => _submitting = false);

    if (result['success'] == true && mounted) {
      setState(() {
        _generatedReceipt = result['data'] as Map<String, dynamic>?;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Đã tạo biên lai thanh toán thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Lỗi khi tạo biên lai.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool get _isAuthorized {
    if (_currentUser == null) return true;
    final rId = _currentUser!['roleId'];
    int? roleIdNumber;
    if (rId is int) roleIdNumber = rId;
    if (rId != null) roleIdNumber = int.tryParse(rId.toString());
    final rawRole = _currentUser!['role']?.toString().toLowerCase();

    // BUSINESS RULE: Receipt generation is reserved for Receptionist (6), Manager (2), Administrator (1).
    // Patients, Doctors, and Lab Users are forbidden from generating receipts.
    return roleIdNumber == 6 || rawRole == 'receptionist' ||
           roleIdNumber == 2 || rawRole == 'manager' ||
           roleIdNumber == 1 || rawRole == 'admin' || rawRole == 'administrator';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xuất Biên Lai Thu Phí', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF212529),
        elevation: 1,
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_isAuthorized
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.block, size: 64, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        const Text(
                          'Không có quyền truy cập',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tính năng Xuất Biên Lai Thu Phí chỉ dành cho Nhân viên Lễ tân (Receptionist) và Quản lý phòng khám. Bệnh nhân không thể xuất biên lai thu phí.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Quay lại Trang Chủ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D6EFD),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _generatedReceipt != null
                      ? _buildReceiptView()
                      : _buildBillingForm(),
                ),
    );
  }

  Widget _buildBillingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF198754), Color(0xFF157347)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.white, size: 36),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tạo Biên Lai Tiếp Nhận',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tự động tính phí & xuất hóa đơn điện tử cho lễ tân',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Appointment Selection
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn Lịch Hẹn / Bệnh Nhân', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                if (_appointments.isNotEmpty)
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _selectedAppointment,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _appointments.map((apt) {
                      final map = apt as Map<String, dynamic>;
                      final name = map['patientName'] ?? map['guestName'] ?? 'Bệnh nhân';
                      final id = map['appointmentId'] ?? map['id'] ?? '';
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: map,
                        child: Text('$name ($id)', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedAppointment = val);
                    },
                  )
                else
                  const Text('Không có lịch hẹn cần xử lý.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Package Selection & Quantity
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gói Xét Nghiệm & Số Lượng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: _selectedPackage,
                  decoration: InputDecoration(
                    labelText: 'Gói xét nghiệm',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _packages.map((pkg) {
                    final price = (pkg['price'] as num?)?.toDouble() ?? 0;
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: pkg,
                      child: Text('${pkg['packageName']} (${_formatCurrency(price)})', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedPackage = val;
                        _unitPrice = (val['price'] as num?)?.toDouble() ?? 350000;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _quantity.toString(),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Số lượng',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _quantity = int.tryParse(val) ?? 1;
                            if (_quantity < 1) _quantity = 1;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: _taxPercent.toStringAsFixed(0),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'VAT (%)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _taxPercent = double.tryParse(val) ?? 0.0;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _discountAmount.toStringAsFixed(0),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Giảm trừ / Khuyến mãi (đ)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _discountAmount = double.tryParse(val) ?? 0.0;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Payment Method & Notes
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Thanh Toán & Ghi Chú', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: InputDecoration(
                    labelText: 'Hình thức thanh toán',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('Tiền mặt (Cash)')),
                    DropdownMenuItem(value: 'VNPay', child: Text('Cổng thanh toán VNPay')),
                    DropdownMenuItem(value: 'BankTransfer', child: Text('Chuyển khoản ngân hàng')),
                    DropdownMenuItem(value: 'CreditCard', child: Text('Thẻ POS / Tín dụng')),
                  ],
                  onChanged: (val) => setState(() => _paymentMethod = val ?? 'Cash'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Ghi chú thanh toán',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Calculation Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tiền dịch vụ (Subtotal):', style: TextStyle(color: Colors.grey)),
                  Text(_formatCurrency(_subTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Thuế VAT (${_taxPercent.toStringAsFixed(0)}%):', style: const TextStyle(color: Colors.grey)),
                  Text('+${_formatCurrency(_taxAmount)}'),
                ],
              ),
              if (_discountAmount > 0) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Giảm trừ:', style: TextStyle(color: Colors.red)),
                    Text('-${_formatCurrency(_discountAmount)}', style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ],
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng thanh toán:', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  Text(
                    _formatCurrency(_totalAmount),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF198754)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Submit Button
        ElevatedButton.icon(
          onPressed: _submitting ? null : _handleGenerateReceipt,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF198754),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: _submitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check_circle_outline, color: Colors.white),
          label: Text(
            _submitting ? 'Đang tạo biên lai...' : 'Xác Nhận & Xuất Biên Lai',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptView() {
    final receipt = _generatedReceipt!;
    final items = (receipt['items'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4)),
            ],
            border: Border.all(color: Colors.green.shade200, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Icon(Icons.check_circle, color: Color(0xFF198754), size: 48),
              ),
              const SizedBox(height: 8),
              const Text(
                'PHÒNG XÉT NGHIỆM HUYẾT HỌC BMS',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D6EFD)),
                textAlign: TextAlign.center,
              ),
              const Text(
                'BIÊN LAI THANH TOÁN ĐIỆN TỬ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Số biên lai:', style: TextStyle(color: Colors.grey)),
                  Text(receipt['receiptNumber'] ?? 'REC-XXXX', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bệnh nhân:', style: TextStyle(color: Colors.grey)),
                  Text(receipt['patientName'] ?? 'Bệnh nhân', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Thu ngân / Lễ tân:', style: TextStyle(color: Colors.grey)),
                  Text(receipt['receptionistName'] ?? 'Lễ tân tiếp đón'),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Hình thức:', style: TextStyle(color: Colors.grey)),
                  Text(receipt['paymentMethod'] ?? 'Tiền mặt', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const Divider(height: 24),

              // Itemized list
              const Text('Chi tiết gói xét nghiệm:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...items.map((item) {
                final map = item as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${map['packageName']} (x${map['quantity']})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        _formatCurrency(((map['amount'] ?? map['unitPrice']) as num?)?.toDouble() ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }),

              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng cộng thanh toán:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    _formatCurrency(((receipt['totalAmount']) as num?)?.toDouble() ?? 0),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF198754)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _generatedReceipt = null;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D6EFD),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Tạo Biên Lai Mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
