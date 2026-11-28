/// BMS MedLab Mobile Application — 1-to-1 Patient Portal & Streamlined 5-Role Staff Companion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/bms_theme.dart';
import 'features/appointment/presentation/book_appointment_screen.dart';
import 'features/auth/presentation/screens/change_password_screen.dart';
import 'features/auth/presentation/screens/forgot_password_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/otp_verification_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/catalog/presentation/screens/service_catalog_screen.dart';
import 'features/guest/presentation/guest_shell_screen.dart';
import 'features/notification/presentation/screens/notifications_history_screen.dart';
import 'features/notification/presentation/screens/unified_notifications_screen.dart';
import 'features/patient/presentation/screens/export_test_result_screen.dart';
import 'features/patient_portal/presentation/screens/patient_feedback_screen.dart';
import 'features/patient_portal/presentation/tabs/patient_billing_tab.dart';
import 'features/scanQRcheckin/qr_checkin_scanner_screen.dart';
import 'features/shell/presentation/mobile_role_router_screen.dart';
import 'services/bms_auth.dart';

final GlobalKey<NavigatorState> bmsNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final restored = await BmsAuth.restoreSession();

  BmsAuth.onSessionExpired = () {
    bmsNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  };

  final initialRoute = restored ? '/workspace' : '/login';
  runApp(BmsMobileApp(initialRoute: initialRoute));
}

class BmsMobileApp extends StatelessWidget {
  final String initialRoute;

  const BmsMobileApp({super.key, this.initialRoute = '/login'});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: bmsNavigatorKey,
      title: 'BMS MedLab',
      debugShowCheckedModeBanner: false,
      theme: BmsTheme.lightTheme,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
      locale: const Locale('vi', 'VN'),
      initialRoute: initialRoute,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/guest': (_) => const GuestShellScreen(),
        '/workspace': (_) => const MobileRoleRouterScreen(),
        '/home': (_) => const MobileRoleRouterScreen(),
        '/register': (_) => const RegisterScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/change-password': (_) => const ChangePasswordScreen(),
        '/otp-verify': (_) => const OtpVerificationScreen(
          destination: '',
          purpose: 'PasswordReset',
          channel: 'Email',
        ),
        '/service-catalog': (_) => const ServiceCatalogScreen(),
        '/book-appointment': (_) => const BookAppointmentScreen(),
        '/results/export': (_) => const ExportTestResultScreen(),
        '/billing': (_) => const PatientBillingTab(asStandaloneScreen: true),
        '/feedback': (_) => const PatientFeedbackScreen(),
        '/scan-qr-checkin': (_) => const QrCheckinScannerScreen(),
        '/notifications': (_) => const PatientNotificationsScreen(),
        '/notifications-history': (_) => const NotificationsHistoryScreen(),
      },
    );
  }
}
