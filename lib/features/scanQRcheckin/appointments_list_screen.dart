import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/bms_ui_kit.dart';
import '../appointment/presentation/book_appointment_screen.dart';
import '../reception_portal/data/reception_portal_api.dart';
import 'qr_checkin_scanner_screen.dart';

/// Appointments Management & QR Check-in Screen backed by real `/api/appointments`.
class AppointmentsListScreen extends StatefulWidget {
  const AppointmentsListScreen({super.key});

  @override
  State<AppointmentsListScreen> createState() => _AppointmentsListScreenState();
}

class _AppointmentsListScreenState extends State<AppointmentsListScreen> {
  final ReceptionPortalApi _api = const ReceptionPortalApi();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = '';

  static const List<({String key, String label})> _filters = [
    (key: '', label: 'Tất cả'),
    (key: 'Confirmed', label: 'Đã xác nhận'),
    (key: 'CheckedIn', label: 'Đã check-in'),
    (key: 'Completed', label: 'Hoàn thành'),
    (key: 'Cancelled', label: 'Đã hủy'),
  ];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.getAppointments(
        keyword: _searchCtrl.text,
        status: _statusFilter.isEmpty ? null : _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _appointments = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('BmsApiException: ', '');
        _loading = false;
      });
    }
  }

  void _showQrModal(Map<String, dynamic> apt) {
    final id = (apt['id'] ?? '').toString();
    final code = (apt['appointmentCode'] ?? id).toString();
    final patientName = (apt['patientName'] ?? 'Bệnh nhân').toString();
    final payload = jsonEncode({'appointmentCode': code, 'id': id});

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mã QR lịch hẹn $code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: payload, size: 190),
            const SizedBox(height: 10),
            Text(
              patientName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Danh sách lịch hẹn'),
        actions: [
          IconButton(
            tooltip: 'Quét QR Check-in',
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const QrCheckinScannerScreen(),
                ),
              );
              if (changed == true) _loadAppointments();
            },
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const BookAppointmentScreen()),
          );
          _loadAppointments();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Đặt lịch mới'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadAppointments,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
          children: [
            BmsSearchFilterBar(
              controller: _searchCtrl,
              hintText: 'Tìm theo mã hẹn, họ tên, số điện thoại...',
              onSubmitted: (_) => _loadAppointments(),
              onClear: _loadAppointments,
              filterChips: _filters.map((f) {
                return BmsFilterChipItem(
                  key: f.key,
                  label: f.label,
                  selected: _statusFilter == f.key,
                  onSelected: () {
                    setState(() => _statusFilter = f.key);
                    _loadAppointments();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const BmsLoadingState(message: 'Đang tải danh sách lịch hẹn...')
            else if (_error != null)
              BmsErrorState(message: _error!, onRetry: _loadAppointments)
            else if (_appointments.isEmpty)
              const BmsEmptyState(
                icon: Icons.event_busy_outlined,
                title: 'Không có lịch hẹn nào',
                subtitle: 'Nhấn "Đặt lịch mới" để đăng ký khung giờ khám.',
              )
            else
              ..._appointments.map((apt) {
                final id = (apt['id'] ?? '').toString();
                final code = (apt['appointmentCode'] ?? id).toString();
                final name = (apt['patientName'] ?? 'Bệnh nhân').toString();
                final dateStr = BmsFormatters.date(
                  apt['appointmentDate'] ?? apt['appointmentTime'],
                );
                final slot = (apt['slotTime'] ??
                        BmsFormatters.time(apt['appointmentTime']))
                    .toString();
                final status = (apt['status'] ?? 'Confirmed').toString();

                return BmsSoftCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          BmsStatusPill(status: status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      BmsInfoRow(label: 'Mã hẹn', value: code, isMono: true),
                      BmsInfoRow(label: 'Khung giờ', value: '$dateStr · $slot'),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _showQrModal(apt),
                          icon: const Icon(Icons.qr_code_rounded, size: 17),
                          label: const Text('Xem QR'),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
