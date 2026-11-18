import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../patient_portal/presentation/tabs/patient_profile_tab.dart';

/// Clinical Patient Profile Screen backed by real `/api/patients/me` and `/api/users/me`.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Hồ sơ y tế cá nhân')),
      body: const PatientProfileTab(),
    );
  }
}
