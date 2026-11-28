import 'package:flutter/material.dart';
import '../../../services/bms_auth.dart';
import '../../auth/presentation/screens/login_screen.dart';
import '../../patient_portal/presentation/patient_shell_screen.dart';
import '../../reception_portal/presentation/receptionist_shell_screen.dart';
import '../../staff_portal/presentation/shells/admin_mobile_shell.dart';
import '../../staff_portal/presentation/shells/manager_mobile_shell.dart';
import '../../staff_portal/presentation/shells/staff_compact_shell.dart';

/// Central 6-Role Mobile Dispatcher:
/// - Patient (5) -> [PatientShellScreen] (1-1 Web)
/// - Receptionist (4) -> [ReceptionistShellScreen] (3-tab QR Check-in + Shifts + Account)
/// - Doctor (2) & Lab (3) -> [StaffCompactShell] (2-tab Personal Shifts + Account)
/// - Manager (6) -> [ManagerMobileShell] (4-tab KPI / IoT / Shifts+Feedback / Account)
/// - Admin (1) -> [AdminMobileShell] (4-tab AdminOps / IoT RO / Shifts RO / Account)
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
      case 'Receptionist':
        return const ReceptionistShellScreen();
      case 'Doctor':
      case 'Lab':
        return const StaffCompactShell();
      case 'Manager':
        return const ManagerMobileShell();
      case 'Admin':
        return const AdminMobileShell();
      default:
        return const LoginScreen();
    }
  }
}
