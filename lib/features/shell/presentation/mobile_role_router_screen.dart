import 'package:flutter/material.dart';
import '../../../services/bms_auth.dart';
import '../../auth/presentation/screens/login_screen.dart';
import '../../doctor_portal/presentation/doctor_shell_screen.dart';
import '../../patient_portal/presentation/patient_shell_screen.dart';
import '../../reception_portal/presentation/receptionist_shell_screen.dart';
import 'web_only_role_notice_screen.dart';

/// Central Role Dispatcher for BMS Mobile Application.
/// Dispatches strictly:
/// - Patient (RoleId 5 or 9) -> [PatientShellScreen]
/// - Doctor (RoleId 2) -> [DoctorShellScreen]
/// - Receptionist (RoleId 4) -> [ReceptionistShellScreen]
/// - Admin (1) / Lab (3) / Manager (6) -> [WebOnlyRoleNoticeScreen]
/// - Unauthenticated -> [LoginScreen]
class MobileRoleRouterScreen extends StatelessWidget {
  const MobileRoleRouterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!BmsAuth.isLoggedIn) {
      return const LoginScreen();
    }

    switch (BmsAuth.userRole) {
      case 'Patient':
        return const PatientShellScreen();
      case 'Doctor':
        return const DoctorShellScreen();
      case 'Receptionist':
        return const ReceptionistShellScreen();
      default:
        return const WebOnlyRoleNoticeScreen();
    }
  }
}
