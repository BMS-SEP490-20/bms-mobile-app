import 'package:flutter/material.dart';
import '../../../../core/network/bms_http_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/account_service.dart';
import '../../../../services/bms_auth.dart';
import '../../../auth/presentation/screens/change_password_screen.dart';
import '../../../doctor-schedule/presentation/screens/doctor_schedule_screen.dart';
import '../../../notification/presentation/screens/unified_notifications_screen.dart';
import '../../data/doctor_portal_api.dart';

/// Tab 5 — Shifts, Doctor Appointments Rescheduling & Staff Profile.
class DoctorScheduleProfileTab extends StatefulWidget {
  const DoctorScheduleProfileTab({super.key});

  @override
  State<DoctorScheduleProfileTab> createState() =>
      _DoctorScheduleProfileTabState();
}

class _DoctorScheduleProfileTabState extends State<DoctorScheduleProfileTab> {
  final DoctorPortalApi _api = const DoctorPortalApi();
  final BmsHttpClient _http = const BmsHttpClient();

  int _subTab = 0;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = BmsAuth.currentUserId;
      final now = DateTime.now();
      final fromIso = BmsFormatters.isoDate(now.subtract(const Duration(days: 2)));
      final toIso = BmsFormatters.isoDate(now.add(const Duration(days: 14)));

      final res = await Future.wait([
        _api.getStaffProfile(),
        _api.getShifts(from: fromIso, to: toIso, doctorId: userId),
        _api.getAppointments(doctorId: userId, pageSize: 30),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = res[0] as Map<String, dynamic>?;
        _shifts = res[1] as List<Map<String, dynamic>>;
        _appointments = res[2] as List<Map<String, dynamic>>;
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

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.textPrimary,
      ),
    );
  }

  Future<void> _rescheduleAppointment(Map<String, dynamic> apt) async {
    final id = (apt['id'] ?? '').toString();
    if (id.isEmpty) return;

    DateTime pickedDate = DateTime.now().add(const Duration(days: 1));
    String selectedSlot = '08:30';
    List<String> availableSlots = const [
      '07:30',
      '08:00',
      '08:30',
      '09:00',
      '09:30',
      '10:00',
      '13:30',
      '14:00',
      '14:30',
      '15:00',
    ];
    final notesCtrl = TextEditingController(
      text: 'Điều chỉnh khung giờ khám theo lịch trực bác sĩ',
    );
    bool saving = false;

    Future<void> loadSlots(StateSetter setSheetState) async {
      try {
        final res = await _http.get(
          '/api/appointments/slots',
          query: {
            'doctorId': BmsAuth.currentUserId,
            'date': BmsFormatters.isoDate(pickedDate),
          },
        );
        if (res.isSuccess) {
          final map = res.bodyAsMap;
          final raw = map['slots'] ?? res.data;
          if (raw is List && raw.isNotEmpty) {
            final parsed = raw
                .map((e) {
                  if (e is Map) {
                    return (e['slotTime'] ?? e['time'] ?? '').toString();
                  }
                  return e.toString();
                })
                .where((s) => s.isNotEmpty)
                .toList();
            if (parsed.isNotEmpty) {
              setSheetState(() {
                availableSlots = parsed;
                if (!availableSlots.contains(selectedSlot)) {
                  selectedSlot = availableSlots.first;
                }
              });
            }
          }
        }
      } catch (_) {}
    }

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Đổi khung giờ hẹn khám',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: pickedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (d != null) {
                    setSheetState(() => pickedDate = d);
                    await loadSlots(setSheetState);
                  }
                },
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: Text('Ngày hẹn mới: ${BmsFormatters.date(pickedDate)}'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedSlot,
                decoration: const InputDecoration(labelText: 'Khung giờ khám'),
                items: availableSlots
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setSheetState(() => selectedSlot = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Ghi chú dời lịch'),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setSheetState(() => saving = true);
                        try {
                          await _api.updateAppointment(id, {
                            'appointmentDate': BmsFormatters.isoDate(pickedDate),
                            'slotTime': selectedSlot,
                            'status': 'Rescheduled',
                            'notes': notesCtrl.text.trim(),
                          });
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          setSheetState(() => saving = false);
                          _showSnack(
                            e.toString().replaceFirst('BmsApiException: ', ''),
                            isError: true,
                          );
                        }
                      },
                child: Text(saving ? 'Đang cập nhật...' : 'Xác nhận dời lịch'),
              ),
            ],
          ),
        ),
      ),
    );

    if (updated == true) {
      _showSnack('Đã cập nhật khung giờ lịch hẹn thành công.');
      await _loadData();
    }
  }

  Future<void> _editContactInfo() async {
    final userId = (_profile?['id'] ?? BmsAuth.currentUserId).toString();
    if (userId.isEmpty) return;

    final nameCtrl = TextEditingController(
      text: (_profile?['fullName'] ?? BmsAuth.currentUserName).toString(),
    );
    final emailCtrl = TextEditingController(
      text: (_profile?['email'] ?? BmsAuth.user?['email'] ?? '').toString(),
    );
    final phoneCtrl = TextEditingController(
      text: (_profile?['phoneNumber'] ?? _profile?['phone'] ?? '').toString(),
    );
    bool saving = false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cập nhật thông tin liên hệ',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Họ và tên bác sĩ'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email công vụ'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setSheetState(() => saving = true);
                        final res = await AccountService.updateAccount(
                          userId,
                          fullName: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          phoneNumber: phoneCtrl.text.trim(),
                        );
                        if (res['success'] == true) {
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } else {
                          setSheetState(() => saving = false);
                          _showSnack(
                            (res['message'] ?? 'Không thể lưu thông tin.')
                                .toString(),
                            isError: true,
                          );
                        }
                      },
                child: Text(saving ? 'Đang lưu...' : 'Lưu thay đổi'),
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true) {
      _showSnack('Đã cập nhật thông tin liên hệ nhân sự.');
      await _loadData();
    }
  }

  Future<void> _handleLogout() async {
    await BmsAuth.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          BmsPageHeaderCard(
            icon: Icons.badge_outlined,
            badgeText: 'Lịch công tác & Tài khoản',
            title: 'Lịch trực & Cá nhân',
            subtitle: 'Quản lý ca trực khoa, lịch hẹn bác sĩ và hồ sơ nhân sự',
            trailing: IconButton(
              tooltip: 'Thông báo',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PatientNotificationsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(height: 14),
          BmsSegmentedTabs(
            tabs: const ['Ca trực', 'Lịch hẹn BS', 'Hồ sơ nhân sự'],
            selectedIndex: _subTab,
            onChanged: (idx) => setState(() => _subTab = idx),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const BmsLoadingState(message: 'Đang tải thông tin công tác...')
          else if (_error != null)
            BmsErrorState(message: _error!, onRetry: _loadData)
          else if (_subTab == 0)
            _buildShiftsView()
          else if (_subTab == 1)
            _buildAppointmentsView()
          else
            _buildProfileView(),
        ],
      ),
    );
  }

  Widget _buildShiftsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BmsSectionHeader(
          title: 'Ca trực cá nhân (${_shifts.length})',
          trailing: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DoctorScheduleScreen(),
                ),
              );
            },
            icon: const Icon(Icons.calendar_view_week_rounded, size: 17),
            label: const Text('Lịch toàn khoa'),
          ),
        ),
        const SizedBox(height: 10),
        if (_shifts.isEmpty)
          const BmsEmptyState(
            icon: Icons.event_busy_outlined,
            title: 'Chưa có ca trực trong 14 ngày tới',
            subtitle: 'Bạn có thể nhấn "Lịch toàn khoa" để tra cứu lịch chung.',
          )
        else
          ..._shifts.map((s) {
            final dateStr = BmsFormatters.date(s['shiftDate'] ?? s['date']);
            final shiftType = BmsFormatters.shiftTypeVi(
              (s['shiftType'] ?? s['shiftName'])?.toString(),
            );
            final room = (s['roomName'] ?? s['roomId'] ?? 'Khoa Khám Bệnh')
                .toString();
            final status = (s['status'] ?? 'Confirmed').toString();

            return BmsSoftCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$dateStr · $shiftType',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          room,
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
            );
          }),
      ],
    );
  }

  Widget _buildAppointmentsView() {
    if (_appointments.isEmpty) {
      return const BmsEmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Chưa có lịch hẹn gán cho bác sĩ',
        subtitle: 'Các lịch hẹn bệnh nhân chọn bác sĩ sẽ hiển thị tại đây.',
      );
    }

    return Column(
      children: _appointments.map((apt) {
        final code = (apt['appointmentCode'] ?? apt['code'] ?? '—').toString();
        final patientName = (apt['patientName'] ?? 'Bệnh nhân').toString();
        final dateStr = BmsFormatters.date(
          apt['appointmentDate'] ?? apt['appointmentTime'],
        );
        final slot = (apt['slotTime'] ??
                BmsFormatters.time(apt['appointmentTime']))
            .toString();
        final status = (apt['status'] ?? 'Confirmed').toString();
        final lower = status.toLowerCase();
        final canReschedule = lower == 'confirmed' ||
            lower == 'pending' ||
            lower == 'rescheduled';

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
                      patientName,
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
              BmsInfoRow(label: 'Mã lịch hẹn', value: code, isMono: true),
              BmsInfoRow(label: 'Thời gian', value: '$dateStr · $slot'),
              if (canReschedule) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _rescheduleAppointment(apt),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                    label: const Text('Đổi khung giờ'),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProfileView() {
    final p = _profile ?? BmsAuth.user ?? <String, dynamic>{};
    final fullName = (p['fullName'] ?? BmsAuth.currentUserName).toString();
    final email = (p['email'] ?? '—').toString();
    final phone = (p['phoneNumber'] ?? p['phone'] ?? 'Chưa cập nhật').toString();
    final empCode = (p['employeeCode'] ?? 'Chưa cấp').toString();
    final license = (p['licenseNumber'] ?? 'Chưa cập nhật').toString();
    final specialty = (p['specialty'] ?? 'Đa khoa - Xét nghiệm').toString();
    final department = (p['department'] ?? 'Khoa Khám Bệnh').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BmsSoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BS. $fullName',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              BmsInfoRow(label: 'Mã nhân sự', value: empCode, isMono: true),
              BmsInfoRow(label: 'Chứng chỉ hành nghề', value: license),
              BmsInfoRow(label: 'Chuyên khoa', value: specialty),
              BmsInfoRow(label: 'Đơn vị công tác', value: department),
              BmsInfoRow(label: 'Email', value: email),
              BmsInfoRow(label: 'Số điện thoại', value: phone),
            ],
          ),
        ),
        const SizedBox(height: 12),
        BmsSoftCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Cập nhật thông tin liên hệ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _editContactInfo,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.lock_reset_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Đổi mật khẩu tài khoản',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Đăng xuất khỏi thiết bị',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.dangerText,
                  ),
                ),
                onTap: _handleLogout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
