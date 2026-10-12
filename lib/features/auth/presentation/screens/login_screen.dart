import 'package:flutter/material.dart';
import 'package:bms_mobile_app/services/bms_auth.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const blue = Color(0xFF0353E9);
  static const navy = Color(0xFF0F2743);
  static const muted = Color(0xFF64748B);

  final formKey = GlobalKey<FormState>();

  final usernameController =
  TextEditingController(text: 'dr_nguyenminh');

  final passwordController =
  TextEditingController(text: 'Admin@123');

  bool obscurePassword = true;
  bool isLoading = false;
  bool rememberMe = false;
  String? errorMessage;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }


  Future<void> handleLogin() async {
    FocusScope.of(context).unfocus();

    if (!formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await BmsAuth.login(
        usernameOrEmail: usernameController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;

      setState(() => isLoading = false);

      if (result['success'] == true) {
        // Đóng LoginScreen và báo MainScreen chuyển sang Home.
        Navigator.pop(context, true);
      } else {
        setState(() {
          errorMessage =
              result['message']?.toString() ?? 'Đăng nhập thất bại.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Không thể kết nối máy chủ. Vui lòng thử lại.';
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
              // Header
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
                      'Welcome back',
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

              // Login form
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
                        'Đăng nhập tài khoản',
                        style: TextStyle(
                          color: navy,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Đăng nhập để tiếp tục sử dụng BMS Health.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 26),

                      const Text(
                        'Email hoặc tên đăng nhập',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: usernameController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: inputDecoration(
                          hint: 'Nhập email hoặc username',
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Vui lòng nhập tài khoản.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Mật khẩu',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => handleLogin(),
                        decoration: inputDecoration(
                          hint: 'Nhập mật khẩu',
                          icon: Icons.lock_outline_rounded,
                        ).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: muted,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập mật khẩu.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Checkbox(
                            value: rememberMe,
                            activeColor: blue,
                            onChanged: (value) {
                              setState(() {
                                rememberMe = value ?? false;
                              });
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Ghi nhớ đăng nhập',
                              style: TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Quên mật khẩu?',
                              style: TextStyle(
                                color: blue,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFECACA),
                            ),
                          ),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed:
                          isLoading ? null : handleLogin,
                          icon: isLoading
                              ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.login_rounded),
                          label: Text(
                            isLoading
                                ? 'Đang đăng nhập...'
                                : 'Sign in',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Center(
                        child: Text(
                          'BMS Health · Secure Login',
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
}