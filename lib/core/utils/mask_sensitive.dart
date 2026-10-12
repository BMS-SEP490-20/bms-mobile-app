/// Tiện ích che mờ thông tin cá nhân (PII) như Email và Số điện thoại trên Mobile App.
/// Tuân thủ: NIST SP 800-63B & AGENTS-DESIGN.md Rule 22.
class MaskSensitive {
  MaskSensitive._();

  /// Che địa chỉ email: "tanphat@gmail.com" -> "t***t@gmail.com"
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

  /// Che số điện thoại: "0901234567" -> "090****567"
  static String maskPhone(String phone) {
    if (phone.isEmpty) return '';
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length < 7) return cleaned;

    final prefix = cleaned.substring(0, 3);
    final suffix = cleaned.substring(cleaned.length - 3);
    return '$prefix****$suffix';
  }

  /// Tự động nhận diện Email hoặc Số điện thoại để áp dụng mặt nạ phù hợp.
  static String maskDestination(String destination) {
    if (destination.contains('@')) {
      return maskEmail(destination);
    }
    return maskPhone(destination);
  }
}
