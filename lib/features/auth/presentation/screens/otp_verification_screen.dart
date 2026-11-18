import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/mask_sensitive.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../widgets/otp_pin_field_group.dart';

/// 6-Digit OTP Verification Screen in Vietnamese Soft Healthcare SaaS design.
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
    setState(() => _countdownSeconds = seconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds > 1) {
        setState(() => _countdownSeconds--);
      } else {
        timer.cancel();
        setState(() => _countdownSeconds = 0);
      }
    });
  }

  String _formatCountdown(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _handleVerify([String? codeToVerify]) async {
    final otp = codeToVerify ?? _currentOtp;
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Vui lòng nhập đầy đủ 6 chữ số mã xác thực.';
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
    setState(() => _isVerifying = false);

    if (result.isSuccess) {
      if (widget.onVerified != null) {
        widget.onVerified!(result.verificationToken ?? '');
      } else {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() => _errorMessage = result.message);
    }
  }

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
    setState(() => _isResending = false);

    if (result.isSuccess) {
      setState(() {
        _successMessage = result.message;
        _currentOtp = '';
      });
      _startCountdown(result.cooldownSeconds);
    } else {
      setState(() => _errorMessage = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masked = widget.destination.trim().isEmpty
        ? 'hộp thư đăng ký'
        : MaskSensitive.maskDestination(widget.destination);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Xác thực mã OTP')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: BmsSoftCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 32,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nhập mã xác thực 6 chữ số',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Mã OTP đã được gửi đến ${widget.channel == 'Email' ? 'email' : 'số điện thoại'}: $masked',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                if (_errorMessage != null) ...[
                  BmsErrorState(message: _errorMessage!),
                  const SizedBox(height: 14),
                ],
                if (_successMessage != null && _errorMessage == null) ...[
                  BmsSoftCard(
                    backgroundColor: AppColors.successLight,
                    borderColor: AppColors.successBorder,
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(
                        color: AppColors.successText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                OtpPinFieldGroup(
                  length: 6,
                  hasError: _errorMessage != null,
                  enabled: !_isVerifying && !_isResending,
                  onChanged: (val) {
                    setState(() {
                      _currentOtp = val;
                      _errorMessage = null;
                    });
                  },
                  onCompleted: _handleVerify,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Mã xác thực có hiệu lực trong vòng 5 phút',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: (_currentOtp.length == 6 && !_isVerifying)
                        ? () => _handleVerify()
                        : null,
                    child: Text(
                      _isVerifying ? 'Đang kiểm tra...' : 'Xác nhận & Tiếp tục',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: _countdownSeconds == 0 && !_isResending
                      ? _handleResend
                      : null,
                  child: Text(
                    _countdownSeconds > 0
                        ? 'Gửi lại mã sau (${_formatCountdown(_countdownSeconds)})'
                        : 'Gửi lại mã OTP ngay',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
