import 'package:flutter/material.dart';

import '../../../../services/bms_auth.dart';
import '../data/walkin_repository.dart';
import 'register_walkin_page.dart';

/// Ready-to-route wrapper for UC26 (Receptionist walk-in).
/// `'/register-walk-in': (_) => const RegisterWalkInScreen(),`
class RegisterWalkInScreen extends StatelessWidget {
  const RegisterWalkInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!BmsAuth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Walk-in registration')),
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            child: const Text('Sign in'),
          ),
        ),
      );
    }

    // Prefer Receptionist; still allow Admin for testing.
    final role = BmsAuth.userRole.toLowerCase();
    if (role != 'receptionist' && role != 'admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Walk-in registration')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Only Receptionist (or Admin) can register walk-in patients.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return RegisterWalkInPage(repository: WalkInRepository());
  }
}
