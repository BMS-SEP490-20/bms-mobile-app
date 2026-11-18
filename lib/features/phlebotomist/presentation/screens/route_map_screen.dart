import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';

/// Home Collection Phlebotomy Dispatch Notice Screen.
class RouteMapScreen extends StatelessWidget {
  const RouteMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Điều phối lấy mẫu tận nơi')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: BmsEmptyState(
          icon: Icons.location_on_outlined,
          title: 'Lịch lấy mẫu được quản lý theo lịch hẹn',
          subtitle:
              'Vui lòng kiểm tra danh sách lịch hẹn lấy mẫu tận nơi tại phân hệ Tiếp đón Lễ tân.',
        ),
      ),
    );
  }
}
