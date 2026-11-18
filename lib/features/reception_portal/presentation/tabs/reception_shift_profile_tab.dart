import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/account_service.dart';
import '../../../../services/bms_auth.dart';
import '../../../auth/presentation/screens/change_password_screen.dart';
import '../../../doctor-schedule/presentation/screens/doctor_schedule_screen.dart';
import '../../../notification/presentation/screens/unified_notifications_screen.dart';
import '../../data/reception_portal_api.dart';

/// Tab 5 — Receptionist Shifts, Doctor Schedule Lookup & Staff Account Profile.
class ReceptionShiftProfileTab extends StatefulWidget {
  const ReceptionShiftProfileTab({super.key});

  @override
  State<ReceptionShiftProfileTab> createState() =>
      _ReceptionShiftProfileTabState();
}

class _ReceptionShiftProfileTabState extends State<ReceptionShiftProfileTab> {
  final ReceptionPortalApi _api = const ReceptionPortalApi();

  int _subTab = 0;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _shifts = [];
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
        _api.getShifts(from: fromIso, to: toIso, employeeId: userId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = res[0] as Map<String, dynamic>?;
        _shifts = res[1] as List<Map<String, dynamic>>;
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

  Future<void> _editContact() async {
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
                decoration: const InputDecoration(labelText: 'Họ và tên nhân viên'),
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
                            (res['message'] ?? 'Không thể lưu thay đổi.')
                                .toString(),
                            isError: true,
                          );
                        }
                      },
                child: Text(saving ? 'Đang lưu...' : 'Lưu thông tin'),
              ),
            ],
          ),
        ),
      ),
    );

    if (updated == true) {
      _showSnack('Đã cập nhật hồ sơ nhân viên lễ tân.');
      await _loadData();
    }
  }

  Future<void> _logout() async {
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
            icon: Icons.schedule_rounded,
            badgeText: 'Lịch ca & Tài khoản Lễ tân',
            title: 'Ca trực & Cá nhân',
            subtitle: 'Theo dõi ca trực quầy, tra cứu lịch bác sĩ và quản lý tài khoản',
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
            tabs: const ['Ca trực quầy', 'Hồ sơ cá nhân'],
            selectedIndex: _subTab,
            onChanged: (idx) => setState(() => _subTab = idx),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const BmsLoadingState(message: 'Đang tải thông tin ca trực...')
          else if (_error != null)
            BmsErrorState(message: _error!, onRetry: _loadData)
          else if (_subTab == 0)
            _buildShiftsSection()
          else
            _buildProfileSection(),
        ],
      ),
    );
  }

  Widget _buildShiftsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BmsSectionHeader(
          title: 'Lịch trực của tôi (${_shifts.length})',
          trailing: FilledButton.tonalIcon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DoctorScheduleScreen(),
                ),
              );
            },
            icon: const Icon(Icons.medical_services_outlined, size: 17),
            label: const Text('Tra cứu lịch BS'),
          ),
        ),
        const SizedBox(height: 10),
        if (_shifts.isEmpty)
          const BmsEmptyState(
            icon: Icons.event_available_outlined,
            title: 'Chưa có phân công ca trực riêng',
            subtitle:
                'Nhấn "Tra cứu lịch BS" để xem lịch khám bác sĩ phục vụ tư vấn tiếp đón.',
          )
        else
          ..._shifts.map((s) {
            final dateStr = BmsFormatters.date(s['shiftDate'] ?? s['date']);
            final shiftType = BmsFormatters.shiftTypeVi(
              (s['shiftType'] ?? s['shiftName'])?.toString(),
            );
            final area = (s['roomName'] ?? s['department'] ?? 'Quầy Tiếp Đón')
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
                          area,
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

  Widget _buildProfileSection() {
    final p = _profile ?? BmsAuth.user ?? <String, dynamic>{};
    final fullName = (p['fullName'] ?? BmsAuth.currentUserName).toString();
    final username = (p['username'] ?? '—').toString();
    final email = (p['email'] ?? '—').toString();
    final phone = (p['phoneNumber'] ?? p['phone'] ?? 'Chưa cập nhật').toString();
    final empCode = (p['employeeCode'] ?? 'RECEP-BMS').toString();
    final department = (p['department'] ?? 'Bộ phận Tiếp đón & Thu ngân')
        .toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BmsSoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              BmsInfoRow(label: 'Mã nhân viên', value: empCode, isMono: true),
              BmsInfoRow(label: 'Tài khoản', value: username),
              BmsInfoRow(label: 'Bộ phận', value: department),
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
                  'Chỉnh sửa thông tin liên hệ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _editContact,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.lock_reset_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Đổi mật khẩu đăng nhập',
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
                  'Đăng xuất tài khoản',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.dangerText,
                  ),
                ),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
