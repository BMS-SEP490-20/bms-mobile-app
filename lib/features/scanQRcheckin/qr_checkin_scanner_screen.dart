import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/bms_ui_kit.dart';
import '../reception_portal/data/reception_portal_api.dart';

/// Camera QR Code Check-in Scanner for Receptionist Role.
/// Extracts appointment code/ID from BMS QR JSON or raw string, previews via
/// `GET /api/appointments/{codeOrId}`, confirms check-in via `PUT /api/appointments/{id}`,
/// and optionally issues a phlebotomy queue ticket via `POST /api/reception/queue/issue`.
class QrCheckinScannerScreen extends StatefulWidget {
  const QrCheckinScannerScreen({super.key});

  @override
  State<QrCheckinScannerScreen> createState() => _QrCheckinScannerScreenState();
}

class _QrCheckinScannerScreenState extends State<QrCheckinScannerScreen> {
  final ReceptionPortalApi _api = const ReceptionPortalApi();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isProcessing = false;
  bool _isTorchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        _processScannedCode(rawValue.trim());
        break;
      }
    }
  }

  String _extractAppointmentCodeOrId(String raw) {
    try {
      if (raw.startsWith('{') && raw.endsWith('}')) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final id = decoded['appointmentCode'] ??
              decoded['code'] ??
              decoded['appointmentId'] ??
              decoded['id'] ??
              decoded['c'];
          if (id != null && id.toString().trim().isNotEmpty) {
            return id.toString().trim();
          }
        }
      }
    } catch (_) {}

    if (raw.contains('/')) {
      final parts = raw.split('/');
      final last = parts.lastWhere(
        (p) => p.trim().isNotEmpty,
        orElse: () => '',
      );
      if (last.isNotEmpty) return last.trim();
    }
    return raw.trim();
  }

  Future<void> _processScannedCode(String rawCode) async {
    setState(() => _isProcessing = true);
    await _scannerController.stop();

    final codeOrId = _extractAppointmentCodeOrId(rawCode);
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: BmsSoftCard(
          padding: EdgeInsets.all(24),
          child: BmsLoadingState(message: 'Đang kiểm tra mã lịch hẹn...'),
        ),
      ),
    );

    try {
      final apt = await _api.getAppointmentByCodeOrId(codeOrId);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await _showCheckinPreviewSheet(apt);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await _showErrorDialog(
        e.toString().replaceFirst('BmsApiException: ', ''),
      );
    }
  }

  Future<void> _showCheckinPreviewSheet(Map<String, dynamic> apt) async {
    final id = (apt['id'] ?? apt['appointmentId'] ?? '').toString();
    final code = (apt['appointmentCode'] ?? apt['code'] ?? id).toString();
    final patientId = (apt['patientId'] ?? '').toString();
    final patientName = (apt['patientName'] ??
            apt['guestName'] ??
            'Bệnh nhân')
        .toString();
    final phone = (apt['patientPhone'] ?? apt['guestPhone'] ?? '').toString();
    final pkgName = (apt['packageName'] ??
            (apt['packages'] is List && (apt['packages'] as List).isNotEmpty
                ? ((apt['packages'] as List).first['name'] ?? '')
                : 'Khám & Xét nghiệm máu'))
        .toString();
    final dateStr = BmsFormatters.date(
      apt['appointmentDate'] ?? apt['appointmentTime'],
    );
    final slot = (apt['slotTime'] ??
            BmsFormatters.time(apt['appointmentTime']))
        .toString();
    final status = (apt['status'] ?? 'Confirmed').toString();
    final alreadyCheckedIn =
        status.toLowerCase().replaceAll('_', '') == 'checkedin';

    bool issueQueue = true;
    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: alreadyCheckedIn
                          ? AppColors.successLight
                          : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      alreadyCheckedIn
                          ? Icons.check_circle_outline_rounded
                          : Icons.qr_code_scanner_rounded,
                      color: alreadyCheckedIn
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alreadyCheckedIn
                              ? 'Lịch hẹn đã Check-in'
                              : 'Xác nhận tiếp đón QR',
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Mã lịch hẹn: $code',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  BmsStatusPill(status: status),
                ],
              ),
              const Divider(height: 24),
              BmsInfoRow(
                label: 'Họ tên bệnh nhân',
                value: patientName,
                isBold: true,
              ),
              if (phone.isNotEmpty)
                BmsInfoRow(label: 'Số điện thoại', value: phone),
              BmsInfoRow(label: 'Dịch vụ / Gói XN', value: pkgName),
              BmsInfoRow(label: 'Thời gian hẹn', value: '$dateStr · $slot'),
              if (!alreadyCheckedIn) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: AppColors.primary,
                  value: issueQueue,
                  title: const Text(
                    'Đồng thời cấp số thứ tự lấy mẫu xét nghiệm',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onChanged: (val) =>
                      setSheetState(() => issueQueue = val ?? true),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: submitting || id.isEmpty
                      ? null
                      : () async {
                          setSheetState(() => submitting = true);
                          try {
                            await _api.checkInAppointment(
                              id,
                              notes: 'Check-in QR trên ứng dụng Lễ tân',
                            );
                            String? ticketNum;
                            if (issueQueue) {
                              try {
                                final ticket = await _api.issueQueueTicket(
                                  patientId: patientId.isEmpty
                                      ? null
                                      : patientId,
                                  patientName: patientName,
                                  packageName: pkgName,
                                  isWalkIn: false,
                                  priority: 'Routine',
                                );
                                ticketNum =
                                    ticket['ticketNumber']?.toString();
                              } catch (_) {}
                            }
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ticketNum != null && ticketNum.isNotEmpty
                                      ? 'Đã check-in $code · Số thứ tự: $ticketNum'
                                      : 'Đã xác nhận check-in lịch hẹn $code.',
                                ),
                              ),
                            );
                            Navigator.pop(context, true);
                          } catch (e) {
                            setSheetState(() => submitting = false);
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst(
                                    'BmsApiException: ',
                                    '',
                                  ),
                                ),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.how_to_reg_rounded, size: 19),
                  label: Text(
                    submitting
                        ? 'Đang xác nhận...'
                        : 'Xác nhận Check-in ngay',
                  ),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng & Quét mã tiếp'),
              ),
            ],
          ),
        ),
      ),
    );

    if (mounted) {
      _resumeScanning();
    }
  }

  Future<void> _showErrorDialog(String msg) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Không thể kiểm tra mã QR'),
        content: Text(msg),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Quét lại'),
          ),
        ],
      ),
    );
    if (mounted) _resumeScanning();
  }

  void _resumeScanning() {
    setState(() => _isProcessing = false);
    _scannerController.start();
  }

  Future<void> _showManualInputDialog() async {
    final codeCtrl = TextEditingController();
    final submitted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập mã lịch hẹn thủ công'),
        content: TextField(
          controller: codeCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Mã cuộc hẹn (APT-...)',
            hintText: 'APT-2026...',
            prefixIcon: Icon(Icons.tag_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, codeCtrl.text.trim()),
            child: const Text('Tra cứu'),
          ),
        ],
      ),
    );
    if (submitted != null && submitted.isNotEmpty) {
      await _processScannedCode(submitted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Quét QR Check-in',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Đèn chiếu sáng',
            onPressed: () async {
              await _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? AppColors.warning : Colors.white,
            ),
          ),
          IconButton(
            tooltip: 'Đổi camera',
            onPressed: () async {
              await _scannerController.switchCamera();
              setState(() {
                _cameraFacing = _cameraFacing == CameraFacing.back
                    ? CameraFacing.front
                    : CameraFacing.back;
              });
            },
            icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Nhập mã thủ công',
            onPressed: _showManualInputDialog,
            icon: const Icon(Icons.keyboard_outlined, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _scannerController, onDetect: _onDetect),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.primary, width: 2.5),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: BmsSoftCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Đưa mã QR lịch hẹn vào khung ngắm camera để tự động nhận diện',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _showManualInputDialog,
                    icon: const Icon(Icons.keyboard_rounded, size: 18),
                    label: const Text('Nhập mã lịch hẹn thủ công'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
