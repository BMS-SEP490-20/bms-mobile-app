import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bms_ui_kit.dart';
import '../../../services/bms_auth.dart';

/// Notice screen rendered when an Admin (1), Lab (3), or Manager (6) signs into the mobile app.
/// Directs administrative and laboratory analyzer personnel to the dedicated BMS Web Workstation.
class WebOnlyRoleNoticeScreen extends StatefulWidget {
  const WebOnlyRoleNoticeScreen({super.key});

  @override
  State<WebOnlyRoleNoticeScreen> createState() =>
      _WebOnlyRoleNoticeScreenState();
}

class _WebOnlyRoleNoticeScreenState extends State<WebOnlyRoleNoticeScreen> {
  bool _signingOut = false;

  Future<void> _handleSignOut() async {
    setState(() => _signingOut = true);
    await BmsAuth.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final roleName = BmsAuth.roleLabelVi;
    final displayName = BmsAuth.currentUserName.isNotEmpty
        ? BmsAuth.currentUserName
        : 'Tài khoản nội bộ BMS';
    final username = (BmsAuth.user?['username'] ?? BmsAuth.user?['email'] ?? '')
        .toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Phân hệ Trạm làm việc Web'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: BmsSoftCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.desktop_windows_rounded,
                          color: AppColors.primary,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Vai trò sử dụng trên BMS Web Workstation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Các nghiệp vụ Quản trị hệ thống, Vận hành máy phân tích xét nghiệm (LIS/QC) và Quản lý điều hành được thiết kế chuyên biệt trên Trạm làm việc BMS Web để đảm bảo không gian bảng biểu rộng và an toàn dữ liệu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          BmsInfoRow(
                            label: 'Tài khoản hiện tại',
                            value: displayName,
                            isBold: true,
                          ),
                          if (username.isNotEmpty)
                            BmsInfoRow(label: 'Tên đăng nhập', value: username),
                          BmsInfoRow(
                            label: 'Vai trò ghi nhận',
                            value: roleName,
                            valueColor: AppColors.primary,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.phone_iphone_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ứng dụng di động BMS phục vụ 3 vai trò: Bệnh nhân, Bác sĩ khám bệnh và Lễ tân tiếp đón.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.primaryDark,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _signingOut ? null : _handleSignOut,
                      icon: _signingOut
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.logout_rounded, size: 19),
                      label: Text(
                        _signingOut
                            ? 'Đang đăng xuất...'
                            : 'Đăng xuất & Chuyển tài khoản',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
