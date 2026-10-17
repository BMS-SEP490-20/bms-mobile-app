import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Patient Medical Billing & Payment History Screen (UC23 / Iteration 2).
///
/// Features:
/// - Viewing transaction receipts, billing status, and online payment methods (VNPay, MoMo, Kiosk POS).
/// - Electronic invoice download and payment verification receipts.
///
/// Status: Iteration 2 Placeholder.
class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch Sử Thanh Toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                child: const Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'Lịch Sử Viện Phí & Hóa Đơn (UC23)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tính năng tra cứu lịch sử giao dịch viện phí và biên lai thanh toán điện tử VNPay/MoMo đang trong lộ trình hoàn thiện của Iteration 2.',
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
