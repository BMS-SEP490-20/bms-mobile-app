import 'package:flutter/material.dart';

/// BMS Design System color tokens - Blood Laboratory Management System.
/// Conforms to: AGENTS-DESIGN.md Rules 01-28 (Medical Blue Primary Color Palette).
class AppColors {
  AppColors._();

  // Primary Medical Blue Palette
  static const Color primary = Color(0xFF1E40AF);
  static const Color primaryHover = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFFEFF6FF);
  static const Color primaryDark = Color(0xFF1E3A8A);

  // Clinical Teal / Secondary
  static const Color teal = Color(0xFF0EA5E9);
  static const Color tealLight = Color(0xFFE0F2FE);

  // Semantic Feedback Colors
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFF0FDF4);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);

  static const Color danger = Color(0xFFDC2626);
  static const Color dangerLight = Color(0xFFFEF2F2);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderFocus = Color(0xFF1E40AF);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF94A3B8);
  static const Color textInverse = Color(0xFFFFFFFF);
}
