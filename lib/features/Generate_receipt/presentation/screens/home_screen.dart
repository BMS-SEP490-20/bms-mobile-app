import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

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

  int? get _normalizedRoleId {
    if (_user == null) return null;
    final rId = _user!['roleId'];
    if (rId is int) return rId;
    if (rId != null) {
      final parsed = int.tryParse(rId.toString());
      if (parsed != null) return parsed;
    }
    final role = _user!['role']?.toString().toLowerCase();
    switch (role) {
      case 'admin':
      case 'administrator':
        return 1;
      case 'manager':
        return 2;
      case 'doctor':
        return 3;
      case 'labuser':
      case 'lab_user':
      case 'laboratory user':
        return 4;
      case 'patient':
        return 5;
      case 'receptionist':
        return 6;
      default:
        return null;
    }
  }

  bool get _isPatient => _normalizedRoleId == 5 || _normalizedRoleId == null;
  bool get _isReceptionist => _normalizedRoleId == 6;
  bool get _isManager => _normalizedRoleId == 2;
  bool get _isAdmin => _normalizedRoleId == 1;

  // BUSINESS RULE: Role-based mobile features permission matrix
  // - Generate Receipt: Receptionist, Clinic Manager, Administrator. (Patients, Doctors, Lab Users cannot issue receipts)
  bool get _canGenerateReceipt => _isReceptionist || _isManager || _isAdmin;

  // - Scan QR Check-in: Receptionist, Clinic Manager, Administrator. (Patients present their own check-in QR, they do not scan others)
  bool get _canScanCheckin => _isReceptionist || _isManager || _isAdmin;

  // - Manage Test Packages: Clinic Manager, Administrator.
  bool get _canManagePackages => _isManager || _isAdmin;

  // - Manage Staff: Administrator, Clinic Manager.
  bool get _canManageStaff => _isAdmin || _isManager;

  String get _roleDisplayName {
    switch (_normalizedRoleId) {
      case 1:
        return 'Quản trị viên (Admin)';
      case 2:
        return 'Quản lý phòng khám (Manager)';
      case 3:
        return 'Bác sĩ (Doctor)';
      case 4:
        return 'Kỹ thuật viên xét nghiệm (Lab User)';
      case 5:
        return 'Bệnh nhân (Patient)';
      case 6:
        return 'Lễ tân tiếp đón (Receptionist)';
      default:
        return _user?['role']?.toString() ?? 'Bệnh nhân (Patient)';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0D6EFD)),
            tooltip: 'Lịch sử thông báo (Notifications)',
            onPressed: () => Navigator.pushNamed(context, '/notifications-history'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
        ],
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
                                'Vai trò: $_roleDisplayName',
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

            // Feature: Quản Lý Lịch Hẹn (Appointments - All Roles)
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/appointments'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6EFD),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              icon: const Icon(Icons.calendar_month, color: Colors.white, size: 24),
              label: Text(
                _isPatient ? 'Lịch Hẹn Của Tôi (My Appointments)' : 'Quản Lý Lịch Hẹn (Appointments)',
                style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // Feature: Quét QR Check-in (Scan QR Check-in - Receptionist / Manager / Admin only)
            // BUSINESS RULE: Patients only show their QR code to the clinic desk; only reception staff scans barcodes.
            if (_canScanCheckin) ...[
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
            ],

            // Feature: Xuất Biên Lai Thu Phí (Generate Receipt - Receptionist / Manager / Admin only)
            // BUSINESS RULE: Billing and receipt generation is strictly restricted to front-desk Receptionists and Admins.
            // Patients, Doctors, and Laboratory users cannot issue receipts.
            if (_canGenerateReceipt) ...[
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/generate-receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6EFD),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                label: const Text(
                  'Xuất Biên Lai Thu Phí (Generate Receipt)',
                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Feature: Lịch Sử Thông Báo (View Notifications History - All 6 Roles)
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/notifications-history'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0DCAF0),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              icon: const Icon(Icons.notifications_active, color: Colors.white, size: 24),
              label: const Text(
                'Thông Báo Hệ Thống (Notifications History)',
                style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // Feature: Cập Nhật Thông Tin Tài Khoản (Update Account Information - All Roles)
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

            // Feature 2: Xác Thực OTP (Verify OTP Screen - All Roles)
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

            // Feature: Quản Lý Nhân Viên (Admin & Manager only)
            if (_canManageStaff) ...[
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

            // Feature: Quản Lý Gói Dịch Vụ (Manager & Admin only)
            if (_canManagePackages) ...[
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
              const SizedBox(height: 12),
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
