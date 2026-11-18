import 'package:flutter/material.dart';
import '../../../../core/network/bms_http_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';

/// Patient Self-Registration Screen backed by real `POST /api/auth/register`.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final BmsHttpClient _http = const BmsHttpClient();

  final TextEditingController _fullNameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _http.post(
        '/api/auth/register',
        includeAuth: false,
        body: {
          'fullName': _fullNameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'username': _usernameCtrl.text.trim(),
          'phoneNumber': _phoneCtrl.text.trim(),
          'password': _passwordCtrl.text,
          'confirmPassword': _confirmPasswordCtrl.text,
        },
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!res.isSuccess) {
        setState(() {
          _errorMessage = res.extractMessage(
            'Không thể đăng ký tài khoản. Vui lòng kiểm tra lại thông tin.',
          );
        });
        return;
      }

      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            destination: _emailCtrl.text.trim(),
            purpose: 'Registration',
            channel: 'Email',
          ),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verified == true
                ? 'Đăng ký và kích hoạt tài khoản thành công. Vui lòng đăng nhập.'
                : 'Tài khoản đã được ghi nhận. Vui lòng đăng nhập.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on BmsApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể kết nối đến máy chủ BMS.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Đăng ký tài khoản bệnh nhân')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BmsPageHeaderCard(
                  icon: Icons.person_add_alt_1_rounded,
                  badgeText: 'Dành cho bệnh nhân mới',
                  title: 'Tạo tài khoản khám & xét nghiệm',
                  subtitle:
                      'Đặt lịch xét nghiệm trực tuyến, theo dõi hành trình mẫu máu và tra cứu kết quả',
                ),
                const SizedBox(height: 16),
                BmsSoftCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.dangerBorder),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.dangerText,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      TextFormField(
                        controller: _fullNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Họ và tên đầy đủ *',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Vui lòng nhập họ và tên đầy đủ.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _usernameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tên đăng nhập *',
                          prefixIcon: Icon(Icons.account_circle_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().length < 3)
                            ? 'Tên đăng nhập tối thiểu 3 ký tự.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Địa chỉ Email *',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Vui lòng nhập địa chỉ email hợp lệ.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Số điện thoại liên hệ *',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().length < 9)
                            ? 'Vui lòng nhập số điện thoại hợp lệ.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu *',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Mật khẩu cần tối thiểu 6 ký tự.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordCtrl,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Nhập lại mật khẩu *',
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
                        validator: (v) => v != _passwordCtrl.text
                            ? 'Mật khẩu xác nhận không trùng khớp.'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          child: Text(
                            _isLoading ? 'Đang đăng ký...' : 'Đăng ký tài khoản',
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
