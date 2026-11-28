import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../catalog/presentation/screens/service_catalog_screen.dart';
import 'tabs/patient_appointments_tab.dart';
import 'tabs/patient_dashboard_tab.dart';
import 'tabs/patient_profile_tab.dart';
import 'tabs/patient_results_hub_tab.dart';

/// 5-Tab 1-to-1 Patient Portal Shell (RoleId = 5):
/// 0: Trang chủ (1-1 PatientHomePage)
/// 1: Gói XN & Bảng giá (1-1 ServiceCatalogPage -> BookAppointment)
/// 2: Lịch khám (1-1 AppointmentList + 15m countdown + SePay + QR)
/// 3: Kết quả (Tiến trình 6 bước + Lịch sử & PDF A4)
/// 4: Tài khoản (Hồ sơ ISO 15189 + Viện phí + Đánh giá + Thông báo + Đổi MK)
class PatientShellScreen extends StatefulWidget {
  final int initialIndex;

  const PatientShellScreen({super.key, this.initialIndex = 0});

  @override
  State<PatientShellScreen> createState() => _PatientShellScreenState();
}

class _PatientShellScreenState extends State<PatientShellScreen> {
  late int _currentIndex = widget.initialIndex;
  int _resultsSubTab = 0;
  String? _catalogSearch;

  void _navigateTab(
    int index, {
    int? subTabIndex,
    String? catalogSearch,
  }) {
    setState(() {
      _currentIndex = index;
      if (index == 1 && catalogSearch != null) {
        _catalogSearch = catalogSearch;
      }
      if (index == 3 && subTabIndex != null) {
        _resultsSubTab = subTabIndex;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      PatientDashboardTab(onNavigateTab: _navigateTab),
      ServiceCatalogScreen(
        key: ValueKey('patient_catalog_${_catalogSearch ?? ''}'),
        embedded: true,
        isGuest: false,
        initialSearch: _catalogSearch,
      ),
      const PatientAppointmentsTab(),
      PatientResultsHubTab(initialSegment: _resultsSubTab),
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
              icon: Icon(Icons.medical_information_outlined),
              selectedIcon: Icon(Icons.medical_information_rounded),
              label: 'Gói XN',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Lịch khám',
            ),
            NavigationDestination(
              icon: Icon(Icons.biotech_outlined),
              selectedIcon: Icon(Icons.biotech_rounded),
              label: 'Kết quả',
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
