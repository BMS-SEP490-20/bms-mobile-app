import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'tabs/doctor_clinical_work_tab.dart';
import 'tabs/doctor_console_tab.dart';
import 'tabs/doctor_dashboard_tab.dart';
import 'tabs/doctor_lab_reference_tab.dart';
import 'tabs/doctor_schedule_profile_tab.dart';

/// 5-Tab Mobile Clinical Shell for Doctor Role (RoleId = 2).
class DoctorShellScreen extends StatefulWidget {
  final int initialIndex;

  const DoctorShellScreen({super.key, this.initialIndex = 0});

  @override
  State<DoctorShellScreen> createState() => _DoctorShellScreenState();
}

class _DoctorShellScreenState extends State<DoctorShellScreen> {
  late int _currentIndex = widget.initialIndex;
  String? _preselectedPatientId;
  int _clinicalSubTab = 0;

  void _openClinicalWork(String patientId, int subTab) {
    setState(() {
      _preselectedPatientId = patientId;
      _clinicalSubTab = subTab;
      _currentIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DoctorDashboardTab(
        onOpenConsole: () => setState(() => _currentIndex = 1),
        onOpenClinicalWork: _openClinicalWork,
        onOpenLabLookup: () => setState(() => _currentIndex = 3),
      ),
      DoctorConsoleTab(onOpenClinicalWork: _openClinicalWork),
      DoctorClinicalWorkTab(
        preselectedPatientId: _preselectedPatientId,
        initialSubTab: _clinicalSubTab,
      ),
      const DoctorLabReferenceTab(),
      const DoctorScheduleProfileTab(),
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
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Tổng quan',
            ),
            NavigationDestination(
              icon: Icon(Icons.meeting_room_outlined),
              selectedIcon: Icon(Icons.meeting_room_rounded),
              label: 'Bàn khám',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_shared_outlined),
              selectedIcon: Icon(Icons.folder_shared_rounded),
              label: 'Bệnh án',
            ),
            NavigationDestination(
              icon: Icon(Icons.science_outlined),
              selectedIcon: Icon(Icons.science_rounded),
              label: 'Tra cứu XN',
            ),
            NavigationDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge_rounded),
              label: 'Lịch trực',
            ),
          ],
        ),
      ),
    );
  }
}
