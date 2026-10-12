import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/mask_sensitive.dart';
import '../widgets/otp_pin_field_group.dart';

/// Màn hình xác thực mã OTP 2 lớp (2FA) bảo mật y tế chuyên biệt trên Mobile (UC03 / I1-013).
/// Tuân thủ: AGENTS-DESIGN.md Rules 01-28 & AGENTS-CODE.md chuẩn Flutter Screen.
class OtpVerificationScreen extends StatefulWidget {
  final String destination;
  final String purpose;
  final String channel;
  final ValueChanged<String>? onVerified;

  const OtpVerificationScreen({
    super.key,
    required this.destination,
    this.purpose = 'PasswordReset',
    this.channel = 'Email',
    this.onVerified,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  String _currentOtp = '';
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _successMessage;

  // Quản lý đếm ngược thời gian gửi lại (60s cooldown)
  int _countdownSeconds = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown(60);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    setState(() {
      _countdownSeconds = seconds;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 1) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _countdownSeconds = 0;
        });
      }
    });
  }

  String _formatCountdown(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Gửi yêu cầu xác thực mã OTP
  Future<void> _handleVerify([String? codeToVerify]) async {
    final otp = codeToVerify ?? _currentOtp;
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Vui lòng nhập đủ 6 chữ số mã xác thực.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final result = await ApiClient.verifyOtp(
      destination: widget.destination,
      otp: otp,
      purpose: widget.purpose,
    );

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
    });

    if (result.isSuccess) {
      setState(() {
        _successMessage = 'Xác thực OTP thành công!';
      });

      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        if (widget.onVerified != null) {
          widget.onVerified!(result.verificationToken ?? '');
        } else {
          Navigator.of(context).pop(true);
        }
      });
    } else {
      setState(() {
        _errorMessage = result.message;
      });
    }
  }

  /// Gửi lại mã OTP (Resend)
  Future<void> _handleResend() async {
    if (_countdownSeconds > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final result = await ApiClient.sendOtp(
      destination: widget.destination,
      purpose: widget.purpose,
      channel: widget.channel,
    );

    if (!mounted) return;

    setState(() {
      _isResending = false;
    });

    if (result.isSuccess) {
      setState(() {
        _successMessage = result.message;
        _currentOtp = '';
      });
      _startCountdown(result.cooldownSeconds);
    } else {
      setState(() {
        _errorMessage = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maskedDestination = MaskSensitive.maskDestination(widget.destination);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Xác Thực Mã OTP',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

              // Biểu tượng Khiên y tế bảo mật Medical Blue
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Nhập Mã Xác Nhận',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Mã xác thực 6 số đã được gửi tới ${widget.channel == 'Email' ? 'Email' : 'Số điện thoại'}:',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 10),

              // Huy hiệu hiển thị thông tin mask
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.channel == 'Email' ? Icons.email_outlined : Icons.phone_android,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      maskedDestination,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Thông báo lỗi nếu có
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Thông báo thành công nếu có
              if (_successMessage != null && _errorMessage == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(color: AppColors.success, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Nhóm 6 ô số nhập PIN OTP
              OtpPinFieldGroup(
                length: 6,
                hasError: _errorMessage != null,
                enabled: !_isVerifying && !_isResending,
                onChanged: (val) {
                  setState(() {
                    _currentOtp = val;
                    if (_errorMessage != null) _errorMessage = null;
                  });
                },
                onCompleted: (val) {
                  _handleVerify(val);
                },
              ),

              const SizedBox(height: 16),

              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
                  SizedBox(width: 4),
                  Text(
                    'Mã có hiệu lực trong vòng 5 phút',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Nút bấm Xác nhận
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_currentOtp.length == 6 && !_isVerifying)
                      ? () => _handleVerify()
                      : null,
                  style: ElevatedButton.overrideWith(
                    ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.textDisabled,
                      disabledForegroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Xác Nhận & Tiếp Tục',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Vùng gửi lại mã với Cooldown 60s
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Chưa nhận được mã? ',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  _isResending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: _countdownSeconds == 0 ? _handleResend : null,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _countdownSeconds > 0
                                ? 'Gửi lại sau (${_formatCountdown(_countdownSeconds)})'
                                : 'Gửi lại mã ngay',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _countdownSeconds > 0
                                  ? AppColors.textDisabled
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
