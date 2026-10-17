import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Mobile Phlebotomist Specimen Barcode & RFID Scanner Screen (UC22 / Iteration 2).
///
/// Features:
/// - Real-time camera barcode and QR scanning for primary sample tubes (EDTA, Heparin, Serum).
/// - Instant identity cross-matching against patient order to prevent sample mix-up.
/// - Cold-chain RFID tag verification.
///
/// Status: Iteration 2 Placeholder.
class BarcodeScannerScreen extends StatelessWidget {
  const BarcodeScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quét Barcode Ống Mẫu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                child: const Icon(Icons.qr_code_scanner_outlined, size: 56, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'Quét Mã Ống Nghiệm (UC22)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tính năng nhận diện mã vạch Code128 / DataMatrix ống nghiệm và đối soát thông tin bệnh nhân đang trong lộ trình hoàn thiện của Iteration 2.',
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
