import 'package:flutter/material.dart';

import 'features/catalog/presentation/screens/service_catalog_screen.dart';
import 'features/doctor-schedule/presentation/screens/doctor_schedule_screen.dart';

/// Application entry point.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BmsApp());
}

/// Root widget of the BMS mobile application.
class BmsApp extends StatelessWidget {
  /// Creates the root app widget.
  const BmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BMS – Laboratory Services',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      // UC01 – View Service Catalog is the home screen for now.
      // Other features will be added via routes / navigation later.
      home: const DoctorScheduleScreen(),
    );
  }
}