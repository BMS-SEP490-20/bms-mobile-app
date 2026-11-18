import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bms_ui_kit.dart';
import '../../../services/bms_auth.dart';
import '../data/walkin_repository.dart';
import 'register_walkin_page.dart';

/// Walk-in Patient Registration Route Wrapper in Vietnamese.
class RegisterWalkInScreen extends StatelessWidget {
  const RegisterWalkInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!BmsAuth.isLoggedIn) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Tiếp nhận khách vãng lai')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: BmsEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Vui lòng đăng nhập tài khoản Lễ tân',
            actionLabel: 'Đăng nhập',
            onAction: () => Navigator.pushNamed(context, '/login'),
          ),
        ),
      );
    }

    final role = BmsAuth.userRole.toLowerCase();
    if (role != 'receptionist' && role != 'admin') {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Tiếp nhận khách vãng lai')),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: BmsEmptyState(
            icon: Icons.block_rounded,
            title: 'Chức năng dành riêng cho Lễ tân tiếp đón',
            subtitle: 'Chỉ nhân viên Lễ tân mới có quyền đăng ký hồ sơ vãng lai.',
          ),
        ),
      );
    }

    return RegisterWalkInPage(repository: WalkInRepository());
  }
}
