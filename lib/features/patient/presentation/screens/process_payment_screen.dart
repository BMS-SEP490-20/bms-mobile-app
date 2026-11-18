import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../patient_portal/presentation/tabs/patient_billing_tab.dart';
import '../../data/payment_repository.dart';
import '../../models/payment_checkout_model.dart';

/// Patient Invoice Checkout & Payment Screen in Vietnamese Soft Healthcare SaaS design.
class ProcessPaymentScreen extends StatefulWidget {
  final String? invoiceId;
  final PaymentRepository? repository;

  const ProcessPaymentScreen({super.key, this.invoiceId, this.repository});

  @override
  State<ProcessPaymentScreen> createState() => _ProcessPaymentScreenState();
}

class _ProcessPaymentScreenState extends State<ProcessPaymentScreen> {
  late final PaymentRepository _repo;
  final TextEditingController _discountCtrl = TextEditingController();

  PaymentCheckoutModel? _checkoutData;
  PaymentCheckoutModel? _successResult;
  String _paymentMethod = 'SePay';
  double _appliedDiscountAmount = 0.0;
  String? _appliedDiscountCode;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? PaymentRepository();
    if (widget.invoiceId != null && widget.invoiceId!.trim().isNotEmpty) {
      _loadCheckout(widget.invoiceId!.trim());
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCheckout(String targetId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _repo.getCheckoutSummary(targetId);
      if (!mounted) return;
      setState(() {
        _checkoutData = res;
        _appliedDiscountAmount = res?.discountAmount ?? 0.0;
        _appliedDiscountCode = res?.discountCode;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải chi tiết thanh toán hóa đơn.';
      });
    }
  }

  Future<void> _applyDiscount() async {
    final code = _discountCtrl.text.trim();
    final targetId = _checkoutData?.invoiceId ?? widget.invoiceId ?? '';
    if (code.isEmpty || targetId.isEmpty) return;

    try {
      final res = await _repo.applyDiscount(targetId, code);
      if (!mounted) return;
      if (res != null && res['success'] == true && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _appliedDiscountAmount =
              (data['discountAmount'] as num?)?.toDouble() ?? 0.0;
          _appliedDiscountCode = data['discountCode']?.toString();
          _errorMessage = null;
        });
      } else {
        setState(() => _errorMessage = 'Mã ưu đãi không hợp lệ hoặc đã hết hạn.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Không thể kiểm tra mã ưu đãi.');
      }
    }
  }

  Future<void> _payNow() async {
    final targetId = _checkoutData?.invoiceId ?? widget.invoiceId ?? '';
    if (targetId.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final res = await _repo.processPayment({
        'invoiceId': targetId,
        'paymentMethod': _paymentMethod,
        if (_appliedDiscountCode != null) 'discountCode': _appliedDiscountCode,
      });
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _successResult = res;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Xử lý thanh toán không thành công. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.invoiceId == null || widget.invoiceId!.trim().isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Viện phí & Thanh toán')),
        body: const PatientBillingTab(),
      );
    }

    final subTotal = _checkoutData?.subTotal ?? 0.0;
    final totalDue = (subTotal - _appliedDiscountAmount) > 0
        ? (subTotal - _appliedDiscountAmount)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Thanh toán hóa đơn')),
      body: _isLoading
          ? const BmsLoadingState(message: 'Đang tải thông tin thanh toán...')
          : _successResult != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: BmsSoftCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 52,
                          color: AppColors.success,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Thanh toán thành công',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        BmsInfoRow(
                          label: 'Mã hóa đơn',
                          value: _successResult!.invoiceCode,
                          isMono: true,
                        ),
                        BmsInfoRow(
                          label: 'Số tiền đã thu',
                          value: BmsFormatters.currency(
                            _successResult!.totalAmount,
                          ),
                          isBold: true,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).maybePop(true),
                            child: const Text('Hoàn tất'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    if (_errorMessage != null) ...[
                      BmsErrorState(message: _errorMessage!),
                      const SizedBox(height: 12),
                    ],
                    BmsSoftCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          BmsInfoRow(
                            label: 'Nội dung thu',
                            value: _checkoutData?.packageName ?? 'Viện phí xét nghiệm',
                            isBold: true,
                          ),
                          BmsInfoRow(
                            label: 'Tạm tính',
                            value: BmsFormatters.currency(subTotal),
                          ),
                          if (_appliedDiscountAmount > 0)
                            BmsInfoRow(
                              label: 'Giảm trừ ưu đãi',
                              value:
                                  '- ${BmsFormatters.currency(_appliedDiscountAmount)}',
                              valueColor: AppColors.successText,
                            ),
                          const Divider(height: 20),
                          BmsInfoRow(
                            label: 'CẦN THANH TOÁN',
                            value: BmsFormatters.currency(totalDue),
                            isBold: true,
                            valueColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    BmsSoftCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _discountCtrl,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Mã ưu đãi (nếu có)',
                                hintText: 'Nhập mã ưu đãi...',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _applyDiscount,
                            child: const Text('Áp dụng'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    BmsSoftCard(
                      padding: const EdgeInsets.all(16),
                      child: DropdownButtonFormField<String>(
                        initialValue: _paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Phương thức thanh toán',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'SePay',
                            child: Text('Chuyển khoản QR Ngân hàng (SePay)'),
                          ),
                          DropdownMenuItem(
                            value: 'VNPay',
                            child: Text('Cổng thanh toán VNPay'),
                          ),
                          DropdownMenuItem(
                            value: 'Reception',
                            child: Text('Thanh toán trực tiếp tại quầy'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _paymentMethod = v);
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _isSubmitting ? null : _payNow,
                        icon: const Icon(Icons.payments_outlined, size: 19),
                        label: Text(
                          _isSubmitting
                              ? 'Đang xử lý...'
                              : 'Xác nhận thanh toán ${BmsFormatters.currency(totalDue)}',
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
