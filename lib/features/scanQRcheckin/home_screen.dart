import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bms_mobile_app/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      setState(() {
        _user = jsonDecode(userStr);
      });
    }
  }

  void _handleLogout() async {
    await AuthService.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _navigateToUpdateAccount() async {
    final updated = await Navigator.pushNamed(context, '/update-account');
    if (updated == true) {
      _loadUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang Chủ BMS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF212529),
        elevation: 1,
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Chào mừng đến với BMS Mobile!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D6EFD),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // User Info Card
            if (_user != null)
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
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFF0D6EFD).withValues(alpha: 0.12),
                          child: const Icon(Icons.person, size: 28, color: Color(0xFF0D6EFD)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _user!['fullName'] ?? _user!['username'] ?? 'Người dùng',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF212529),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Vai trò: ${_user!['role'] ?? 'Patient'}',
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                              ),
                              if (_user!['email'] != null)
                                Text(
                                  'Email: ${_user!['email']}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Feature: Quản Lý Lịch Hẹn (Appointments - Create, Update, Delete)
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/appointments'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6EFD),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              icon: const Icon(Icons.calendar_month, color: Colors.white, size: 24),
              label: const Text(
                'Quản Lý Lịch Hẹn (Appointments)',
                style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // Feature: Quét QR Check-in (Scan QR Check-in)
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/scan-qr-checkin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF198754),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
              label: const Text(
                'Quét QR Check-in (Scan QR Check-in)',
                style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // Feature: Cập Nhật Thông Tin Tài Khoản (Update Account Information)
            OutlinedButton.icon(
              onPressed: _navigateToUpdateAccount,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: const BorderSide(color: Color(0xFF0D6EFD), width: 1.5),
              ),
              icon: const Icon(Icons.manage_accounts, color: Color(0xFF0D6EFD), size: 22),
              label: const Text(
                'Cập Nhật Thông Tin Tài Khoản',
                style: TextStyle(fontSize: 16, color: Color(0xFF0D6EFD), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // Feature 2: Xác Thực OTP (Verify OTP Screen)
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/verify-otp'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: const BorderSide(color: Color(0xFF198754), width: 1.5),
              ),
              icon: const Icon(Icons.verified_user_outlined, color: Color(0xFF198754), size: 22),
              label: const Text(
                'Xác Thực OTP (Verify OTP)',
                style: TextStyle(fontSize: 16, color: Color(0xFF198754), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // Additional Management features
            if (_user != null && (_user!['role'] == 'admin' || _user!['roleId'] == 1)) ...[
              ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF198754),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.people_outline, color: Colors.white),
                label: const Text('Quản Lý Nhân Viên', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
            ],

            if (_user != null) ...[
              ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0DCAF0),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.medical_services_outlined, color: Colors.white),
                label: const Text('Quản Lý Gói Dịch Vụ', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],

            const SizedBox(height: 36),

            // Logout Button
            ElevatedButton.icon(
              onPressed: _handleLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC3545),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Đăng Xuất', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
