/// Utility functions for masking Personally Identifiable Information (PII) on mobile devices.
/// Conforms to: NIST SP 800-63B & AGENTS-DESIGN.md Rule 22.
class MaskSensitive {
  MaskSensitive._();

  /// Masks an email address: "tanphat@gmail.com" -> "t***t@gmail.com"
  static String maskEmail(String email) {
    if (email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final username = parts[0];
    final domain = parts[1];

    if (username.length <= 2) {
      return '${username[0]}***@$domain';
    }

    final first = username[0];
    final last = username[username.length - 1];
    return '$first***$last@$domain';
  }

  /// Masks a telephone number: "0901234567" -> "090****567"
  static String maskPhone(String phone) {
    if (phone.isEmpty) return '';
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length < 7) return cleaned;

    final prefix = cleaned.substring(0, 3);
    final suffix = cleaned.substring(cleaned.length - 3);
    return '$prefix****$suffix';
  }

  /// Automatically detects whether the destination is an email or phone number and masks it.
  static String maskDestination(String destination) {
    if (destination.contains('@')) {
      return maskEmail(destination);
    }
    return maskPhone(destination);
  }
}
