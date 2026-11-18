import 'package:flutter/material.dart';
import '../../../../core/network/bms_http_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/account_service.dart';
import '../../../../services/bms_auth.dart';

/// Account Contact Update Screen backed by real `GET /api/users/me` and `PUT /api/users/{id}`.
class UpdateAccountScreen extends StatefulWidget {
  const UpdateAccountScreen({super.key});

  @override
  State<UpdateAccountScreen> createState() => _UpdateAccountScreenState();
}

class _UpdateAccountScreenState extends State<UpdateAccountScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final BmsHttpClient _http = const BmsHttpClient();

  final TextEditingController _fullNameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  String _accountId = '';
  bool _fetching = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentAccount();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentAccount() async {
    setState(() {
      _fetching = true;
      _errorMessage = null;
    });

    try {
      final res = await _http.get('/api/users/me');
      if (!mounted) return;
      if (res.isSuccess) {
        final data = res.data is Map
            ? Map<String, dynamic>.from(res.data as Map)
            : res.bodyAsMap;
        _accountId = (data['id'] ?? BmsAuth.currentUserId).toString();
        _fullNameCtrl.text =
            (data['fullName'] ?? BmsAuth.currentUserName).toString();
        _emailCtrl.text =
            (data['email'] ?? BmsAuth.user?['email'] ?? '').toString();
        _phoneCtrl.text =
            (data['phoneNumber'] ?? data['phone'] ?? '').toString();
      } else {
        _accountId = BmsAuth.currentUserId;
        _fullNameCtrl.text = BmsAuth.currentUserName;
        _emailCtrl.text = (BmsAuth.user?['email'] ?? '').toString();
      }
      setState(() => _fetching = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetching = false;
        _errorMessage = e.toString().replaceFirst('BmsApiException: ', '');
      });
    }
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_accountId.isEmpty) {
      setState(() {
        _errorMessage = 'Không xác định được phiên đăng nhập hiện tại.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final result = await AccountService.updateAccount(
      _accountId,
      fullName: _fullNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (result['message'] ?? 'Đã cập nhật thông tin tài khoản.').toString(),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage = (result['message'] ??
                'Không thể lưu thay đổi thông tin tài khoản.')
            .toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Cập nhật tài khoản')),
      body: _fetching
          ? const BmsLoadingState(message: 'Đang tải thông tin tài khoản...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BmsPageHeaderCard(
                      icon: Icons.manage_accounts_rounded,
                      badgeText: BmsAuth.roleLabelVi,
                      title: _fullNameCtrl.text.isEmpty
                          ? 'Thông tin tài khoản'
                          : _fullNameCtrl.text,
                      subtitle:
                          'Chỉnh sửa họ tên hiển thị, email nhận kết quả và số điện thoại liên hệ',
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
                            controller: _fullNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Họ và tên *',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().length < 2)
                                ? 'Vui lòng nhập họ và tên hợp lệ.'
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
                            validator: (v) =>
                                (v == null || !v.contains('@'))
                                ? 'Vui lòng nhập email hợp lệ.'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Số điện thoại liên hệ',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _handleSave,
                              icon: const Icon(Icons.save_outlined, size: 18),
                              label: Text(
                                _saving ? 'Đang lưu...' : 'Lưu thông tin',
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
    );
  }
}
