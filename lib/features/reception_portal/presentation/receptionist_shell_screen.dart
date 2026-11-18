import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'tabs/reception_billing_tab.dart';
import 'tabs/reception_check_in_tab.dart';
import 'tabs/reception_patients_walk_in_tab.dart';
import 'tabs/reception_queue_tab.dart';
import 'tabs/reception_shift_profile_tab.dart';

/// 5-Tab Mobile Shell for Receptionist Role (RoleId = 4).
class ReceptionistShellScreen extends StatefulWidget {
  final int initialIndex;

  const ReceptionistShellScreen({super.key, this.initialIndex = 0});

  @override
  State<ReceptionistShellScreen> createState() =>
      _ReceptionistShellScreenState();
}

class _ReceptionistShellScreenState extends State<ReceptionistShellScreen> {
  late int _currentIndex = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ReceptionCheckInTab(
        onOpenQueueTab: () => setState(() => _currentIndex = 2),
        onOpenWalkInTab: () => setState(() => _currentIndex = 1),
      ),
      ReceptionPatientsWalkInTab(
        onOpenQueueTab: () => setState(() => _currentIndex = 2),
      ),
      const ReceptionQueueTab(),
      const ReceptionBillingTab(),
      const ReceptionShiftProfileTab(),
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
              label: 'Tiếp đón',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_add_alt_outlined),
              selectedIcon: Icon(Icons.person_add_alt_1_rounded),
              label: 'Vãng lai',
            ),
            NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined),
              selectedIcon: Icon(Icons.confirmation_number_rounded),
              label: 'Hàng đợi',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Viện phí',
            ),
            NavigationDestination(
              icon: Icon(Icons.schedule_outlined),
              selectedIcon: Icon(Icons.schedule_rounded),
              label: 'Ca trực',
            ),
          ],
        ),
      ),
    );
  }
}
