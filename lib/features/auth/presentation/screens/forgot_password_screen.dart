import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import 'otp_verification_screen.dart';

/// Password Recovery Screen backed by real `POST /api/auth/forgot-password`.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final result = await BmsAuth.sendPasswordRecoveryOtp(
      email: _emailCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _successMessage = (result['message'] ??
                'Nếu email tồn tại trên hệ thống, mã khôi phục đã được gửi.')
            .toString();
      } else {
        _errorMessage = (result['message'] ??
                'Không thể gửi mã xác thực. Vui lòng thử lại.')
            .toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Khôi phục mật khẩu')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BmsPageHeaderCard(
                  icon: Icons.lock_reset_rounded,
                  badgeText: 'Bảo mật tài khoản BMS',
                  title: 'Quên mật khẩu đăng nhập',
                  subtitle:
                      'Nhập địa chỉ email đã đăng ký để nhận mã xác thực OTP khôi phục tài khoản',
                ),
                const SizedBox(height: 16),
                BmsSoftCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        onFieldSubmitted: (_) => _handleSendOtp(),
                        decoration: const InputDecoration(
                          labelText: 'Địa chỉ Email đăng ký *',
                          hintText: 'tenban@domain.vn',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (val) {
                          final email = val?.trim() ?? '';
                          if (email.isEmpty || !email.contains('@')) {
                            return 'Vui lòng nhập địa chỉ email hợp lệ.';
                          }
                          return null;
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        BmsErrorState(message: _errorMessage!),
                      ],
                      if (_successMessage != null) ...[
                        const SizedBox(height: 12),
                        BmsSoftCard(
                          backgroundColor: AppColors.successLight,
                          borderColor: AppColors.successBorder,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _successMessage!,
                                style: const TextStyle(
                                  color: AppColors.successText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => OtpVerificationScreen(
                                        destination: _emailCtrl.text.trim(),
                                        purpose: 'PasswordReset',
                                        channel: 'Email',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.verified_user_outlined,
                                  size: 18,
                                ),
                                label: const Text('Nhập mã xác thực OTP'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _handleSendOtp,
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _isLoading
                                ? 'Đang gửi mã...'
                                : 'Gửi mã khôi phục',
                          ),
                        ),
                      ),
                    ],
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
