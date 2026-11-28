import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../../../auth/presentation/screens/change_password_screen.dart';
import '../../../notification/presentation/screens/unified_notifications_screen.dart';
import '../../data/staff_portal_api.dart';

/// Shared Staff Account, Security & Password Management Tab
/// used by Doctor, Lab, Receptionist, Manager, and Admin shells.
class StaffAccountTab extends StatefulWidget {
  final String webWorkstationNote;

  const StaffAccountTab({
    super.key,
    required this.webWorkstationNote,
  });

  @override
  State<StaffAccountTab> createState() => _StaffAccountTabState();
}

class _StaffAccountTabState extends State<StaffAccountTab> {
  final StaffPortalApi _api = const StaffPortalApi();
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await _api.getMyProfile();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất tài khoản'),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng BMS MedLab?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await BmsAuth.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile ?? BmsAuth.user ?? {};
    final fullName =
        (p['fullName'] ?? BmsAuth.currentUserName).toString();
    final username =
        (p['username'] ?? BmsAuth.currentUserUsername).toString();
    final email = (p['email'] ?? BmsAuth.currentUserEmail).toString();
    final phone = (p['phoneNumber'] ?? p['phone'] ?? '—').toString();
    final department =
        (p['department'] ?? p['specialty'] ?? BmsAuth.roleLabelVi).toString();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BmsPageHeaderCard(
            icon: Icons.badge_outlined,
            badgeText: BmsAuth.roleLabelVi.toUpperCase(),
            title: fullName.isNotEmpty ? fullName : 'Tài khoản nhân sự',
            subtitle: '@$username • $department',
          ),
          const SizedBox(height: 14),
          if (_loading)
            const BmsLoadingState(message: 'Đang đồng bộ thông tin tài khoản...')
          else
            BmsSoftCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin nhân sự',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  BmsInfoRow(label: 'Họ và tên', value: fullName, isBold: true),
                  BmsInfoRow(
                    label: 'Vai trò hệ thống',
                    value: BmsAuth.roleLabelVi,
                    valueColor: AppColors.primary,
                    isBold: true,
                  ),
                  BmsInfoRow(
                    label: 'Tên đăng nhập',
                    value: username,
                    isMono: true,
                  ),
                  BmsInfoRow(label: 'Email công việc', value: email),
                  BmsInfoRow(label: 'Số điện thoại', value: phone),
                  BmsInfoRow(label: 'Khoa / Bộ phận', value: department),
                ],
              ),
            ),
          const SizedBox(height: 14),
          BmsSoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Thông báo cá nhân',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PatientNotificationsScreen(),
                    ),
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
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
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
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
                      color: AppColors.danger,
                    ),
                  ),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          BmsSoftCard(
            backgroundColor: AppColors.surfaceSoft,
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.desktop_windows_outlined,
                  size: 19,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.webWorkstationNote,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
