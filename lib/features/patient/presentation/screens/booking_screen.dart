import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Patient Online Appointment & Specimen Collection Booking Screen (UC21 / Iteration 2).
///
/// Features:
/// - Selecting clinical test package from catalog.
/// - Picking appointment slot (At-Clinic or Home Phlebotomy Collection).
/// - Confirmation of patient contact and pre-analytical instructions (fasting status).
///
/// Status: Iteration 2 Placeholder.
class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Đặt Lịch Khám & Xét Nghiệm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                child: const Icon(Icons.calendar_month_outlined, size: 56, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'Đặt Lịch Trực Tuyến (UC21)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              const Text(
                'Hệ thống đặt lịch hẹn lấy mẫu tại trung tâm và tại nhà theo khung giờ tự chọn đang được xây dựng theo lộ trình Iteration 2.',
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
