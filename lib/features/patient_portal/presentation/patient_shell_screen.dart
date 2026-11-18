import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'tabs/patient_appointments_tab.dart';
import 'tabs/patient_billing_tab.dart';
import 'tabs/patient_dashboard_tab.dart';
import 'tabs/patient_profile_tab.dart';
import 'tabs/patient_results_hub_tab.dart';

/// 5-Tab Mobile Shell for Patient Role (RoleId = 5 or 9).
class PatientShellScreen extends StatefulWidget {
  final int initialIndex;

  const PatientShellScreen({super.key, this.initialIndex = 0});

  @override
  State<PatientShellScreen> createState() => _PatientShellScreenState();
}

class _PatientShellScreenState extends State<PatientShellScreen> {
  late int _currentIndex = widget.initialIndex;
  int _resultsSubTab = 0;

  void _navigateTab(int index, {int? subTabIndex}) {
    setState(() {
      _currentIndex = index;
      if (index == 2 && subTabIndex != null) {
        _resultsSubTab = subTabIndex;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      PatientDashboardTab(onNavigateTab: _navigateTab),
      const PatientAppointmentsTab(),
      PatientResultsHubTab(initialSegment: _resultsSubTab),
      const PatientBillingTab(),
      const PatientProfileTab(),
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
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Lịch hẹn',
            ),
            NavigationDestination(
              icon: Icon(Icons.biotech_outlined),
              selectedIcon: Icon(Icons.biotech_rounded),
              label: 'Kết quả & Mẫu',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Viện phí',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Hồ sơ',
            ),
          ],
        ),
      ),
    );
  }
}
