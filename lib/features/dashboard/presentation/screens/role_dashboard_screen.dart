import 'package:flutter/material.dart';
import '../../../shell/presentation/mobile_role_router_screen.dart';

/// Backward-compatible Role Dashboard route delegating to [MobileRoleRouterScreen].
class RoleDashboardScreen extends StatelessWidget {
  final String? initialRole;

  const RoleDashboardScreen({super.key, this.initialRole});

  @override
  Widget build(BuildContext context) {
    return const MobileRoleRouterScreen();
  }
}
