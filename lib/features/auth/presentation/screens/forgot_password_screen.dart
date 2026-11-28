import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../widgets/otp_pin_field_group.dart';
import 'register_screen.dart';

/// Complete 3-Step Password Recovery Screen matching Web `ForgotPassword.jsx` 1-1:
/// Step 1: Enter registered Email -> `POST /api/auth/forgot`
/// Step 2: Verify 6-digit OTP -> `POST /api/auth/verify-reset-otp` (60s resend countdown)
/// Step 3: Set strong new password -> `POST /api/auth/reset` -> return to Login
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 1;
  bool _loading = false;
  String? _error;
  String? _message;

  final TextEditingController _emailCtrl = TextEditingController();
  String _otp = '';
  final TextEditingController _newPwdCtrl = TextEditingController();
  final TextEditingController _confirmPwdCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  int _countdown = 60;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        t.cancel();
        setState(() => _countdown = 0);
      }
    });
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    final email = _emailCtrl.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() {
        _error = 'Vui lòng nhập địa chỉ Email hợp lệ đã đăng ký BMS.';
        _message = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    final res = await BmsAuth.sendPasswordRecoveryOtp(email: email);
    if (!mounted) return;
    setState(() => _loading = false);

    if (res['success'] == true) {
      setState(() {
        _step = 2;
        _otp = '';
        _message = 'Mã OTP khôi phục 6 chữ số đã gửi đến $email.';
      });
      _startCountdown();
    } else {
      setState(
        () => _error =
            res['message']?.toString() ?? 'Không thể gửi mã khôi phục.',
      );
    }
  }

  Future<void> _verifyOtp([String? code]) async {
    FocusScope.of(context).unfocus();
    final otpVal = (code ?? _otp).trim();
    if (otpVal.length != 6) {
      setState(() => _error = 'Vui lòng nhập đủ 6 chữ số của mã OTP.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    final res = await BmsAuth.verifyPasswordResetOtp(
      email: _emailCtrl.text.trim(),
      otp: otpVal,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (res['success'] == true) {
      setState(() {
        _step = 3;
        _message =
            res['message']?.toString() ??
            'Mã OTP hợp lệ. Tiếp tục đặt mật khẩu mới.';
        _newPwdCtrl.clear();
        _confirmPwdCtrl.clear();
      });
    } else {
      setState(
        () => _error =
            res['message']?.toString() ??
            'Mã OTP không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    final pwd = _newPwdCtrl.text;
    final confirm = _confirmPwdCtrl.text;

    if (pwd.length < 8 ||
        !RegExp(r'[A-Z]').hasMatch(pwd) ||
        !RegExp(r'[a-z]').hasMatch(pwd) ||
        !RegExp(r'[0-9]').hasMatch(pwd) ||
        !RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pwd)) {
      setState(() {
        _error =
            'Mật khẩu mới phải có ít nhất 8 ký tự gồm chữ hoa, chữ thường, số và ký tự đặc biệt.';
      });
      return;
    }
    if (pwd != confirm) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    final res = await BmsAuth.resetPassword(
      email: _emailCtrl.text.trim(),
      otp: _otp.trim(),
      newPassword: pwd,
      confirmNewPassword: confirm,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (res['success'] == true) {
      Navigator.of(context).pop(true);
    } else {
      final msg =
          res['message']?.toString() ?? 'Đặt lại mật khẩu thất bại.';
      final code = res['errorCode']?.toString() ?? '';
      setState(() {
        _error = msg;
        if (msg.toLowerCase().contains('otp') || code.startsWith('OTP_')) {
          _step = 2;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepBadge = _step == 1
        ? 'BƯỚC 1 / 3 • XÁC THỰC EMAIL'
        : _step == 2
        ? 'BƯỚC 2 / 3 • XÁC NHẬN MÃ OTP'
        : 'BƯỚC 3 / 3 • ĐẶT MẬT KHẨU MỚI';

    final title = _step == 1
        ? 'Khôi phục mật khẩu'
        : _step == 2
        ? 'Nhập mã OTP 6 chữ số'
        : 'Thiết lập mật khẩu mới';

    final subtitle = _step == 1
        ? 'Nhập địa chỉ email đã đăng ký tài khoản BMS để nhận mã xác thực.'
        : _step == 2
        ? 'Mã OTP đã được gửi đến ${_emailCtrl.text.trim()}.'
        : 'OTP đã được xác thực. Tạo mật khẩu mới theo quy định bảo mật BMS.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Khôi phục mật khẩu')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BmsPageHeaderCard(
                icon: Icons.key_rounded,
                badgeText: stepBadge,
                title: title,
                subtitle: subtitle,
              ),
              const SizedBox(height: 14),
              BmsSoftCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.dangerBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.dangerText,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_error!.contains('không tồn tại')) ...[
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                ),
                                child: const Text(
                                  'Chưa có tài khoản? Đăng ký ngay',
                                  style: TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_message != null && _error == null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.successBorder),
                        ),
                        child: Text(
                          _message!,
                          style: const TextStyle(
                            color: AppColors.successText,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_step == 1) ...[
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_loading,
                        decoration: const InputDecoration(
                          labelText: 'Địa chỉ Email đăng ký *',
                          hintText: 'name@example.com',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _loading ? null : _sendOtp,
                          child: Text(
                            _loading
                                ? 'Đang gửi mã OTP...'
                                : 'Gửi mã khôi phục',
                          ),
                        ),
                      ),
                    ] else if (_step == 2) ...[
                      OtpPinFieldGroup(
                        length: 6,
                        hasError: _error != null,
                        enabled: !_loading,
                        onChanged: (v) => setState(() => _otp = v),
                        onCompleted: _verifyOtp,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: (_countdown == 0 && !_loading)
                              ? _sendOtp
                              : null,
                          child: Text(
                            _countdown > 0
                                ? 'Gửi lại mã sau ${_countdown}s'
                                : 'Gửi lại mã OTP',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: (_loading || _otp.length != 6)
                              ? null
                              : _verifyOtp,
                          child: Text(
                            _loading ? 'Đang xác nhận...' : 'Xác nhận OTP',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                _step = 1;
                                _otp = '';
                                _error = null;
                                _message = null;
                              }),
                        child: const Text('Đổi email khác'),
                      ),
                    ] else ...[
                      TextField(
                        controller: _newPwdCtrl,
                        obscureText: _obscureNew,
                        enabled: !_loading,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới (≥8 ký tự) *',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscureNew = !_obscureNew),
                            icon: Icon(
                              _obscureNew
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPwdCtrl,
                        obscureText: _obscureConfirm,
                        enabled: !_loading,
                        decoration: InputDecoration(
                          labelText: 'Xác nhận mật khẩu mới *',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _loading ? null : _resetPassword,
                          child: Text(
                            _loading
                                ? 'Đang đặt lại mật khẩu...'
                                : 'Hoàn tất đặt lại mật khẩu',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
