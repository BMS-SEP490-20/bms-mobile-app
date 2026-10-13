
import 'package:flutter/material.dart';
import 'package:bms_mobile_app/services/bms_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  static const blue = Color(0xFF0353E9);
  static const navy = Color(0xFF0F2743);
  static const muted = Color(0xFF64748B);

  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> handleSendOtp() async {
    FocusScope.of(context).unfocus();

    if (!formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      // Gọi API gửi OTP khôi phục mật khẩu.
      final result = await BmsAuth.sendPasswordRecoveryOtp(
        email: emailController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;

        if (result['success'] == true) {
          successMessage = result['message']?.toString() ??
              'Nếu email tồn tại trong hệ thống, mã OTP sẽ được gửi đến hộp thư của bạn.';
        } else {
          errorMessage = result['message']?.toString() ??
              'Không thể gửi mã OTP. Vui lòng thử lại.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
        'Không thể kết nối máy chủ. Vui lòng thử lại.';
      });
    }
  }

  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: muted),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFCBD5E1),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFCBD5E1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: blue,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header đồng bộ với LoginScreen.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  24, 20, 24, 38,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      navy,
                      Color(0xFF1E1B4B),
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(26),
                  ),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: blue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'BMS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Forgot password?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Blood Laboratory Management System',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF94B0CE),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // Form khôi phục mật khẩu.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  24, 28, 24, 32,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Khôi phục mật khẩu',
                        style: TextStyle(
                          color: navy,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Nhập email đã đăng ký. Chúng tôi sẽ gửi mã OTP để xác minh tài khoản.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 26),

                      const Text(
                        'Địa chỉ email',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enabled: !isLoading,
                        onFieldSubmitted: (_) => handleSendOtp(),
                        decoration: inputDecoration(
                          hint: 'name@example.com',
                          icon: Icons.email_outlined,
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';

                          if (email.isEmpty) {
                            return 'Vui lòng nhập địa chỉ email.';
                          }

                          if (!RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(email)) {
                            return 'Địa chỉ email không hợp lệ.';
                          }

                          return null;
                        },
                        onChanged: (_) {
                          setState(() {
                            errorMessage = null;
                            successMessage = null;
                          });
                        },
                      ),

                      const SizedBox(height: 12),

                      if (errorMessage != null)
                        _buildMessage(
                          message: errorMessage!,
                          isError: true,
                        ),

                      if (successMessage != null)
                        _buildMessage(
                          message: successMessage!,
                          isError: false,
                        ),

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed:
                          isLoading ? null : handleSendOtp,
                          icon: isLoading
                              ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            isLoading
                                ? 'Đang gửi mã OTP...'
                                : 'Gửi mã khôi phục',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: blue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                            const Color(0xFF93B4F8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                          ),
                          label: const Text('Quay lại đăng nhập'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: navy,
                            side: const BorderSide(
                              color: Color(0xFFCBD5E1),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: blue,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Hãy sử dụng email đã đăng ký với BMS. Nếu không nhận được mã, vui lòng kiểm tra hộp thư rác hoặc liên hệ bộ phận hỗ trợ.',
                                style: TextStyle(
                                  color: Color(0xFF1E40AF),
                                  fontSize: 12,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Center(
                        child: Text(
                          'BMS Health · Secure Account Recovery',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessage({
    required String message,
    required bool isError,
  }) {
    final background = isError
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFF0FDF4);

    final border = isError
        ? const Color(0xFFFECACA)
        : const Color(0xFFBBF7D0);

    final foreground = isError
        ? const Color(0xFFB91C1C)
        : const Color(0xFF166534);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: foreground,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}