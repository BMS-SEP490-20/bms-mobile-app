import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../staff_portal/presentation/widgets/staff_account_tab.dart';
import '../../staff_portal/presentation/widgets/staff_personal_shifts_tab.dart';
import 'tabs/reception_check_in_tab.dart';

/// Compact 3-Tab Mobile Shell for Receptionist (RoleId = 4):
/// 0: Quét mã QR & Check-in lịch hẹn hôm nay
/// 1: Lịch ca trực cá nhân
/// 2: Tài khoản, Thông báo & Đổi mật khẩu
/// Heavy walk-in intake forms & POS billing stay on BMS Web Workstation (PC).
class ReceptionistShellScreen extends StatefulWidget {
  final int initialIndex;

  const ReceptionistShellScreen({super.key, this.initialIndex = 0});

  @override
  State<ReceptionistShellScreen> createState() =>
      _ReceptionistShellScreenState();
}

class _ReceptionistShellScreenState extends State<ReceptionistShellScreen> {
  late int _currentIndex = widget.initialIndex;

  void _showPcOnlyHint(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$featureName được tối ưu trên BMS Web Workstation (máy tính quầy lễ tân).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ReceptionCheckInTab(
        onOpenQueueTab: () => _showPcOnlyHint('Bảng điều phối hàng đợi lớn'),
        onOpenWalkInTab: () => _showPcOnlyHint('Tiếp nhận khách vãng lai'),
      ),
      const StaffPersonalShiftsTab(),
      const StaffAccountTab(
        webWorkstationNote:
            'Ứng dụng di động dành cho Lễ tân tối ưu việc quét mã QR Check-in nhanh tại sảnh và xem lịch trực. Nghiệp vụ đăng ký vãng lai, thu ngân POS và điều phối hàng đợi lớn vui lòng thao tác trên BMS Web Workstation.',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _currentIndex, children: pages),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_outlined),
              selectedIcon: Icon(Icons.qr_code_scanner_rounded),
              label: 'Quét QR',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today_rounded),
              label: 'Lịch trực',
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
