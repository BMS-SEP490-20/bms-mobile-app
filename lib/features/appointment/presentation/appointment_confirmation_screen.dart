import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bms_ui_kit.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment_confirmation_model.dart';
import '../../patient_portal/presentation/screens/sepay_checkout_screen.dart';

/// 1-to-1 Appointment Confirmation & Check-in QR Screen matching Web `AppointmentConfirmationPage.jsx`:
/// - Calls `GET /api/appointments/{id}/confirmation`
/// - Unlocks QR Check-in ONLY when appointment is paid/confirmed (`isQrUnlocked`)
/// - When Pending/Unpaid: guides patient directly into `SePayCheckoutScreen`
/// - Zero Receptionist-only `/notify` 403 call, zero SMS UI.
class AppointmentConfirmationScreen extends StatefulWidget {
  final String appointmentIdOrCode;

  const AppointmentConfirmationScreen({
    super.key,
    required this.appointmentIdOrCode,
  });

  @override
  State<AppointmentConfirmationScreen> createState() =>
      _AppointmentConfirmationScreenState();
}

class _AppointmentConfirmationScreenState
    extends State<AppointmentConfirmationScreen> {
  final AppointmentRepository _repo = AppointmentRepository();

  bool _loading = true;
  String? _error;
  AppointmentConfirmationModel? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _repo.getAppointmentConfirmation(
        widget.appointmentIdOrCode,
      );
      if (!mounted) return;
      setState(() {
        _data = AppointmentConfirmationModel.fromJson(raw);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Phiếu xác nhận lịch hẹn')),
      body: SafeArea(
        child: _loading
            ? const BmsLoadingState(message: 'Đang tải phiếu xác nhận...')
            : _error != null
            ? Padding(
                padding: const EdgeInsets.all(18),
                child: BmsErrorState(message: _error!, onRetry: _load),
              )
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BmsSoftCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MÃ LỊCH HẸN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            d.appointmentCode.isNotEmpty
                                ? d.appointmentCode
                                : d.appointmentId,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    BmsStatusPill(status: d.status),
                  ],
                ),
                const Divider(height: 24),
                if (d.isQrUnlocked) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: QrImageView(
                      data: d.qrCodeData.isNotEmpty
                          ? d.qrCodeData
                          : d.appointmentCode,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Đưa mã QR này tại Quầy Lễ tân để Check-in và lấy số thứ tự tự động',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.successText,
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.warningBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.lock_clock_outlined,
                              color: AppColors.warningText,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Mã QR Check-in sẽ mở ngay sau khi thanh toán',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.warningText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Lịch hẹn đang được giữ chỗ trong 15 phút. Hoàn tất chuyển khoản VietQR SePay để xác nhận chính thức.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warningText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () async {
                            final paid = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => SePayCheckoutScreen(
                                  appointmentId: d.appointmentId,
                                  appointmentCode: d.appointmentCode,
                                  packageName: d.packageName,
                                ),
                              ),
                            );
                            if (paid == true && mounted) {
                              _load();
                            }
                          },
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('Thanh toán VietQR SePay ngay'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          BmsSoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chi tiết lịch hẹn',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                BmsInfoRow(label: 'Bệnh nhân', value: d.patientName),
                BmsInfoRow(label: 'Gói xét nghiệm', value: d.packageName),
                if (d.price > 0)
                  BmsInfoRow(
                    label: 'Chi phí dịch vụ',
                    value: BmsFormatters.currency(d.price),
                    isBold: true,
                    valueColor: AppColors.primary,
                  ),
                BmsInfoRow(
                  label: 'Ngày khám',
                  value: d.dateFormatted,
                  isBold: true,
                ),
                BmsInfoRow(
                  label: 'Khung giờ',
                  value: d.timeFormatted,
                  isBold: true,
                ),
                if (d.doctorName != null && d.doctorName!.isNotEmpty)
                  BmsInfoRow(label: 'Bác sĩ phụ trách', value: d.doctorName!),
                if (d.location.isNotEmpty)
                  BmsInfoRow(label: 'Địa điểm', value: d.location),
                BmsInfoRow(
                  label: 'Thanh toán',
                  value: d.paymentStatus.toLowerCase() == 'paid'
                      ? 'Đã thanh toán'
                      : 'Chờ thanh toán',
                  valueColor: d.paymentStatus.toLowerCase() == 'paid'
                      ? AppColors.successText
                      : AppColors.warningText,
                ),
              ],
            ),
          ),
          if (d.fastingInstructions.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            BmsSoftCard(
              backgroundColor: AppColors.warningLight,
              borderColor: AppColors.warningBorder,
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warningText,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hướng dẫn chuẩn bị trước khi lấy mẫu',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warningText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d.fastingInstructions,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.warningText,
                            height: 1.4,
                          ),
                        ),
                      ],
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
}
