
import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'features/catalog/presentation/screens/service_catalog_screen.dart';
import 'features/doctor-schedule/presentation/screens/doctor_schedule_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/patient_home_screen.dart';
import 'features/auth/presentation/screens/otp_verification_screen.dart';
import 'features/patient/presentation/screens/update_account_screen.dart';

void main() {
  runApp(const BmsMobileApp());
}

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

      // Màn hình giới thiệu BMS và nút đăng nhập.
      home: const MainScreen(),

      // Các route dùng chung trong ứng dụng.
      routes: {
        '/login': (context) => const LoginScreen(),
        '/patient-home': (context) => const PatientHomeScreen(),
        '/otp-verify': (context) => const OtpVerificationScreen(
              destination: 'patient.johnson@gmail.com',
              purpose: 'PasswordReset',
              channel: 'Email',
            ),
        '/service-catalog': (context) => const ServiceCatalogScreen(),
        '/doctor-schedule': (context) => const DoctorScheduleScreen(),
        '/update-account': (context) => const UpdateAccountScreen(),
      },
    );
  }
}

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
            ],
          ),
        ),
      ),
    );
  }
}

