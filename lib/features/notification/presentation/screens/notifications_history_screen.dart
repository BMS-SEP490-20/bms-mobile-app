import 'package:flutter/material.dart';
import 'unified_notifications_screen.dart';

/// Backward-compatible Notification History route delegating to [PatientNotificationsScreen].
class NotificationsHistoryScreen extends StatelessWidget {
  const NotificationsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PatientNotificationsScreen();
  }
}
