import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../reception_portal/presentation/tabs/reception_billing_tab.dart';

/// Electronic Receipt & Invoice Generation Screen backed by real `/api/invoices` & `/api/receipts`.
class GenerateReceiptScreen extends StatelessWidget {
  final Map<String, dynamic>? initialAppointment;

  const GenerateReceiptScreen({super.key, this.initialAppointment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Xuất biên lai & Viện phí')),
      body: const ReceptionBillingTab(),
    );
  }
}
