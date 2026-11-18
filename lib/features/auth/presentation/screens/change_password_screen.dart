import 'package:flutter/material.dart';
import '../../../../core/network/bms_http_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';

/// Change Password Screen backed by real `POST /api/auth/passwords/change`.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final BmsHttpClient _http = const BmsHttpClient();

  final TextEditingController _currentPasswordCtrl = TextEditingController();
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordCtrl.text == _currentPasswordCtrl.text) {
      setState(() {
        _errorMessage = 'Mật khẩu mới không được trùng với mật khẩu hiện tại.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _http.post(
        '/api/auth/passwords/change',
        body: {
          'currentPassword': _currentPasswordCtrl.text,
          'newPassword': _newPasswordCtrl.text,
          'confirmNewPassword': _confirmPasswordCtrl.text,
        },
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!res.isSuccess) {
        setState(() {
          _errorMessage = res.extractMessage(
            'Không thể đổi mật khẩu. Vui lòng kiểm tra mật khẩu hiện tại.',
          );
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.extractMessage('Đã cập nhật mật khẩu thành công.'),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
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
        _errorMessage = 'Không thể kết nối máy chủ BMS.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Đổi mật khẩu tài khoản')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BmsPageHeaderCard(
                  icon: Icons.security_rounded,
                  badgeText: 'Bảo mật đăng nhập',
                  title: 'Thay đổi mật khẩu',
                  subtitle:
                      'Mật khẩu mới cần tối thiểu 6 ký tự và khác với mật khẩu đang sử dụng',
                ),
                const SizedBox(height: 16),
                BmsSoftCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        BmsErrorState(message: _errorMessage!),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _currentPasswordCtrl,
                        obscureText: _obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu hiện tại *',
                          prefixIcon: const Icon(Icons.lock_clock_outlined),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscureCurrent = !_obscureCurrent,
                            ),
                            icon: Icon(
                              _obscureCurrent
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Vui lòng nhập mật khẩu hiện tại.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPasswordCtrl,
                        obscureText: _obscureNew,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới *',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscureNew = !_obscureNew,
                            ),
                            icon: Icon(
                              _obscureNew
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Mật khẩu mới tối thiểu 6 ký tự.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordCtrl,
                        obscureText: _obscureConfirm,
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
                        validator: (v) => v != _newPasswordCtrl.text
                            ? 'Mật khẩu xác nhận không trùng khớp.'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _handleChangePassword,
                          child: Text(
                            _isLoading
                                ? 'Đang cập nhật...'
                                : 'Cập nhật mật khẩu',
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
