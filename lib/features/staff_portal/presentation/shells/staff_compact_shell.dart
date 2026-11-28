import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/bms_auth.dart';
import '../widgets/staff_account_tab.dart';
import '../widgets/staff_personal_shifts_tab.dart';

/// Compact 2-Tab Mobile Shell for Doctor (RoleId = 2) and Lab Tech (RoleId = 3):
/// - Tab 0: Lịch ca trực cá nhân (`GET /api/shifts`)
/// - Tab 1: Tài khoản, Thông báo & Đổi mật khẩu
class StaffCompactShell extends StatefulWidget {
  const StaffCompactShell({super.key});

  @override
  State<StaffCompactShell> createState() => _StaffCompactShellState();
}

class _StaffCompactShellState extends State<StaffCompactShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isDoctor = BmsAuth.isDoctor;
    final pages = [
      const StaffPersonalShiftsTab(),
      StaffAccountTab(
        webWorkstationNote: isDoctor
            ? 'Các nghiệp vụ chuyên môn sâu như soạn bệnh án EMR, chỉ định xét nghiệm, thẩm định và ký duyệt kết quả vui lòng thực hiện trên BMS Web Workstation (máy tính).'
            : 'Các nghiệp vụ chuyên môn phòng Lab như tiếp nhận mẫu, nhập chỉ số phân tích, nội kiểm Westgard IQC vui lòng thực hiện trên BMS Web Workstation (máy tính).',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today_rounded),
              label: 'Lịch ca trực',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }
}
