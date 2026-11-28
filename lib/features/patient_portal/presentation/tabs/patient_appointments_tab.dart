import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../appointment/presentation/appointment_confirmation_screen.dart';
import '../../../appointment/presentation/book_appointment_screen.dart';
import '../../data/patient_portal_api.dart';
import '../screens/patient_feedback_screen.dart';
import '../screens/sepay_checkout_screen.dart';

/// 1-to-1 Patient Appointments List Tab matching Web `AppointmentListPage.jsx`:
/// - Live 15-minute reservation countdown on `Pending` / `Unpaid` bookings
/// - Pay SePay VietQR, View QR Confirmation, Cancel Booking, Leave Feedback shortcuts
class PatientAppointmentsTab extends StatefulWidget {
  const PatientAppointmentsTab({super.key});

  @override
  State<PatientAppointmentsTab> createState() => _PatientAppointmentsTabState();
}

class _PatientAppointmentsTabState extends State<PatientAppointmentsTab> {
  final PatientPortalApi _api = const PatientPortalApi();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String _statusFilter = 'ALL';
  Timer? _tickTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getAppointments(page: 1, pageSize: 50);
      if (!mounted) return;
      setState(() {
        _items = list;
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

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _items.where((a) {
      final st = (a['status'] ?? '').toString().toLowerCase();
      if (_statusFilter != 'ALL' && st != _statusFilter.toLowerCase()) {
        return false;
      }
      if (q.isNotEmpty) {
        final blob =
            '${a['appointmentCode'] ?? ''} ${a['packageName'] ?? ''} ${a['doctorName'] ?? ''}'
                .toLowerCase();
        if (!blob.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Duration? _remainingHold(Map<String, dynamic> appt) {
    final st = (appt['status'] ?? '').toString().toLowerCase();
    final pay = (appt['paymentStatus'] ?? '').toString().toLowerCase();
    if (st != 'pending' || pay == 'paid') return null;

    final rawCreated =
        appt['createdAt'] ?? appt['CreatedAt'] ?? appt['bookedAt'];
    if (rawCreated == null) return null;
    final created = DateTime.tryParse(rawCreated.toString())?.toLocal();
    if (created == null) return null;
    final expires = created.add(const Duration(minutes: 15));
    final diff = expires.difference(_now);
    return diff.isNegative ? Duration.zero : diff;
  }

  Future<void> _cancelAppointment(Map<String, dynamic> appt) async {
    final id = (appt['id'] ?? appt['appointmentId'] ?? '').toString();
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy lịch hẹn này?'),
        content: Text(
          'Bạn có chắc chắn muốn hủy lịch hẹn ${appt['appointmentCode'] ?? id} không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Giữ lịch'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.updateAppointment(id, {'status': 'Cancelled'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hủy lịch hẹn thành công.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BmsPageHeaderCard(
            icon: Icons.calendar_month_rounded,
            badgeText: 'LỊCH KHÁM & QR CHECK-IN',
            title: 'Lịch hẹn của tôi',
            subtitle: 'Theo dõi trạng thái thanh toán, đếm ngược giữ chỗ & mã QR',
            trailing: FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BookAppointmentScreen(),
                  ),
                );
                _load();
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Đặt lịch'),
            ),
          ),
          const SizedBox(height: 12),
          BmsSearchFilterBar(
            controller: _searchCtrl,
            hintText: 'Tìm mã lịch hẹn, gói XN, bác sĩ...',
            onChanged: (_) => setState(() {}),
            filterChips: [
              _chip('ALL', 'Tất cả (${_items.length})'),
              _chip('Pending', 'Chờ thanh toán'),
              _chip('Confirmed', 'Đã xác nhận'),
              _chip('CheckedIn', 'Đã check-in'),
              _chip('Completed', 'Hoàn thành'),
              _chip('Cancelled', 'Đã hủy'),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading)
            const BmsLoadingState(message: 'Đang tải danh sách lịch hẹn...')
          else if (_error != null)
            BmsErrorState(message: _error!, onRetry: _load)
          else if (_filtered.isEmpty)
            BmsEmptyState(
              icon: Icons.event_busy_outlined,
              title: 'Chưa có lịch hẹn nào',
              subtitle:
                  'Đặt lịch xét nghiệm trực tuyến để chọn khung giờ lấy mẫu nhanh chóng.',
              actionLabel: 'Đặt lịch ngay',
              onAction: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BookAppointmentScreen(),
                  ),
                );
                _load();
              },
            )
          else
            ..._filtered.map(_buildCard),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  BmsFilterChipItem _chip(String key, String label) => BmsFilterChipItem(
    key: key,
    label: label,
    selected: _statusFilter == key,
    onSelected: () => setState(() => _statusFilter = key),
  );

  Widget _buildCard(Map<String, dynamic> appt) {
    final id = (appt['id'] ?? appt['appointmentId'] ?? '').toString();
    final code = (appt['appointmentCode'] ?? id).toString();
    final pkgName =
        (appt['packageName'] ?? appt['servicePackageName'] ?? 'Gói xét nghiệm')
            .toString();
    final st = (appt['status'] ?? 'Pending').toString();
    final stLower = st.toLowerCase();
    final pay = (appt['paymentStatus'] ?? '').toString().toLowerCase();
    final hold = _remainingHold(appt);
    final canPay = stLower == 'pending' && pay != 'paid';
    final canCancel = stLower == 'pending' || stLower == 'confirmed';
    final canFeedback = stLower == 'checkedin' || stLower == 'completed';

    return BmsSoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    color: AppColors.primary,
                  ),
                ),
              ),
              BmsStatusPill(status: st),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pkgName,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          BmsInfoRow(
            label: 'Ngày & giờ hẹn',
            value:
                '${BmsFormatters.date(appt['appointmentDate'])} • ${appt['slotTime'] ?? '—'}',
            isBold: true,
          ),
          if ((appt['doctorName'] ?? '').toString().isNotEmpty)
            BmsInfoRow(
              label: 'Bác sĩ phụ trách',
              value: appt['doctorName'].toString(),
            ),
          if (hold != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: AppColors.warningText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hold == Duration.zero
                          ? 'Hết thời gian giữ chỗ 15 phút — đơn đang chờ hệ thống tự hủy'
                          : 'Giữ chỗ tự hủy sau: ${hold.inMinutes.toString().padLeft(2, '0')}:${(hold.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warningText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canPay)
                FilledButton.icon(
                  onPressed: () async {
                    final paid = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => SePayCheckoutScreen(
                          appointmentId: id,
                          appointmentCode: code,
                          packageName: pkgName,
                        ),
                      ),
                    );
                    if (paid == true) _load();
                  },
                  icon: const Icon(Icons.qr_code_2_rounded, size: 17),
                  label: const Text('Thanh toán SePay'),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AppointmentConfirmationScreen(
                        appointmentIdOrCode: id,
                      ),
                    ),
                  );
                  _load();
                },
                icon: const Icon(Icons.confirmation_number_outlined, size: 17),
                label: Text(canPay ? 'Xem phiếu' : 'Mã QR Check-in'),
              ),
              if (canFeedback)
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PatientFeedbackScreen(
                        preselectedAppointmentId: id,
                        preselectedPackageCode:
                            appt['packageCode']?.toString(),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.star_outline_rounded, size: 17),
                  label: const Text('Đánh giá'),
                ),
              if (canCancel)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () => _cancelAppointment(appt),
                  child: const Text('Hủy lịch'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
