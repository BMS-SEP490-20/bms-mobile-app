import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../../../shell/presentation/web_only_role_notice_screen.dart';

/// Cold-Chain IoT Threshold Configuration Notice Screen.
/// Administrative & Manager IoT configuration is handled on the BMS Web Workstation.
class ConfigureIotThresholdsScreen extends StatelessWidget {
  const ConfigureIotThresholdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (BmsAuth.isLoggedIn && !BmsAuth.isMobileSupportedRole) {
      return const WebOnlyRoleNoticeScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Cấu hình cảm biến kho lạnh')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: BmsEmptyState(
          icon: Icons.desktop_windows_rounded,
          title: 'Quản trị cảm biến kho lạnh vận hành trên BMS Web',
          subtitle:
              'Thiết lập ngưỡng nhiệt độ tủ bảo quản mẫu và danh sách cảnh báo thuộc phân hệ Quản lý trên BMS Web Workstation.',
        ),
      ),
    );
  }
}
