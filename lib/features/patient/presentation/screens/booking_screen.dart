import 'package:flutter/material.dart';
import '../../../appointment/presentation/book_appointment_screen.dart';

/// Backward-compatible Patient Booking route delegating to [BookAppointmentScreen].
class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BookAppointmentScreen();
  }
}
