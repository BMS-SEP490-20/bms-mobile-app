import 'package:flutter/material.dart';

import '../../../../services/bms_auth.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment_models.dart';
import 'book_appointment_page.dart';

/// Ready-to-route wrapper for UC21.
/// Uses [BmsAuth] for token + patient id. Register in main:
/// `'/book-appointment': (_) => const BookAppointmentScreen(),`
class BookAppointmentScreen extends StatelessWidget {
  final List<String> initialPackageIds;
  final List<TestPackageOption>? packages;

  const BookAppointmentScreen({
    super.key,
    this.initialPackageIds = const [],
    this.packages,
  });

  @override
  Widget build(BuildContext context) {
    if (!BmsAuth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Book appointment')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please sign in to book an appointment.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final patientId = AppointmentRepository.currentPatientId();
    if (patientId == null || patientId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('Patient id not found in session. Sign in as Patient.'),
        ),
      );
    }

    final packageList = packages ??
        const [
          TestPackageOption(
            packageId: 'PKG-CBC',
            packageName: 'CBC – Complete blood count',
            price: 150000,
          ),
          TestPackageOption(
            packageId: 'PKG-LIPID',
            packageName: 'Lipid panel',
            price: 220000,
          ),
        ];

    return BookAppointmentPage(
      patientId: patientId,
      repository: AppointmentRepository(),
      packages: packageList,
      initialPackageIds: initialPackageIds,
    );
  }
}
