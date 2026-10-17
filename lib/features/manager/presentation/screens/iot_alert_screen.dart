import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// IoT Refrigerator & Specimen Cold-Chain Telemetry Monitoring Screen (UC28 / Iteration 3).
///
/// Features:
/// - Real-time MQTT telemetry from specimen storage refrigerators (2-8°C).
/// - Instant threshold alerts (over-temperature, power disruption, door ajar).
/// - Incident logging and SMS dispatch to lab managers.
///
/// Status: Iteration 3 Placeholder.
class IotAlertScreen extends StatelessWidget {
  const IotAlertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cảnh Báo IoT Tủ Lạnh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                child: const Icon(Icons.thermostat_outlined, size: 56, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'IoT Cold-Chain Telemetry (UC28)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              const Text(
                'Mô-đun giám sát nhiệt độ tủ lưu trữ mẫu tự động (2-8°C) và phát hiện sự cố theo thời gian thực đang trong lộ trình hoàn thiện của Iteration 3.',
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
