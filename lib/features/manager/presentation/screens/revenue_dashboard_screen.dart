import 'package:flutter/material.dart';
import '../../dashboard/presentation/screens/role_dashboard_screen.dart';

/// Manager Revenue & Operations Dashboard Screen (UC12 / I1-040)
class RevenueDashboardScreen extends StatelessWidget {
  const RevenueDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleDashboardScreen(initialRole: 'Manager');
  }
}
