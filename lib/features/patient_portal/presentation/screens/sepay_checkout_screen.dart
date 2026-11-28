import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../data/patient_portal_api.dart';
import '../../../appointment/presentation/appointment_confirmation_screen.dart';

/// 1-to-1 SePay VietQR Payment Checkout Screen matching Web `ProcessPaymentPage.jsx`:
/// - Calls `GET /api/payments/sepay/checkout/{appointmentId}`
/// - Displays REAL VietQR image via `Image.network(qrUrl)` (never blocks HTTP URLs!)
/// - Bank transfer details with one-tap copy (bankCode, accountNumber, accountName, transferContent, amount)
/// - Auto-polls `GET /api/payments/sepay/status/{appointmentId}` every 3 seconds
/// - Demo Sandbox 1-tap button (`POST /api/payments/sepay/simulate/{appointmentId}`) when `allowSandbox == true`
/// - Zero BHYT, zero VNPay/Reception 403 buttons.
class SePayCheckoutScreen extends StatefulWidget {
  final String appointmentId;
  final String? appointmentCode;
  final String? packageName;

  const SePayCheckoutScreen({
    super.key,
    required this.appointmentId,
    this.appointmentCode,
    this.packageName,
  });

  @override
  State<SePayCheckoutScreen> createState() => _SePayCheckoutScreenState();
}

class _SePayCheckoutScreenState extends State<SePayCheckoutScreen> {
  final PatientPortalApi _api = const PatientPortalApi();

  bool _loading = true;
  bool _simulating = false;
  bool _paid = false;
  String? _error;
  Map<String, dynamic>? _checkout;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadCheckout();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCheckout() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.getSePayCheckout(widget.appointmentId);
      if (!mounted) return;
      if (result.checkout != null) {
        final data = result.checkout!;
        final alreadyPaid =
            data['isPaid'] == true ||
            data['paid'] == true ||
            (data['paymentStatus'] ?? '').toString().toLowerCase() == 'paid';
        setState(() {
          _checkout = data;
          _paid = alreadyPaid;
          _loading = false;
        });
        if (!alreadyPaid) {
          _startPolling();
        }
      } else {
        setState(() {
          _error =
              result.unavailableReason ??
              'Không thể khởi tạo phiên thanh toán SePay.';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _paid) return;
      try {
        final status = await _api.getSePayStatus(widget.appointmentId);
        if (!mounted) return;
        final isPaid =
            status['paid'] == true ||
            status['isPaid'] == true ||
            (status['paymentStatus'] ?? '').toString().toLowerCase() == 'paid';
        if (isPaid) {
          _pollTimer?.cancel();
          setState(() => _paid = true);
        }
      } catch (_) {}
    });
  }

  Future<void> _simulatePayment() async {
    setState(() => _simulating = true);
    try {
      await _api.simulateSePayPayment(widget.appointmentId);
      if (!mounted) return;
      _pollTimer?.cancel();
      setState(() {
        _paid = true;
        _simulating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanh toán SePay Sandbox thành công! Mã QR Check-in đã mở.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _simulating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label: $value'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Thanh toán VietQR SePay')),
      body: SafeArea(
        child: _loading
            ? const BmsLoadingState(message: 'Đang tạo mã VietQR SePay...')
            : _error != null
            ? Padding(
                padding: const EdgeInsets.all(18),
                child: BmsErrorState(message: _error!, onRetry: _loadCheckout),
              )
            : _paid
            ? _buildPaidSuccess()
            : _buildQrCheckout(),
      ),
    );
  }

  Widget _buildPaidSuccess() {
    final code =
        _checkout?['appointmentCode']?.toString() ??
        widget.appointmentCode ??
        widget.appointmentId;
    final amount = (_checkout?['amount'] as num?) ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: BmsSoftCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thanh toán thành công!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Lịch khám của bạn đã được xác nhận chính thức và mở khóa mã QR Check-in tại quầy lễ tân.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const Divider(height: 28),
            BmsInfoRow(label: 'Mã lịch hẹn', value: code, isMono: true, isBold: true),
            if (widget.packageName != null && widget.packageName!.isNotEmpty)
              BmsInfoRow(label: 'Gói xét nghiệm', value: widget.packageName!),
            if (amount > 0)
              BmsInfoRow(
                label: 'Số tiền đã thanh toán',
                value: BmsFormatters.currency(amount),
                isBold: true,
                valueColor: AppColors.successText,
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => AppointmentConfirmationScreen(
                        appointmentIdOrCode: widget.appointmentId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Mở phiếu xác nhận & Mã QR Check-in'),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Quay lại danh sách'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCheckout() {
    final c = _checkout!;
    final qrUrl = (c['qrUrl'] ?? c['qrCodeUrl'] ?? '').toString().trim();
    final bankCode = (c['bankCode'] ?? c['bankName'] ?? 'VietinBank').toString();
    final accountNumber = (c['accountNumber'] ?? '').toString();
    final accountName = (c['accountName'] ?? '').toString();
    final transferContent = (c['transferContent'] ?? c['description'] ?? '').toString();
    final amount = (c['amount'] as num?) ?? 0;
    final allowSandbox = c['allowSandbox'] == true || c['sandboxEnabled'] == true;
    final apptCode =
        (c['appointmentCode'] ?? widget.appointmentCode ?? widget.appointmentId)
            .toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BmsSoftCard(
            backgroundColor: AppColors.primaryLight,
            borderColor: AppColors.primaryBorder,
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Đang tự động kiểm tra giao dịch chuyển khoản mỗi 3 giây...',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          BmsSoftCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(
                  widget.packageName?.isNotEmpty == true
                      ? widget.packageName!
                      : 'Thanh toán lịch hẹn $apptCode',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  BmsFormatters.currency(amount),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 16),
                if (qrUrl.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Image.network(
                      qrUrl,
                      width: 240,
                      height: 240,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          width: 240,
                          height: 240,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (_, _, _) => const SizedBox(
                        width: 240,
                        height: 180,
                        child: Center(
                          child: Text(
                            'Không tải được ảnh VietQR.\nVui lòng chuyển khoản theo thông tin bên dưới.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Mở ứng dụng Ngân hàng quét mã VietQR trên — hệ thống tự động điền đúng số tiền & nội dung',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          BmsSoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Thông tin chuyển khoản thủ công',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                _copyRow('Ngân hàng', bankCode),
                _copyRow('Số tài khoản', accountNumber, isMono: true),
                _copyRow('Chủ tài khoản', accountName),
                _copyRow(
                  'Số tiền',
                  BmsFormatters.currency(amount),
                  copyValue: amount.round().toString(),
                  valueColor: AppColors.primary,
                ),
                _copyRow(
                  'Nội dung CK',
                  transferContent,
                  isMono: true,
                  valueColor: AppColors.dangerText,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Lưu ý: Vui lòng giữ nguyên chính xác nội dung chuyển khoản để hệ thống tự động đối soát trong vài giây.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (allowSandbox) ...[
            const SizedBox(height: 14),
            BmsSoftCard(
              backgroundColor: AppColors.successLight,
              borderColor: AppColors.successBorder,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: AppColors.successText,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Chế độ Demo Sandbox đang bật',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.successText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Bấm nút bên dưới để mô phỏng webhook ngân hàng SePay xác nhận thanh toán thành công ngay lập tức.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.successText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 46,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      onPressed: _simulating ? null : _simulatePayment,
                      icon: const Icon(Icons.verified_rounded),
                      label: Text(
                        _simulating
                            ? 'Đang xác nhận thanh toán...'
                            : 'Thanh toán nhanh (Demo Sandbox)',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _copyRow(
    String label,
    String displayValue, {
    String? copyValue,
    bool isMono = false,
    Color? valueColor,
  }) {
    final target = (copyValue ?? displayValue).trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue.isEmpty ? '—' : displayValue,
              style: TextStyle(
                fontSize: 13,
                fontFamily: isMono ? 'monospace' : null,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
          if (target.isNotEmpty)
            IconButton(
              onPressed: () => _copy(label, target),
              icon: const Icon(Icons.copy_rounded, size: 17),
              color: AppColors.primary,
              tooltip: 'Sao chép $label',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
