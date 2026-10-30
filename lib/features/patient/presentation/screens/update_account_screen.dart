import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/account_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Clinical Update Account Information Screen (UC09).
/// Allows patients and users to update their profile username/email and change their password.
class UpdateAccountScreen extends StatefulWidget {
  const UpdateAccountScreen({super.key});

  @override
  State<UpdateAccountScreen> createState() => _UpdateAccountScreenState();
}

class _UpdateAccountScreenState extends State<UpdateAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _fetching = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _accountId;
  String _userRole = 'Patient';
  int _roleId = 5;
  int _status = 1;

  @override
  void initState() {
    super.initState();
    _loadCurrentAccount();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentAccount() async {
    setState(() => _fetching = true);
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');

    if (userStr != null) {
      try {
        final userData = jsonDecode(userStr) as Map<String, dynamic>;
        _accountId = userData['id']?.toString() ?? userData['userId']?.toString() ?? 'P-10023';
        _usernameController.text = (userData['username'] ?? userData['fullName'] ?? 'Nguyễn Văn An').toString();
        _emailController.text = (userData['email'] ?? 'patient.an@gmail.com').toString();
        _userRole = (userData['role'] ?? 'Patient').toString();
        if (userData['roleId'] != null) {
          _roleId = int.tryParse(userData['roleId'].toString()) ?? 5;
        }

        if (_accountId != null && _accountId!.isNotEmpty) {
          final res = await AccountService.getAccountById(_accountId!);
          if (res['success'] == true && res['data'] != null) {
            final acc = res['data'];
            if (acc['username'] != null) _usernameController.text = acc['username'].toString();
            if (acc['fullName'] != null) _usernameController.text = acc['fullName'].toString();
            if (acc['email'] != null) _emailController.text = acc['email'].toString();
            if (acc['roleId'] != null) _roleId = int.tryParse(acc['roleId'].toString()) ?? _roleId;
            if (acc['status'] != null) _status = int.tryParse(acc['status'].toString()) ?? _status;
          }
        }
      } catch (_) {}
    } else {
      // Default demo patient data
      _accountId = 'P-2026-08192';
      _usernameController.text = 'Nguyễn Văn An';
      _emailController.text = 'patient.an@gmail.com';
    }

    if (mounted) {
      setState(() => _fetching = false);
    }
  }

  String _getRoleDisplayName(dynamic role, int roleId) {
    switch (roleId) {
      case 1:
        return 'Quản trị viên (Admin)';
      case 2:
        return 'Quản lý (Manager)';
      case 3:
        return 'Bác sĩ (Doctor)';
      case 4:
        return 'Kỹ thuật viên xét nghiệm (Lab User)';
      case 5:
        return 'Bệnh nhân (Patient)';
      case 6:
        return 'Lễ tân (Receptionist)';
      default:
        return role?.toString().toUpperCase() ?? 'Bệnh nhân';
    }
  }

  void _handleUpdateAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newPassword = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isNotEmpty && newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mật khẩu xác nhận không trùng khớp!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    final targetId = _accountId ?? 'P-2026-08192';
    final result = await AccountService.updateAccount(
      targetId,
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: newPassword.isNotEmpty ? newPassword : null,
      roleId: _roleId,
      status: _status,
    );

    setState(() => _loading = false);

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Cập nhật tài khoản thành công!'),
            backgroundColor: const Color(0xFF198754),
          ),
        );
        _passwordController.clear();
        _confirmPasswordController.clear();
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Cập nhật thất bại. Vui lòng thử lại!'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleName = _getRoleDisplayName(_userRole, _roleId);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Cập Nhật Thông Tin Tài Khoản', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF212529),
        elevation: 1,
      ),
      body: _fetching
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar & Role Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            child: const Icon(Icons.person, size: 36, color: AppColors.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _usernameController.text.isNotEmpty
                                      ? _usernameController.text
                                      : 'Tài khoản người dùng',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF212529),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    roleName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                if (_accountId != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: ${_accountId!.length > 18 ? "${_accountId!.substring(0, 18)}..." : _accountId}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Editable Form Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thông Tin Cá Nhân',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF212529),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Username
                          const Text(
                            'Tên đăng nhập / Họ tên *',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF495057)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.person_outline),
                              hintText: 'Nhập tên đăng nhập',
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Tên đăng nhập không được để trống';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Email
                          const Text(
                            'Địa chỉ Email *',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF495057)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.email_outlined),
                              hintText: 'example@gmail.com',
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Email không được để trống';
                              }
                              if (!val.contains('@') || !val.contains('.')) {
                                return 'Vui lòng nhập email hợp lệ';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          const Divider(),
                          const SizedBox(height: 12),

                          // Đổi mật khẩu
                          const Text(
                            'Đổi Mật Khẩu (Để trống nếu không đổi)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF212529),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // New Password
                          const Text(
                            'Mật khẩu mới',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF495057)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              hintText: 'Nhập mật khẩu mới (ít nhất 6 ký tự)',
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            validator: (val) {
                              if (val != null && val.isNotEmpty && val.length < 6) {
                                return 'Mật khẩu phải có ít nhất 6 ký tự';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Confirm New Password
                          const Text(
                            'Xác nhận mật khẩu mới',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF495057)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_reset),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                              hintText: 'Nhập lại mật khẩu mới',
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            validator: (val) {
                              if (_passwordController.text.isNotEmpty && (val == null || val.isEmpty)) {
                                return 'Vui lòng xác nhận mật khẩu';
                              }
                              if (_passwordController.text.isNotEmpty && val != _passwordController.text) {
                                return 'Mật khẩu xác nhận không khớp';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _handleUpdateAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        icon: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined, color: Colors.white),
                        label: Text(
                          _loading ? 'Đang lưu thay đổi...' : 'Lưu Thay Đổi',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: const Text('Hủy Bỏ', style: TextStyle(fontSize: 16, color: Color(0xFF6C757D))),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
