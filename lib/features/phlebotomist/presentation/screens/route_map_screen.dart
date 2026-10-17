import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Mobile Phlebotomist Dispatch Route Map Screen (UC22 / Iteration 2).
///
/// Features:
/// - Daily dispatched home-collection itinerary with GPS routing.
/// - Patient location mapping, priority ETA calculation, and status updates (En Route, Arrived, Collected).
///
/// Status: Iteration 2 Placeholder.
class RouteMapScreen extends StatelessWidget {
  const RouteMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lộ Trình Đi Lấy Mẫu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                child: const Icon(Icons.map_outlined, size: 56, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bản Đồ Lộ Trình Lấy Mẫu Tại Nhà (UC22)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              const Text(
                'Mô-đun định tuyến di chuyển và chỉ đường GPS cho kỹ thuật viên ngoại viện đang trong lộ trình hoàn thiện của Iteration 2.',
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
