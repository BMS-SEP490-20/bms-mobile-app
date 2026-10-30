import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:bms_mobile_app/services/appointment_service.dart';
import 'appointment_form_screen.dart';
import 'qr_checkin_scanner_screen.dart';

/// Screen for viewing, filtering, searching, and managing test appointments on mobile.
/// 
/// Feature Tasks:
/// - Create Appointments (Mobile) (via FloatingActionButton navigating to [AppointmentFormScreen])
/// - Update Appointments (Mobile) (via edit button on each card)
/// - Delete Appointments (Mobile) (via delete confirmation dialog)
/// - Scan QR Check-in (Mobile) (via personal QR code display modal & AppBar scanner trigger)
class AppointmentsListScreen extends StatefulWidget {
  /// Creates an [AppointmentsListScreen] widget.
  const AppointmentsListScreen({super.key});

  @override
  State<AppointmentsListScreen> createState() => _AppointmentsListScreenState();
}

class _AppointmentsListScreenState extends State<AppointmentsListScreen> {
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  String _statusFilter = 'all';
  String _searchQuery = '';

  final List<Map<String, String>> _filterOptions = [
    {'value': 'all', 'label': 'Tất cả'},
    {'value': 'pending', 'label': 'Chờ xác nhận'},
    {'value': 'scheduled', 'label': 'Đã lên lịch'},
    {'value': 'confirmed', 'label': 'Đã xác nhận'},
    {'value': 'checked_in', 'label': 'Đã check-in'},
    {'value': 'completed', 'label': 'Hoàn thành'},
    {'value': 'cancelled', 'label': 'Đã hủy'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);

    final res = await AppointmentService.getAllAppointments(page: 1, pageSize: 100);

    if (mounted) {
      setState(() {
        if (res['success'] == true) {
          _appointments = List<Map<String, dynamic>>.from(res['data'] ?? []);
        } else {
          _appointments = [];
        }
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredAppointments {
    return _appointments.where((apt) {
      final status = (apt['status'] ?? '').toString().toLowerCase();
      if (_statusFilter != 'all' && status != _statusFilter) {
        return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final id = (apt['appointmentId'] ?? apt['id'] ?? '').toString().toLowerCase();
        final guest = (apt['guestName'] ?? '').toString().toLowerCase();
        final phone = (apt['guestPhone'] ?? '').toString().toLowerCase();
        final type = (apt['appointmentType'] ?? '').toString().toLowerCase();
        final pkg = (apt['testPackageName'] ?? apt['packageName'] ?? '').toString().toLowerCase();

        return id.contains(q) || guest.contains(q) || phone.contains(q) || type.contains(q) || pkg.contains(q);
      }
      return true;
    }).toList();
  }

  /// Prompts a confirmation dialog and deletes an appointment.
  /// Feature Task: Delete Appointments (Mobile).
  /// 
  /// Displays an [AlertDialog] asking the user to confirm permanent deletion.
  /// If confirmed, invokes [AppointmentService.deleteAppointment], shows a feedback [SnackBar],
  /// and automatically reloads the appointments list.
  Future<void> _handleDeleteAppointment(String aptId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Color(0xFFDC3545)),
            SizedBox(width: 8),
            Text('Xác Nhận Xóa', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Bạn có chắc chắn muốn xóa cuộc hẹn "$aptId"? Thao tác này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC3545)),
            child: const Text('Xóa ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await AppointmentService.deleteAppointment(aptId);

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa cuộc hẹn thành công!'),
          backgroundColor: Color(0xFF198754),
        ),
      );
      _loadAppointments();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Không thể xóa cuộc hẹn'),
          backgroundColor: const Color(0xFFDC3545),
        ),
      );
    }
  }

  /// Displays the check-in QR code modal for an individual appointment.
  /// Feature Task: Scan QR Check-in (Mobile).
  /// 
  /// Generates a standardized JSON payload encoded into a QR code via `qr_flutter`
  /// that patients can present to the reception desk or scan at automated kiosks.
  void _showAppointmentQrDialog(Map<String, dynamic> apt) {
    final aptId = apt['appointmentId'] ?? apt['id'] ?? 'N/A';
    final patientName = apt['guestName'] ?? apt['patientName'] ?? 'Bệnh nhân';
    final time = apt['appointmentTime'] != null ? apt['appointmentTime'].toString().replaceAll('T', ' ').substring(0, 16) : '';
    final type = apt['appointmentType'] ?? apt['testPackageName'] ?? 'Xét nghiệm máu';

    final qrData = jsonEncode({
      't': 'checkin',
      'id': aptId,
      'c': aptId,
      'n': patientName,
      's': type,
      'tm': time,
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Column(
            children: [
              const Icon(Icons.qr_code_2, color: Color(0xFF0D6EFD), size: 36),
              const SizedBox(height: 6),
              const Text('Mã QR Check-in', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('Mã: $aptId', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              patientName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(type, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(time, style: const TextStyle(color: Color(0xFF0D6EFD), fontWeight: FontWeight.bold, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF0D6EFD).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF0D6EFD)),
                  SizedBox(width: 6),
                  Text('Đưa mã này tại quầy tiếp đón để check-in', style: TextStyle(fontSize: 11, color: Color(0xFF0D6EFD))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Đóng'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'checked_in':
        return const Color(0xFF0D6EFD); // Blue
      case 'completed':
        return const Color(0xFF198754); // Green
      case 'scheduled':
      case 'confirmed':
        return const Color(0xFF0DCAF0); // Cyan/Teal
      case 'cancelled':
      case 'cancelled_by_patient':
        return const Color(0xFFDC3545); // Red
      case 'pending':
      default:
        return const Color(0xFFFFC107); // Amber/Yellow
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'checked_in':
        return 'Đã check-in';
      case 'completed':
        return 'Hoàn thành';
      case 'scheduled':
        return 'Đã lên lịch';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'cancelled':
      case 'cancelled_by_patient':
        return 'Đã hủy';
      case 'pending':
      default:
        return 'Chờ xác nhận';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAppointments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Lịch Hẹn', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF212529),
        elevation: 1,
        actions: [
          // Task 4: Scan QR Check-in Shortcut from AppBar
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF0D6EFD)),
            tooltip: 'Quét QR Check-in',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrCheckinScannerScreen()),
              );
              _loadAppointments();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadAppointments,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo mã, tên, số điện thoại...',
                    prefixIcon: const Icon(Icons.search, size: 22, color: Color(0xFF0D6EFD)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filterOptions.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (ctx, idx) {
                      final opt = _filterOptions[idx];
                      final isSelected = _statusFilter == opt['value'];
                      return ChoiceChip(
                        label: Text(opt['label']!),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0D6EFD),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _statusFilter = opt['value']!);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Count header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Danh sách cuộc hẹn (${filtered.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF495057)),
                ),
                // Quick QR check-in scan button
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QrCheckinScannerScreen()),
                    );
                    _loadAppointments();
                  },
                  icon: const Icon(Icons.qr_code_scanner, size: 16, color: Color(0xFF0D6EFD)),
                  label: const Text('Quét QR Check-in', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0D6EFD))),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ),

          // List body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('Chưa có lịch hẹn nào', style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('Nhấn vào nút "+" bên dưới để tạo lịch hẹn mới', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAppointments,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, idx) {
                            final apt = filtered[idx];
                            final aptId = apt['appointmentId'] ?? apt['id'] ?? 'N/A';
                            final guestName = apt['guestName'] ?? apt['patientName'] ?? 'Bệnh nhân';
                            final phone = apt['guestPhone'] ?? '';
                            final type = apt['appointmentType'] ?? apt['testPackageName'] ?? 'Xét nghiệm máu';
                            final time = apt['appointmentTime'] != null ? apt['appointmentTime'].toString().replaceAll('T', ' ').substring(0, 16) : 'Chưa xếp giờ';
                            final status = apt['status']?.toString();
                            final statusColor = _getStatusColor(status);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Code and Status Badge
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0D6EFD).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            aptId,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D6EFD)),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            _getStatusText(status),
                                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 18),

                                    // Row 2: Patient Info
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: Colors.grey.shade100,
                                          child: const Icon(Icons.person, color: Color(0xFF0D6EFD), size: 22),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(guestName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                              if (phone.isNotEmpty) Text('SĐT: $phone', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Row 3: Service & Time
                                    Row(
                                      children: [
                                        const Icon(Icons.biotech, size: 16, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(type, style: const TextStyle(fontSize: 13, color: Color(0xFF495057))),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Text(time, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF212529))),
                                      ],
                                    ),

                                    const Divider(height: 20),

                                    // Row 4: Actions (QR Code, Edit, Delete)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // View QR check-in code button
                                        OutlinedButton.icon(
                                          onPressed: () => _showAppointmentQrDialog(apt),
                                          icon: const Icon(Icons.qr_code, size: 16),
                                          label: const Text('Mã QR', style: TextStyle(fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            side: const BorderSide(color: Color(0xFF0D6EFD)),
                                            foregroundColor: const Color(0xFF0D6EFD),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Task 2: Update Appointments (Mobile)
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            final updated = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => AppointmentFormScreen(appointmentToEdit: apt),
                                              ),
                                            );
                                            if (updated == true) _loadAppointments();
                                          },
                                          icon: const Icon(Icons.edit, size: 16),
                                          label: const Text('Sửa', style: TextStyle(fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            side: const BorderSide(color: Color(0xFF198754)),
                                            foregroundColor: const Color(0xFF198754),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Task 3: Delete Appointments (Mobile)
                                        IconButton(
                                          onPressed: () => _handleDeleteAppointment(aptId),
                                          icon: const Icon(Icons.delete_outline, color: Color(0xFFDC3545), size: 20),
                                          tooltip: 'Xóa lịch hẹn',
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),

      // Task 1: Create Appointments (Mobile) Floating Action Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AppointmentFormScreen()),
          );
          if (created == true) _loadAppointments();
        },
        backgroundColor: const Color(0xFF0D6EFD),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tạo Lịch Hẹn', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}
