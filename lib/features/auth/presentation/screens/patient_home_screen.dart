import 'package:flutter/material.dart';
import '../../../shell/presentation/mobile_role_router_screen.dart';

/// Backward-compatible route entry delegating directly to [MobileRoleRouterScreen].
class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MobileRoleRouterScreen();
  }
}
