/// BMS Mobile Application — 3-Role Clinical Portal (Patient, Doctor, Receptionist).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/bms_theme.dart';
import 'core/widgets/bms_ui_kit.dart';
import 'features/Generate_receipt/presentation/screens/generate_receipt_screen.dart';
import 'features/appointment/presentation/book_appointment_screen.dart';
import 'features/auth/presentation/screens/change_password_screen.dart';
import 'features/auth/presentation/screens/forgot_password_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/otp_verification_screen.dart';
import 'features/auth/presentation/screens/patient_home_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/catalog/presentation/screens/service_catalog_screen.dart';
import 'features/dashboard/presentation/screens/configure_iot_thresholds_screen.dart';
import 'features/dashboard/presentation/screens/role_dashboard_screen.dart';
import 'features/doctor-schedule/presentation/screens/doctor_schedule_screen.dart';
import 'features/laboratory/presentation/screens/trace_sample_origin_screen.dart';
import 'features/laboratory/presentation/screens/verify_test_results_screen.dart';
import 'features/notification/presentation/screens/notifications_history_screen.dart';
import 'features/notification/presentation/screens/unified_notifications_screen.dart';
import 'features/patient/presentation/screens/create_guest_profile_screen.dart';
import 'features/patient/presentation/screens/export_test_result_screen.dart';
import 'features/patient/presentation/screens/process_payment_screen.dart';
import 'features/patient/presentation/screens/profile_screen.dart';
import 'features/patient/presentation/screens/test_history_screen.dart';
import 'features/patient/presentation/screens/test_result_notifications_screen.dart';
import 'features/patient/presentation/screens/update_account_screen.dart';
import 'features/queue/presentation/screens/queue_ticket_screen.dart';
import 'features/scanQRcheckin/appointments_list_screen.dart';
import 'features/scanQRcheckin/qr_checkin_scanner_screen.dart';
import 'features/shell/presentation/mobile_role_router_screen.dart';
import 'features/shell/presentation/web_only_role_notice_screen.dart';
import 'features/walkin/presentation/register_walkin_screen.dart';
import 'services/bms_auth.dart';

/// Application entry point.
/// Restores persisted JWT session (and attempts refresh if needed) before launching UI.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final restored = await BmsAuth.restoreSession();
  final initialRoute = restored ? '/workspace' : '/login';
  runApp(BmsMobileApp(initialRoute: initialRoute));
}

/// Root MaterialApp configured with Soft Healthcare SaaS theme and Vietnamese localization.
class BmsMobileApp extends StatelessWidget {
  final String initialRoute;

  const BmsMobileApp({super.key, this.initialRoute = '/login'});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BMS Health',
      debugShowCheckedModeBanner: false,
      theme: BmsTheme.lightTheme,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
      locale: const Locale('vi', 'VN'),
      initialRoute: initialRoute,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/workspace': (_) => const MobileRoleRouterScreen(),
        '/home': (_) => const MobileRoleRouterScreen(),
        '/patient-home': (_) => const PatientHomeScreen(),
        '/web-only': (_) => const WebOnlyRoleNoticeScreen(),
        '/register': (_) => const RegisterScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/change-password': (_) => const ChangePasswordScreen(),
        '/role-dashboard': (_) => const RoleDashboardScreen(),
        '/otp-verify': (_) => const OtpVerificationScreen(
              destination: '',
              purpose: 'PasswordReset',
              channel: 'Email',
            ),
        '/service-catalog': (_) => const ServiceCatalogScreen(),
        '/search-test-packages': (_) => const ServiceCatalogScreen(),
        '/create-guest-profile': (_) => const CreateGuestProfileScreen(),
        '/register-walk-in': (_) => const RegisterWalkInScreen(),
        '/doctor-schedule': (_) => const DoctorScheduleScreen(),
        '/update-account': (_) => const UpdateAccountScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/book-appointment': (_) => const BookAppointmentScreen(),
        '/queue-ticket': (_) => const QueueTicketScreen(),
        '/payment': (_) => const ProcessPaymentScreen(),
        '/checkout': (_) => const ProcessPaymentScreen(),
        '/results/export': (_) => const ExportTestResultScreen(),
        '/export-results': (_) => const ExportTestResultScreen(),
        '/patient/results': (_) => const ExportTestResultScreen(),
        '/iot-thresholds': (_) => const ConfigureIotThresholdsScreen(),
        '/manager/iot-thresholds': (_) => const ConfigureIotThresholdsScreen(),
        '/verify-results': (_) => const VerifyTestResultsScreen(),
        '/laboratory/verify-results': (_) => const VerifyTestResultsScreen(),
        '/sample-trace': (_) => const TraceSampleOriginScreen(),
        '/laboratory/sample-trace': (_) => const TraceSampleOriginScreen(),
        '/trace-sample': (_) => const TraceSampleOriginScreen(),
        '/appointments': (_) => const AppointmentsListScreen(),
        '/scan-qr-checkin': (_) => const QrCheckinScannerScreen(),
        '/notifications': (_) => const PatientNotificationsScreen(),
        '/patient/notifications': (_) => const TestResultNotificationsScreen(),
        '/test-result-notifications': (_) =>
            const TestResultNotificationsScreen(),
        '/notifications-history': (_) => const NotificationsHistoryScreen(),
        '/generate-receipt': (_) => const GenerateReceiptScreen(),
        '/patient/test-history': (_) => const TestHistoryScreen(),
      },
    );
  }
}

/// Optional landing widget retained for backward compatibility.
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: BmsSoftCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.biotech_rounded,
                  size: 56,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'BMS Health',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Hệ thống Quản lý Phòng khám & Xét nghiệm Huyết học',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Đăng nhập'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
