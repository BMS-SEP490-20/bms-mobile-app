import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:bms_mobile_app/services/appointment_service.dart';

/// Mobile QR Code Scanner Screen for express patient check-in.
/// 
/// Feature Task: Scan QR Check-in (Mobile).
/// 
/// Employs `mobile_scanner` to capture QR barcodes via the device camera,
/// decodes BMS check-in JSON or plain appointment codes, validates the appointment,
/// previews patient and appointment details in a modal sheet, and triggers the
/// check-in API to transition status to `checked_in`.
/// Also provides flash/torch toggle, front/rear camera switching, and a manual code entry dialog fallback.
class QrCheckinScannerScreen extends StatefulWidget {
  /// Creates a [QrCheckinScannerScreen] widget.
  const QrCheckinScannerScreen({super.key});

  @override
  State<QrCheckinScannerScreen> createState() => _QrCheckinScannerScreenState();
}

class _QrCheckinScannerScreenState extends State<QrCheckinScannerScreen> {
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

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        _processScannedCode(rawValue.trim());
        break;
      }
    }
  }

  String _extractAppointmentId(String raw) {
    // 1. Attempt to parse BMS check-in JSON format
    try {
      if (raw.startsWith('{') && raw.endsWith('}')) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final id = decoded['id'] ?? decoded['appointmentId'] ?? decoded['c'] ?? decoded['appointmentCode'];
          if (id != null) return id.toString();
        }
      }
    } catch (_) {}

    // 2. Extract code if QR data is a URL
    if (raw.contains('/')) {
      final parts = raw.split('/');
      final last = parts.lastWhere((p) => p.trim().isNotEmpty, orElse: () => '');
      if (last.isNotEmpty) return last;
    }

    // 3. Fallback to raw code string
    return raw;
  }

  /// Decodes, validates, and processes a scanned QR code payload.
  /// Feature Task: Scan QR Check-in (Mobile).
  /// 
  /// Parses either BMS JSON payload (`{"t":"checkin","id":"..."}`) or plain appointment code,
  /// queries appointment details via [AppointmentService.getAppointmentById], and displays
  /// a bottom preview sheet allowing the user to confirm check-in.
  Future<void> _processScannedCode(String rawCode) async {
    setState(() => _isProcessing = true);
    _scannerController.stop();

    final appointmentId = _extractAppointmentId(rawCode);

    // Display loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Đang kiểm tra lịch hẹn...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    final res = await AppointmentService.getAppointmentById(appointmentId);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog

    if (!res['success']) {
      // Fallback to searching appointment list if not found by ID
      final allRes = await AppointmentService.getAllAppointments(page: 1, pageSize: 100);
      Map<String, dynamic>? found;
      if (allRes['success']) {
        final List all = allRes['data'];
        found = all.firstWhere(
          (item) =>
              item['appointmentId']?.toString() == appointmentId ||
              item['id']?.toString() == appointmentId ||
              item['appointmentCode']?.toString() == appointmentId,
          orElse: () => null,
        );
      }

      if (found == null) {
        _showErrorDialog('Không tìm thấy cuộc hẹn với mã "$appointmentId". Vui lòng kiểm tra lại!');
        return;
      }

      _showCheckinConfirmSheet(found);
      return;
    }

    final appointment = res['data'];
    _showCheckinConfirmSheet(appointment);
  }

  void _showCheckinConfirmSheet(Map<String, dynamic> apt) {
    final aptId = apt['appointmentId'] ?? apt['id'] ?? 'N/A';
    final patientName = apt['guestName'] ?? apt['patientName'] ?? apt['patient']?['fullname'] ?? apt['createdBy'] ?? 'Bệnh nhân';
    final status = apt['status']?.toString().toLowerCase() ?? 'pending';
    final type = apt['appointmentType'] ?? apt['testPackageName'] ?? 'Xét nghiệm máu';
    final time = apt['appointmentTime'] != null ? apt['appointmentTime'].toString().replaceAll('T', ' ').substring(0, 16) : 'Chưa xếp giờ';

    final isAlreadyCheckedIn = status == 'checked_in';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: isAlreadyCheckedIn ? const Color(0xFF198754).withValues(alpha: 0.15) : const Color(0xFF0D6EFD).withValues(alpha: 0.15),
                    child: Icon(
                      isAlreadyCheckedIn ? Icons.check_circle : Icons.qr_code_scanner,
                      color: isAlreadyCheckedIn ? const Color(0xFF198754) : const Color(0xFF0D6EFD),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAlreadyCheckedIn ? 'Lịch Hẹn Đã Check-in' : 'Xác Nhận Check-in',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isAlreadyCheckedIn ? const Color(0xFF198754) : const Color(0xFF212529),
                          ),
                        ),
                        Text('Mã cuộc hẹn: $aptId', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),

              // Appointment details
              _buildInfoRow('Bệnh nhân / Người khám:', patientName, isBold: true),
              const SizedBox(height: 8),
              if (apt['guestPhone'] != null) ...[
                _buildInfoRow('Số điện thoại:', apt['guestPhone'].toString()),
                const SizedBox(height: 8),
              ],
              _buildInfoRow('Gói / Loại khám:', type),
              const SizedBox(height: 8),
              _buildInfoRow('Thời gian hẹn:', time),
              const SizedBox(height: 8),
              _buildInfoRow('Trạng thái hiện tại:', status.toUpperCase()),

              const SizedBox(height: 24),

              if (isAlreadyCheckedIn)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF198754).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF198754).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF198754)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cuộc hẹn này đã được check-in thành công!',
                          style: TextStyle(color: Color(0xFF198754), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _executeCheckin(aptId.toString()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF198754),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                  label: const Text(
                    'Xác Nhận Check-in Ngay',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),

              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _resumeScanning();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Đóng & Quét Tiếp', style: TextStyle(color: Color(0xFF6C757D))),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _resumeScanning();
    });
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: const Color(0xFF212529),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _executeCheckin(String aptId) async {
    Navigator.pop(context); // Close bottom sheet

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Đang thực hiện check-in...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    final res = await AppointmentService.checkInAppointment(aptId);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog

    if (res['success'] == true) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.check_circle, color: Color(0xFF198754), size: 56),
          title: const Text('Check-in Thành Công!', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF198754))),
          content: Text(
            'Lịch hẹn $aptId đã được đánh dấu là "checked_in". Bệnh nhân đã sẵn sàng để lấy mẫu xét nghiệm.',
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _resumeScanning();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF198754),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Quét tiếp', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      _showErrorDialog(res['message'] ?? 'Lỗi thực hiện check-in');
    }
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.error_outline, color: Color(0xFFDC3545), size: 50),
        title: const Text('Thông Báo', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(msg, textAlign: TextAlign.center),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resumeScanning();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6EFD)),
            child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _resumeScanning() {
    setState(() => _isProcessing = false);
    _scannerController.start();
  }

  void _showManualInputDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.keyboard, color: Color(0xFF0D6EFD)),
            SizedBox(width: 8),
            Text('Nhập Mã Lịch Hẹn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nhập mã lịch hẹn (ví dụ: APP576256) nếu camera không quét được QR:'),
            const SizedBox(height: 14),
            TextField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Mã cuộc hẹn',
                hintText: 'Nhập mã...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.numbers),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              final code = textController.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                _processScannedCode(code);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6EFD)),
            child: const Text('Kiểm Tra & Check-in', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét QR Check-in', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off, color: _isTorchOn ? Colors.amber : Colors.white),
            tooltip: 'Đèn Flash',
            onPressed: () async {
              await _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            icon: Icon(_cameraFacing == CameraFacing.front ? Icons.camera_front : Icons.camera_rear),
            tooltip: 'Đổi camera',
            onPressed: () async {
              await _scannerController.switchCamera();
              setState(() {
                _cameraFacing = _cameraFacing == CameraFacing.back ? CameraFacing.front : CameraFacing.back;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_outlined),
            tooltip: 'Nhập mã thủ công',
            onPressed: _showManualInputDialog,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Custom Scanner Overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF0D6EFD), width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 4), left: BorderSide(color: Colors.white, width: 4)))),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 4), right: BorderSide(color: Colors.white, width: 4)))),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 4), left: BorderSide(color: Colors.white, width: 4)))),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 4), right: BorderSide(color: Colors.white, width: 4)))),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Instruction Card
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Hướng camera về phía mã QR trên phiếu hẹn hoặc ứng dụng bệnh nhân',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _showManualInputDialog,
                    icon: const Icon(Icons.edit_note, color: Color(0xFF0D6EFD)),
                    label: const Text('Nhập mã cuộc hẹn thủ công', style: TextStyle(color: Color(0xFF0D6EFD), fontWeight: FontWeight.bold)),
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
