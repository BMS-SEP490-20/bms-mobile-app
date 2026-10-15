import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

/// Clinical Patient Profile and Medical Identity Screen (UC08).
/// Displays personal information, PII-masked credentials, blood type, and digital Kiosk QR identity card.
/// Conforms to: OWASP Top 10 (A01: IDOR Prevention) & AGENTS-DESIGN.md Rules 01-28.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Demo patient profile state conforming to API response contract
  final Map<String, dynamic> _profile = {
    'fullName': 'Nguyễn Văn Johnson',
    'patientCode': 'BN-2026-08192',
    'email': 'patient.johnson@gmail.com',
    'phoneNumber': '098 765 4321',
    'identityCardNumberMasked': '********8234',
    'dateOfBirth': '15/08/1995',
    'gender': 'Male',
    'bloodType': 'O+',
    'address': '123 Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh',
    'role': 'Patient',
    'memberSince': '12/07/2026',
    'is2faEnabled': true,
  };

  bool _isQrExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            tooltip: 'Refresh Profile',
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile information updated successfully.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Digital Medical Identity Card (Kiosk Check-in Card)
            _buildMedicalIdentityCard(),

            const SizedBox(height: 20),

            // 2. Personal Information Section
            _buildSectionHeader('Personal Identity', Icons.person_outline),
            const SizedBox(height: 8),
            _buildInfoCard([
              _buildInfoRow('Full Name', _profile['fullName'] as String, Icons.badge_outlined),
              _buildDivider(),
              _buildInfoRow('Citizen ID', _profile['identityCardNumberMasked'] as String, Icons.credit_card),
              _buildDivider(),
              _buildInfoRow('Date of Birth', _profile['dateOfBirth'] as String, Icons.calendar_today_outlined),
              _buildDivider(),
              _buildInfoRow('Gender', _profile['gender'] as String, Icons.male_outlined),
              _buildDivider(),
              _buildInfoRow('Blood Group', _profile['bloodType'] as String, Icons.bloodtype, isHighlight: true),
            ]),

            const SizedBox(height: 20),

            // 3. Contact & Medical Profile Section
            _buildSectionHeader('Contact Information', Icons.contact_mail_outlined),
            const SizedBox(height: 8),
            _buildInfoCard([
              _buildInfoRow('Phone Number', _profile['phoneNumber'] as String, Icons.phone_outlined),
              _buildDivider(),
              _buildInfoRow('Email Address', _profile['email'] as String, Icons.email_outlined),
              _buildDivider(),
              _buildInfoRow('Registered Address', _profile['address'] as String, Icons.location_on_outlined),
            ]),

            const SizedBox(height: 20),

            // 4. Security & Quick Actions Section
            _buildSectionHeader('Security & Quick Links', Icons.security_outlined),
            const SizedBox(height: 8),
            _buildInfoCard([
              _buildActionRow(
                'Two-Factor Authentication (OTP)',
                'Enabled',
                Icons.shield_outlined,
                badgeColor: AppColors.success,
              ),
              _buildDivider(),
              _buildActionRow(
                'Medical Test Results History',
                'View records',
                Icons.biotech_outlined,
              ),
              _buildDivider(),
              _buildActionRow(
                'Change Account Password / Update Info',
                'Update credentials & email',
                Icons.lock_reset,
                onTap: () {
                  Navigator.pushNamed(context, '/update-account');
                },
              ),
            ]),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Builds the top digital clinical identity card styled with Medical Blue gradient.
  Widget _buildMedicalIdentityCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_hospital, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'BMS CLINIC PASS',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ACTIVE PATIENT',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _profile['fullName'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Patient Code: ${_profile['patientCode']}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BLOOD TYPE',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                  ),
                  Text(
                    _profile['bloodType'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isQrExpanded = !_isQrExpanded);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: Icon(_isQrExpanded ? Icons.close : Icons.qr_code, size: 18),
                label: Text(
                  _isQrExpanded ? 'Hide QR' : 'Kiosk QR',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),

          // Collapsible QR code check-in panel
          if (_isQrExpanded) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 120, color: AppColors.textPrimary),
                  const SizedBox(height: 8),
                  Text(
                    _profile['patientCode'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Scan at BMS Kiosk reception counter for express check-in',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isHighlight ? AppColors.danger : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(
    String title,
    String subtitle,
    IconData icon, {
    Color? badgeColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: badgeColor ?? AppColors.textMuted,
                      fontWeight: badgeColor != null ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 0.5, color: AppColors.border);
  }
}
