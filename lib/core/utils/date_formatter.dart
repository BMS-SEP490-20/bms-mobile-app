/// Clinical date and time formatting utilities for BMS Mobile App.
/// Conforms to: Production Standards & AGENTS-DESIGN.md.
library;

import 'package:intl/intl.dart';

/// Centralized date and time formatter supporting Vietnamese medical standards.
class DateFormatter {
  DateFormatter._();

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _isoFormat = DateFormat('yyyy-MM-dd');

  /// Formats a [DateTime] into standard Vietnamese display date: `dd/MM/yyyy`.
  static String formatDate(DateTime? date) {
    if (date == null) return '—';
    return _dateFormat.format(date);
  }

  /// Formats an ISO-8601 string or [DateTime] into `dd/MM/yyyy HH:mm`.
  static String formatDateTime(dynamic value) {
    if (value == null) return '—';
    DateTime? dt;
    if (value is DateTime) {
      dt = value;
    } else if (value is String && value.isNotEmpty) {
      dt = DateTime.tryParse(value);
    }
    if (dt == null) return '—';
    return _dateTimeFormat.format(dt.toLocal());
  }

  /// Formats time component only: `HH:mm`.
  static String formatTime(DateTime? date) {
    if (date == null) return '—';
    return _timeFormat.format(date.toLocal());
  }

  /// Formats date for API queries: `yyyy-MM-dd`.
  static String toIsoDate(DateTime? date) {
    if (date == null) return '';
    return _isoFormat.format(date);
  }
}
