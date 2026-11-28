import 'package:flutter/material.dart';
import '../../../../core/network/bms_http_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';

/// Change Password Screen matching Web `ChangePassword.jsx` 1-1 (`POST /api/auth/passwords/change`).
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

  ({double score, String label, Color color}) _evaluateStrength(String pwd) {
    if (pwd.isEmpty) {
      return (score: 0, label: '', color: AppColors.danger);
    }
    var score = 0.0;
    if (pwd.length >= 6) score += 0.25;
    if (pwd.length >= 10) score += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(pwd)) score += 0.25;
    if (RegExp(r'[0-9!@#$%^&*]').hasMatch(pwd)) score += 0.25;

    if (score <= 0.25) {
      return (score: score, label: 'Yếu', color: AppColors.danger);
    }
    if (score <= 0.50) {
      return (score: score, label: 'Trung bình', color: AppColors.warning);
    }
    if (score <= 0.75) {
      return (score: score, label: 'Khá', color: AppColors.teal);
    }
    return (score: 1.0, label: 'Rất mạnh', color: AppColors.success);
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
    final strength = _evaluateStrength(_newPasswordCtrl.text);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Đổi mật khẩu tài khoản')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BmsPageHeaderCard(
                  icon: Icons.security_rounded,
                  badgeText: 'Bảo mật đăng nhập',
                  title: 'Đổi mật khẩu bảo mật',
                  subtitle:
                      'Cập nhật mật khẩu định kỳ để bảo vệ tài khoản và hồ sơ y tế',
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
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới *',
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
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Mật khẩu mới tối thiểu 6 ký tự.'
                            : null,
                      ),
                      if (_newPasswordCtrl.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Độ mạnh mật khẩu',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              strength.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: strength.color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: strength.score,
                            minHeight: 6,
                            backgroundColor: AppColors.surfaceMuted,
                            valueColor: AlwaysStoppedAnimation(strength.color),
                          ),
                        ),
                      ],
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
