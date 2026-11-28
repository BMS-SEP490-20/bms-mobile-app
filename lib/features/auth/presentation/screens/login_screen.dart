import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class _DemoAccount {
  final String roleLabel;
  final String subtitle;
  final String username;
  final String password;
  final IconData icon;
  final Color color;

  const _DemoAccount({
    required this.roleLabel,
    required this.subtitle,
    required this.username,
    required this.password,
    required this.icon,
    required this.color,
  });
}

/// 6 Canonical Demo Accounts matching `bms-web-frontend/src/features/auth/pages/LoginPage.jsx`.
const List<_DemoAccount> _kDemoAccounts = [
  _DemoAccount(
    roleLabel: 'Bệnh Nhân',
    subtitle: 'Trần Văn An',
    username: 'patient_tranvanan',
    password: 'Admin@123',
    icon: Icons.person_outline_rounded,
    color: Color(0xFF7C3AED),
  ),
  _DemoAccount(
    roleLabel: 'Lễ Tân',
    subtitle: 'QR Check-in',
    username: 'recep_lananh',
    password: 'Admin@123',
    icon: Icons.qr_code_scanner_rounded,
    color: Color(0xFFD97706),
  ),
  _DemoAccount(
    roleLabel: 'Bác Sĩ',
    subtitle: 'BS. Nguyễn Minh',
    username: 'dr_nguyenminh',
    password: 'Admin@123',
    icon: Icons.medical_services_outlined,
    color: Color(0xFF0D9488),
  ),
  _DemoAccount(
    roleLabel: 'KTV Lab',
    subtitle: 'KTV. Quốc Hưng',
    username: 'tech_quochung',
    password: 'Admin@123',
    icon: Icons.science_outlined,
    color: Color(0xFF16A34A),
  ),
  _DemoAccount(
    roleLabel: 'Quản Lý',
    subtitle: 'KPI & IoT Lab',
    username: 'manager_lananh',
    password: 'Admin@123',
    icon: Icons.analytics_outlined,
    color: Color(0xFF4F46E5),
  ),
  _DemoAccount(
    roleLabel: 'Admin',
    subtitle: 'Giám sát hệ thống',
    username: 'admin_bms',
    password: 'Admin@123',
    icon: Icons.shield_outlined,
    color: Color(0xFF2563EB),
  ),
];

/// BMS Login Screen matching Web `LoginPage.jsx` 1-1:
/// - Clean centered card, remember me, 5-attempt lockout (BR-IAM-03)
/// - 6 one-tap Demo Accounts for rapid QA/Demo testing
/// - Guest mode entry, Register (4-step) & Forgot Password (3-step) links
class LoginScreen extends StatefulWidget {
  final String? initialNotice;
  final bool embeddedInGuestTab;

  const LoginScreen({
    super.key,
    this.initialNotice,
    this.embeddedInGuestTab = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _identifierCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _activeDemoUsername;
  String? _errorMessage;
  String? _successNotice;
  int _failedAttempts = 0;
  int _lockoutUntilMs = 0;

  @override
  void initState() {
    super.initState();
    _successNotice = widget.initialNotice;
    _loadLockoutState();
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLockoutState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _failedAttempts = prefs.getInt('bms_failed_login_attempts') ?? 0;
      _lockoutUntilMs = prefs.getInt('bms_login_lockout_until') ?? 0;
    });
  }

  bool get _isLockedOut =>
      _lockoutUntilMs > DateTime.now().millisecondsSinceEpoch;

  int get _remainingLockoutMinutes {
    final diff = _lockoutUntilMs - DateTime.now().millisecondsSinceEpoch;
    if (diff <= 0) return 0;
    return (diff / 60000).ceil();
  }

  Future<void> _recordFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final next = _failedAttempts + 1;
    if (next >= 5) {
      final until = DateTime.now()
          .add(const Duration(minutes: 5))
          .millisecondsSinceEpoch;
      await prefs.setInt('bms_failed_login_attempts', next);
      await prefs.setInt('bms_login_lockout_until', until);
      if (mounted) {
        setState(() {
          _failedAttempts = next;
          _lockoutUntilMs = until;
        });
      }
    } else {
      await prefs.setInt('bms_failed_login_attempts', next);
      if (mounted) setState(() => _failedAttempts = next);
    }
  }

  Future<void> _clearLockoutState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bms_failed_login_attempts');
    await prefs.remove('bms_login_lockout_until');
    if (mounted) {
      setState(() {
        _failedAttempts = 0;
        _lockoutUntilMs = 0;
      });
    }
  }

  Future<void> _performLogin({
    required String identifier,
    required String password,
    String? demoUsername,
  }) async {
    if (_isLockedOut && demoUsername == null) {
      setState(() {
        _errorMessage =
            'Tài khoản tạm thời bị khóa do nhập sai 5 lần. Vui lòng thử lại sau $_remainingLockoutMinutes phút.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _activeDemoUsername = demoUsername;
      _errorMessage = null;
      _successNotice = null;
    });

    final result = await BmsAuth.login(
      usernameOrEmail: identifier.trim(),
      password: password,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _activeDemoUsername = null;
    });

    if (result['success'] == true) {
      await _clearLockoutState();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/workspace',
        (route) => false,
      );
      return;
    }

    if (result['statusCode'] == 401 && demoUsername == null) {
      await _recordFailedAttempt();
    }

    setState(() {
      _errorMessage =
          result['message']?.toString() ??
          'Tên đăng nhập hoặc mật khẩu không chính xác.';
    });
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await _performLogin(
      identifier: _identifierCtrl.text,
      password: _passwordCtrl.text,
    );
  }

  Future<void> _loginWithDemo(_DemoAccount demo) async {
    FocusScope.of(context).unfocus();
    _identifierCtrl.text = demo.username;
    _passwordCtrl.text = demo.password;
    await _performLogin(
      identifier: demo.username,
      password: demo.password,
      demoUsername: demo.username,
    );
  }

  Future<void> _openRegister() async {
    final registered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (registered == true && mounted) {
      setState(() {
        _successNotice =
            'Đăng ký tài khoản thành công! Vui lòng đăng nhập để tiếp tục.';
        _errorMessage = null;
      });
    }
  }

  Future<void> _openForgotPassword() async {
    final resetOk = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
    if (resetOk == true && mounted) {
      setState(() {
        _successNotice =
            'Đặt lại mật khẩu thành công! Vui lòng sử dụng mật khẩu mới.';
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // Brand Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.biotech_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BMS MedLab',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          'Trung tâm Xét nghiệm Y khoa Chuẩn ISO 15189',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Main Login Card
              BmsSoftCard(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Đăng nhập hệ thống',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Dành cho Bệnh nhân đặt lịch, tra cứu kết quả và Nhân sự y tế',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_successNotice != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.successBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline_rounded,
                                color: AppColors.successText,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _successNotice!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.successText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.dangerBorder),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.danger,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.dangerText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _identifierCtrl,
                        textInputAction: TextInputAction.next,
                        enabled: !_isLoading,
                        decoration: const InputDecoration(
                          labelText: 'Tên đăng nhập / Email / SĐT',
                          hintText: 'Nhập tài khoản hoặc email',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Vui lòng nhập tên đăng nhập hoặc email.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        enabled: !_isLoading,
                        onFieldSubmitted: (_) => _submitForm(),
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          hintText: 'Nhập mật khẩu',
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
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Vui lòng nhập mật khẩu.'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: _isLoading
                                ? null
                                : (v) =>
                                      setState(() => _rememberMe = v ?? true),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          const Expanded(
                            child: Text(
                              'Ghi nhớ đăng nhập',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : _openForgotPassword,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Quên mật khẩu?',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _submitForm,
                          child: _isLoading && _activeDemoUsername == null
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Đăng nhập'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Chưa có tài khoản bệnh nhân?',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : _openRegister,
                            child: const Text(
                              'Đăng ký ngay',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!widget.embeddedInGuestTab) ...[
                        const Divider(height: 16),
                        OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(
                                  context,
                                ).pushNamedAndRemoveUntil(
                                  '/guest',
                                  (route) => false,
                                ),
                          icon: const Icon(Icons.explore_outlined, size: 18),
                          label: const Text(
                            'Chế độ Khách (Bảng giá & Tra cứu)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 6 Demo Account Quick Login Card (matches Web LoginPage.jsx)
              BmsSoftCard(
                padding: const EdgeInsets.all(16),
                backgroundColor: AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'DEMO 1 CHẠM',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Tài khoản trải nghiệm nhanh (6 vai trò)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _kDemoAccounts.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 2.35,
                          ),
                      itemBuilder: (context, index) {
                        final demo = _kDemoAccounts[index];
                        final isThisLoading =
                            _isLoading &&
                            _activeDemoUsername == demo.username;
                        return InkWell(
                          onTap: _isLoading
                              ? null
                              : () => _loginWithDemo(demo),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: demo.color.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: demo.color.withValues(alpha: 0.24),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: demo.color.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: isThisLoading
                                      ? Padding(
                                          padding: const EdgeInsets.all(7),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: demo.color,
                                          ),
                                        )
                                      : Icon(
                                          demo.icon,
                                          size: 17,
                                          color: demo.color,
                                        ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        demo.roleLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: demo.color,
                                        ),
                                      ),
                                      Text(
                                        demo.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (widget.embeddedInGuestTab) {
      return SafeArea(child: content);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: content),
    );
  }
}
