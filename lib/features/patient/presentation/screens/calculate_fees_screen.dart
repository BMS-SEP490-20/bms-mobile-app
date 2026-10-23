import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/calculate_fee_repository.dart';
import '../../models/calculate_fee_model.dart';

/// Screen representing UC53 – Calculate Fees on Mobile.
/// Conforms to: Production Standards & AGENTS-DESIGN.md.
class CalculateFeesScreen extends StatefulWidget {
  final List<String>? initialPackageIds;
  final String? initialServiceType;
  final CalculateFeeRepository? repository;

  const CalculateFeesScreen({
    super.key,
    this.initialPackageIds,
    this.initialServiceType,
    this.repository,
  });

  @override
  State<CalculateFeesScreen> createState() => _CalculateFeesScreenState();
}

class _CalculateFeesScreenState extends State<CalculateFeesScreen> {
  late final CalculateFeeRepository _repo = widget.repository ?? CalculateFeeRepository();

  final List<Map<String, dynamic>> _availablePackages = [
    {'id': 'PKG-CBC-01', 'name': 'Tổng Phân Tích Tế Bào Máu (CBC)', 'price': 150000.0, 'tube': 'EDTA (Tím)'},
    {'id': 'PKG-BIO-01', 'name': 'Sinh Hóa Máu Cơ Bản (Glucose, Ure, Creatinine)', 'price': 250000.0, 'tube': 'SST (Vàng)'},
    {'id': 'PKG-LIPID-01', 'name': 'Bộ Mỡ Máu Toàn Phần (Cholesterol, Triglyceride)', 'price': 220000.0, 'tube': 'SST (Vàng)'},
    {'id': 'PKG-LIVER-01', 'name': 'Bộ Men Gan Đầy Đủ (AST, ALT, GGT)', 'price': 180000.0, 'tube': 'Heparin (Xanh)'},
    {'id': 'PKG-GENERAL-01', 'name': 'Gói Xét Nghiệm Khám Tổng Quát', 'price': 1200000.0, 'tube': 'Đa ống nghiệm'},
  ];

  late Set<String> _selectedPackageIds;
  String _serviceType = 'Clinic'; // Clinic | HomeCollection
  final TextEditingController _insuranceController = TextEditingController();
  final TextEditingController _voucherController = TextEditingController();
  bool _isPriorityPatient = false;

  bool _loading = false;
  CalculateFeeResultModel? _calculation;
  String? _errorMessage;

  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _selectedPackageIds = widget.initialPackageIds != null && widget.initialPackageIds!.isNotEmpty
        ? widget.initialPackageIds!.toSet()
        : {'PKG-CBC-01', 'PKG-BIO-01'};
    if (widget.initialServiceType != null) {
      _serviceType = widget.initialServiceType!;
    }
    _runCalculation();
  }

  @override
  void dispose() {
    _insuranceController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _runCalculation() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await _repo.calculateFees(
        packageIds: _selectedPackageIds.toList(),
        serviceType: _serviceType,
        insuranceCardNumber: _insuranceController.text.trim().isEmpty ? null : _insuranceController.text.trim(),
        voucherCode: _voucherController.text.trim().isEmpty ? null : _voucherController.text.trim(),
        isPriorityPatient: _isPriorityPatient,
      );
      if (mounted) {
        setState(() {
          _calculation = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi tính phí: $e';
          _loading = false;
        });
      }
    }
  }

  String _formatVnd(double val) {
    return '${_currencyFormat.format(val.round())} ₫';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Dự Toán Chi Phí Xét Nghiệm',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading && _calculation == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  _buildPackageSelectionCard(),
                  const SizedBox(height: 16),
                  _buildServiceTypeCard(),
                  const SizedBox(height: 16),
                  _buildInsuranceCard(),
                  const SizedBox(height: 16),
                  _buildVoucherCard(),
                  const SizedBox(height: 16),
                  if (_calculation != null) _buildBreakdownCard(_calculation!),
                  const SizedBox(height: 80), // Padding for sticky bottom bar
                ],
              ),
            ),
      bottomNavigationBar: _calculation != null ? _buildBottomBar(_calculation!) : null,
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            radius: 24,
            child: Icon(Icons.calculate_rounded, color: AppColors.primary, size: 28),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HỆ THỐNG TÍNH PHÍ TỰ ĐỘNG',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                SizedBox(height: 2),
                Text(
                  'Chiết tính viện phí & quyền lợi BHYT',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageSelectionCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Chọn Gói Xét Nghiệm',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          ..._availablePackages.map((pkg) {
            final id = pkg['id'] as String;
            final isSelected = _selectedPackageIds.contains(id);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                pkg['name'] as String,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Ống: ${pkg['tube']} • ${_formatVnd(pkg['price'] as double)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              value: isSelected,
              activeColor: AppColors.primary,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedPackageIds.add(id);
                  } else {
                    _selectedPackageIds.remove(id);
                  }
                });
                _runCalculation();
              },
            );
          }),
        ],
      ),
    ),
  );
  }

  Widget _buildServiceTypeCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2. Hình Thức Lấy Mẫu',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tại Phòng Khám BMS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('Miễn phụ phí dịch vụ', style: TextStyle(fontSize: 12, color: AppColors.success)),
            value: 'Clinic',
            groupValue: _serviceType,
            activeColor: AppColors.primary,
            onChanged: (val) {
              if (val != null) {
                setState(() => _serviceType = val);
                _runCalculation();
              }
            },
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lấy Mẫu Tận Nơi (Tại Nhà)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('+150.000 ₫ phụ phí di chuyển & chuỗi lạnh', style: TextStyle(fontSize: 12, color: AppColors.warning)),
            value: 'HomeCollection',
            groupValue: _serviceType,
            activeColor: AppColors.primary,
            onChanged: (val) {
              if (val != null) {
                setState(() => _serviceType = val);
                _runCalculation();
              }
            },
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildInsuranceCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '3. Bảo Hiểm Y Tế & Chế Độ Ưu Tiên',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _insuranceController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Mã Thẻ BHYT (15 Ký tự)',
              hintText: 'VD: DN4791234567890 hoặc TE101...',
              prefixIcon: const Icon(Icons.security, color: AppColors.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (_) => _runCalculation(),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickCardBtn('TE (Trẻ em 100%)', 'TE1012345678901'),
                const SizedBox(width: 6),
                _buildQuickCardBtn('DN (Lao động 80%)', 'DN4791234567890'),
                const SizedBox(width: 6),
                _buildQuickCardBtn('CN (Cận nghèo 95%)', 'CN3012345678901'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Đối tượng ưu tiên khám chữa bệnh', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('Người cao tuổi ≥ 80, Trẻ em < 6 (Giảm 10% viện phí)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            value: _isPriorityPatient,
            activeColor: AppColors.primary,
            onChanged: (val) {
              setState(() => _isPriorityPatient = val);
              _runCalculation();
            },
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildQuickCardBtn(String label, String code) {
    return InkWell(
      onTap: () {
        _insuranceController.text = code;
        _runCalculation();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildVoucherCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '4. Mã Khuyến Mãi / Voucher',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _voucherController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Mã Giảm Giá',
                    hintText: 'BMS10, FREEHOME...',
                    prefixIcon: const Icon(Icons.local_offer_outlined, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _runCalculation,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: const Text('Áp Dụng'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickVoucherBtn('BMS10 (-10%)', 'BMS10'),
                const SizedBox(width: 6),
                _buildQuickVoucherBtn('FREEHOME (Free ship)', 'FREEHOME'),
                const SizedBox(width: 6),
                _buildQuickVoucherBtn('VIP50 (-50k)', 'VIP50'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickVoucherBtn(String label, String code) {
    return InkWell(
      onTap: () {
        _voucherController.text = code;
        _runCalculation();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBreakdownCard(CalculateFeeResultModel calc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Chi Tiết Bảng Giá', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text(calc.calculationReference, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontFamily: 'monospace')),
            ],
          ),
          const Divider(height: 20),
          ...calc.items.map((it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(it.itemName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                    Text(_formatVnd(it.totalPrice), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
          const Divider(height: 20),
          _buildRow('Tổng phí xét nghiệm:', _formatVnd(calc.testSubTotal)),
          _buildRow('Phụ phí lấy mẫu (${calc.serviceType == "HomeCollection" ? "Tại nhà" : "Tại viện"}):', _formatVnd(calc.homeCollectionSurcharge)),
          if (calc.hasInsurance)
            _buildRow(
              'BHYT chi trả (${calc.insuranceCoveragePercent}%):',
              '-${_formatVnd(calc.insuranceDeduction)}',
              color: AppColors.success,
            ),
          if (calc.voucherDiscount > 0)
            _buildRow(
              'Voucher (${calc.voucherCode}):',
              '-${_formatVnd(calc.voucherDiscount)}',
              color: AppColors.primary,
            ),
          if (calc.priorityDiscount > 0)
            _buildRow(
              'Ưu đãi đối tượng ưu tiên:',
              '-${_formatVnd(calc.priorityDiscount)}',
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(CalculateFeeResultModel calc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tổng thanh toán:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  Text(
                    _formatVnd(calc.netTotalPayable),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.payment, size: 18),
              label: const Text('Thanh Toán'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/payment');
              },
            ),
          ],
        ),
      ),
    );
  }
}
