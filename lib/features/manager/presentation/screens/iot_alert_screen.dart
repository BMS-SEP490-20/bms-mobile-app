import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';

/// Cold-Chain Telemetry Notice Screen in Vietnamese.
class IotAlertScreen extends StatelessWidget {
  const IotAlertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Giám sát nhiệt độ tủ mẫu')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: BmsEmptyState(
          icon: Icons.thermostat_outlined,
          title: 'Giám sát tủ lạnh bảo quản mẫu trên BMS Web',
          subtitle:
              'Biểu đồ nhiệt độ kho lạnh theo thời gian thực được tích hợp tại Trạm làm việc BMS Web.',
        ),
      ),
    );
  }
}
