import 'package:flutter/material.dart';
import 'test_history_screen.dart';

/// Backward-compatible Patient Test Results Screen delegating to [TestHistoryScreen].
class TestResultsScreen extends StatelessWidget {
  const TestResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TestHistoryScreen();
  }
}
