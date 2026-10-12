import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/otp_verification_screen.dart';

void main() {
  runApp(const BmsMobileApp());
}

/// BMS Mobile Application - Blood Laboratory Management System (Mobile Flutter).
/// Client application for Patients, Clinicians, and Phlebotomists.
class BmsMobileApp extends StatelessWidget {
  const BmsMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BMS Mobile App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/otp-verify': (context) => const OtpVerificationScreen(
              destination: 'patient.johnson@gmail.com',
              purpose: 'PasswordReset',
              channel: 'Email',
            ),
      },
    );
  }
}
