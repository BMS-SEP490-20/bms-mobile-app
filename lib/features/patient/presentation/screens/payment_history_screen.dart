import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../patient_portal/presentation/tabs/patient_billing_tab.dart';

/// Backward-compatible Patient Payment History Screen backed by [PatientBillingTab].
class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Lịch sử viện phí & Hóa đơn')),
      body: const PatientBillingTab(),
    );
  }
}
