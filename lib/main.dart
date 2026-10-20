/// Blood Laboratory Management System (BMS) - Mobile Client Application.
///
/// Provides cross-platform access for Patients, Clinical Staff, and Mobile Phlebotomists.
/// Conforms to: Production Engineering Standards & AGENTS-CODE.md.
library;

import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'features/auth/presentation/screens/change_password_screen.dart';
import 'features/auth/presentation/screens/forgot_password_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/otp_verification_screen.dart';
import 'features/auth/presentation/screens/patient_home_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/appointment/presentation/book_appointment_screen.dart';
import 'features/catalog/presentation/screens/service_catalog_screen.dart';
import 'features/dashboard/presentation/screens/role_dashboard_screen.dart';
import 'features/doctor-schedule/presentation/screens/doctor_schedule_screen.dart';
import 'features/patient/presentation/screens/create_guest_profile_screen.dart';
import 'features/walkin/presentation/register_walkin_screen.dart';
import 'features/patient/presentation/screens/update_account_screen.dart';
import 'features/queue/presentation/screens/queue_ticket_screen.dart';
import 'features/patient/presentation/screens/process_payment_screen.dart';
import 'features/patient/presentation/screens/export_test_result_screen.dart';
import 'features/dashboard/presentation/screens/configure_iot_thresholds_screen.dart';
import 'features/laboratory/presentation/screens/verify_test_results_screen.dart';
import 'features/laboratory/presentation/screens/trace_sample_origin_screen.dart';

void main() {
  runApp(const BmsMobileApp());
}

/// Root application widget establishing MaterialApp configuration, branding theme, and navigation routes.
class BmsMobileApp extends StatelessWidget {
  const BmsMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BMS Health',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        fontFamily: 'Roboto',
      ),

      // Landing introduction screen with sign-in trigger
      home: const MainScreen(),

      // Centralized named routes registry across Iteration 1 & 2 use cases
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/change-password': (context) => const ChangePasswordScreen(),
        '/patient-home': (context) => const PatientHomeScreen(),
        '/role-dashboard': (context) => const RoleDashboardScreen(),
        '/otp-verify': (context) => const OtpVerificationScreen(
              destination: 'patient.johnson@gmail.com',
              purpose: 'PasswordReset',
              channel: 'Email',
            ),
        '/service-catalog': (context) => const ServiceCatalogScreen(),
        '/search-test-packages': (context) => const ServiceCatalogScreen(),
        '/create-guest-profile': (context) => const CreateGuestProfileScreen(),
        '/doctor-schedule': (context) => const DoctorScheduleScreen(),
        '/update-account': (context) => const UpdateAccountScreen(),
        '/book-appointment': (context) => const BookAppointmentScreen(),
        '/register-walkin': (context) => const RegisterWalkInScreen(),
        '/queue-ticket': (context) => const QueueTicketScreen(),
        '/payment': (context) => const ProcessPaymentScreen(),
        '/checkout': (context) => const ProcessPaymentScreen(),
        '/results/export': (context) => const ExportTestResultScreen(),
        '/export-results': (context) => const ExportTestResultScreen(),
        '/patient/results': (context) => const ExportTestResultScreen(),
        '/iot-thresholds': (context) => const ConfigureIotThresholdsScreen(),
        '/manager/iot-thresholds': (context) => const ConfigureIotThresholdsScreen(),
        '/verify-results': (context) => const VerifyTestResultsScreen(),
        '/laboratory/verify-results': (context) => const VerifyTestResultsScreen(),
        '/sample-trace': (context) => const TraceSampleOriginScreen(),
        '/laboratory/sample-trace': (context) => const TraceSampleOriginScreen(),
        '/trace-sample': (context) => const TraceSampleOriginScreen(),
      },
    );
  }
}

/// Initial landing screen presenting the BMS Health brand and entry points.
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bloodtype_rounded,
                size: 80,
                color: Color(0xFF0353E9),
              ),
              const SizedBox(height: 16),
              const Text(
                'BMS Health',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F2743),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Blood Laboratory Management System',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Đăng nhập'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    ).then((result) {
                      if (result == true && context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PatientHomeScreen(),
                          ),
                        );
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.biotech_outlined),
                  label: const Text('Tra cứu Gói Xét Nghiệm (UC20)'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ServiceCatalogScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.confirmation_number_outlined),
                  label: const Text('Bốc Số Tiếp Nhận (UC27)'),
                  onPressed: () {
                    Navigator.pushNamed(context, '/queue-ticket');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
