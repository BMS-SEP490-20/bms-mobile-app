import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Patient Clinical Laboratory Test Results Screen (UC24 / Iteration 2).
///
/// Features:
/// - Viewing validated laboratory report sheets with reference ranges.
/// - Flagging abnormal/critical values (Panic Values) with visual indicators.
/// - Secure PDF export and digital signature verification.
///
/// Status: Iteration 2 Placeholder.
class TestResultsScreen extends StatelessWidget {
  const TestResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kết Quả Xét Nghiệm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment_turned_in_outlined, size: 56, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tra Cứu Kết Quả Xét Nghiệm (UC24)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              const Text(
                'Hồ sơ kết quả phân tích chỉ số sinh hóa, huyết học kèm chữ ký số của Bác sĩ trưởng khoa đang trong lộ trình hoàn thiện của Iteration 2.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
