import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bms_ui_kit.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment_confirmation_model.dart';

/// Appointment Confirmation & Instant QR Check-in Pass Screen (`GET /api/appointments/{id}/confirmation`).
class AppointmentConfirmationScreen extends StatefulWidget {
  final String appointmentCode;
  final AppointmentRepository? repository;

  const AppointmentConfirmationScreen({
    super.key,
    required this.appointmentCode,
    this.repository,
  });

  @override
  State<AppointmentConfirmationScreen> createState() =>
      _AppointmentConfirmationScreenState();
}

class _AppointmentConfirmationScreenState
    extends State<AppointmentConfirmationScreen> {
  late final AppointmentRepository _repo;
  AppointmentConfirmationModel? _data;
  bool _isLoading = true;
  bool _isResending = false;
  String? _bannerMessage;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? AppointmentRepository();
    _loadConfirmation();
  }

  Future<void> _loadConfirmation() async {
    setState(() => _isLoading = true);
    try {
      final res = await _repo.getAppointmentConfirmation(
        widget.appointmentCode,
      );
      if (!mounted) return;
      setState(() {
        _data = AppointmentConfirmationModel.fromJson(res);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _data = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleResendEmail() async {
    setState(() => _isResending = true);
    try {
      await _repo.sendNotification(
        _data?.appointmentId ?? widget.appointmentCode,
        channel: 1,
        type: 1,
      );
      if (!mounted) return;
      setState(() {
        _bannerMessage = 'Đã gửi lại phiếu xác nhận lịch hẹn qua Email.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bannerMessage = 'Không thể gửi lại email xác nhận lúc này.';
      });
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Phiếu xác nhận & Mã QR')),
      body: _isLoading
          ? const BmsLoadingState(message: 'Đang tải thông tin phiếu hẹn...')
          : _data == null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: BmsErrorState(
                    message:
                        'Không tìm thấy thông tin xác nhận cho mã ${widget.appointmentCode}.',
                    onRetry: _loadConfirmation,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    if (_bannerMessage != null) ...[
                      BmsSoftCard(
                        backgroundColor: AppColors.primaryLight,
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _bannerMessage!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    BmsSoftCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'THẺ CHECK-IN ĐIỆN TỬ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              BmsStatusPill(status: _data!.status),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: QrImageView(
                              data: _data!.qrCodeData.isNotEmpty
                                  ? _data!.qrCodeData
                                  : _data!.appointmentCode,
                              size: 190,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _data!.appointmentCode,
                            style: const TextStyle(
                              fontSize: 16,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Divider(height: 24),
                          BmsInfoRow(
                            label: 'Bệnh nhân',
                            value: _data!.patientName,
                            isBold: true,
                          ),
                          BmsInfoRow(
                            label: 'Gói xét nghiệm',
                            value: _data!.packageName,
                          ),
                          if (_data!.doctorName != null &&
                              _data!.doctorName!.isNotEmpty)
                            BmsInfoRow(
                              label: 'Bác sĩ khám',
                              value: _data!.doctorName!,
                            ),
                          BmsInfoRow(
                            label: 'Thời gian hẹn',
                            value:
                                '${_data!.dateFormatted} · ${_data!.timeFormatted}',
                          ),
                          BmsInfoRow(
                            label: 'Địa điểm',
                            value: _data!.location,
                          ),
                          BmsInfoRow(
                            label: 'Chi phí dự kiến',
                            value: BmsFormatters.currency(_data!.price),
                          ),
                        ],
                      ),
                    ),
                    if (_data!.fastingInstructions.isNotEmpty) ...[
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
                                    'Hướng dẫn chuẩn bị trước lấy mẫu',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.warningText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _data!.fastingInstructions,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.warningText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _isResending ? null : _handleResendEmail,
                      icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                      label: Text(
                        _isResending
                            ? 'Đang gửi email...'
                            : 'Gửi lại phiếu hẹn qua Email',
                      ),
                    ),
                  ],
                ),
    );
  }
}
