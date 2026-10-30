import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../services/bms_auth.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../data/patient_repository.dart';
import '../../models/guest_profile_model.dart';

/// Create Guest Profile Screen & Popup Modal (UC25 – Mobile).
/// Issue: I2-018 | BR-079 | Assignee: Hứa Khánh Duy | Reviewer: Võ Gia Huy
///
/// Strictly restricted to authenticated Receptionist role.
/// Allows receptionists to:
/// 1. View & search walk-in / guest patient profiles (`GET /api/patients`).
/// 2. Create a new guest patient profile via a full-featured Popup Modal / Form (`POST /api/patients/guests`)
///    with live duplicate checking, Vietnamese phone/CCCD validation, allergies, and vital signs.
/// 3. View created guest profile details & Kiosk QR code in a popup dialog.
class CreateGuestProfileScreen extends StatefulWidget {
  final PatientRepository? repository;
  final bool openCreatePopupOnInit;
  final String? preselectedPackageName;

  const CreateGuestProfileScreen({
    super.key,
    this.repository,
    this.openCreatePopupOnInit = false,
    this.preselectedPackageName,
  });

  @override
  State<CreateGuestProfileScreen> createState() =>
      _CreateGuestProfileScreenState();
}

class _CreateGuestProfileScreenState extends State<CreateGuestProfileScreen> {
  late final PatientRepository _repo;
  final TextEditingController _searchController = TextEditingController();

  List<PatientProfileModel> _profiles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? PatientRepository();
    if (BmsAuth.isReceptionist) {
      _loadProfiles();
      if (widget.openCreatePopupOnInit) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && BmsAuth.isReceptionist) {
            _openCreateGuestModal();
          }
        });
      }
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (widget.repository == null) {
      _repo.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    if (!BmsAuth.isReceptionist) {
      setState(() {
        _loading = false;
        _profiles = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _repo.searchPatients(
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        page: 1,
        pageSize: 30,
      );
      if (!mounted) return;
      setState(() {
        _profiles = list;
        _loading = false;
      });
    } on PatientApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải danh sách hồ sơ bệnh nhân: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openCreateGuestModal() async {
    if (!BmsAuth.isReceptionist) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chỉ tài khoản Lễ Tân (Receptionist) mới có quyền tạo hồ sơ khách vãng lai.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final created = await showModalBottomSheet<PatientProfileModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateGuestProfileFormSheet(
        repository: _repo,
        preselectedPackageName: widget.preselectedPackageName,
      ),
    );

    if (created != null && mounted) {
      await _loadProfiles();
      if (mounted) {
        _showProfileDetailDialog(created, isNewlyCreated: true);
      }
    }
  }

  void _showProfileDetailDialog(
    PatientProfileModel profile, {
    bool isNewlyCreated = false,
  }) {
    final dobStr = profile.dateOfBirth != null
        ? DateFormat('dd/MM/yyyy').format(profile.dateOfBirth!)
        : '—';

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isNewlyCreated)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đã tạo hồ sơ khách vãng lai (Guest Profile) thành công!',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            profile.isGuest
                                ? 'KHÁCH VÃNG LAI (GUEST)'
                                : 'BỆNH NHÂN ĐĂNG KÝ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          'Nhóm máu: ${profile.bloodType}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      profile.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mã BN: ${profile.patientCode}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _detailRow('Số điện thoại', profile.phoneNumber),
              _detailRow('Ngày sinh', dobStr),
              _detailRow('Giới tính', profile.genderLabelVi),
              _detailRow('Số CCCD / Định danh', profile.identityNumber ?? '—'),
              _detailRow('Email', profile.email ?? '—'),
              _detailRow('Địa chỉ', profile.address ?? '—'),
              if (profile.emergencyContactName != null ||
                  profile.emergencyContactPhone != null)
                _detailRow(
                  'Liên hệ khẩn cấp',
                  '${profile.emergencyContactName ?? ''} (${profile.emergencyContactPhone ?? ''})',
                ),
              if (profile.allergies.isNotEmpty)
                _detailRow(
                  'Dị ứng ghi nhận',
                  profile.allergies.join(', '),
                  valueColor: AppColors.danger,
                ),
              if (profile.medicalHistory != null &&
                  profile.medicalHistory!.isNotEmpty)
                _detailRow('Tiền sử bệnh lý', profile.medicalHistory!),
              if (profile.vitals != null) ...[
                const Divider(height: 20),
                const Text(
                  'Chỉ số sinh hiệu (Vitals)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (profile.vitals!.heightCm != null)
                      _vitalBadge('Cao', '${profile.vitals!.heightCm} cm'),
                    if (profile.vitals!.weightKg != null)
                      _vitalBadge('Nặng', '${profile.vitals!.weightKg} kg'),
                    if (profile.vitals!.bmi != null)
                      _vitalBadge('BMI', '${profile.vitals!.bmi}'),
                    if (profile.vitals!.bloodPressure != null)
                      _vitalBadge('HA', profile.vitals!.bloodPressure!),
                    if (profile.vitals!.heartRateBpm != null)
                      _vitalBadge(
                        'Mạch',
                        '${profile.vitals!.heartRateBpm} bpm',
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!BmsAuth.isReceptionist) {
      final currentRoleLabel = BmsAuth.isLoggedIn
          ? 'Đang đăng nhập với vai trò: ${BmsAuth.userRole}'
          : 'Chưa đăng nhập phiên làm việc';
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Hồ Sơ Khách Vãng Lai (Guest Profile)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0.5,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_person_outlined,
                      size: 46,
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Yêu Cầu Quyền Lễ Tân (Receptionist)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chức năng Tạo Hồ Sơ Khách Vãng Lai (Create Guest Profile) chỉ cho phép thao tác khi đăng nhập bằng tài khoản Lễ Tân (Receptionist).\n\n($currentRoleLabel)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.login_rounded),
                      label: const Text(
                        'Đăng nhập tài khoản Lễ Tân',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                        if (!mounted) return;
                        setState(() {});
                        if (BmsAuth.isReceptionist) {
                          _loadProfiles();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Hồ Sơ Khách Vãng Lai (Guest Profile)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _loadProfiles,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateGuestModal,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text(
          'Tạo Hồ Sơ Khách',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Top Banner & Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.preselectedPackageName != null &&
                    widget.preselectedPackageName!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.science_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Đăng ký gói: ${widget.preselectedPackageName}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Tìm theo tên, SĐT, mã BN hoặc số CCCD...',
                          hintStyle: const TextStyle(fontSize: 13),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadProfiles();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                        ),
                        onSubmitted: (_) => _loadProfiles(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _loadProfiles,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Tìm'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Danh sách hồ sơ (${_profiles.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openCreateGuestModal,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Tạo mới (Popup)'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Profiles List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.danger,
                                size: 42,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style:
                                    const TextStyle(color: AppColors.danger),
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: _loadProfiles,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _profiles.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.person_search_outlined,
                                    size: 52,
                                    color: AppColors.textDisabled,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Chưa tìm thấy hồ sơ bệnh nhân phù hợp.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed: _openCreateGuestModal,
                                    icon: const Icon(Icons.person_add_alt_1),
                                    label: const Text(
                                      'Tạo Hồ Sơ Khách Vãng Lai Ngay',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadProfiles,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 88),
                              itemCount: _profiles.length,
                              itemBuilder: (ctx, idx) {
                                final p = _profiles[idx];
                                return _buildProfileCard(p);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(PatientProfileModel p) {
    final dobStr = p.dateOfBirth != null
        ? DateFormat('dd/MM/yyyy').format(p.dateOfBirth!)
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showProfileDetailDialog(p),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: p.isGuest
                    ? const Color(0xFFFEF3C7)
                    : AppColors.primaryLight,
                child: Icon(
                  p.isGuest ? Icons.badge_outlined : Icons.person,
                  color: p.isGuest
                      ? const Color(0xFFD97706)
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: p.isGuest
                                ? const Color(0xFFFEF3C7)
                                : AppColors.successLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            p.isGuest ? 'Guest' : 'Đã ĐK',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: p.isGuest
                                  ? const Color(0xFFB45309)
                                  : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mã: ${p.patientCode} • SĐT: ${p.phoneNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Giới tính: ${p.genderLabelVi} • Ngày sinh: $dobStr • Nhóm máu: ${p.bloodType}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom Sheet Popup Form for creating a new Walk-in / Guest Patient Profile (`POST /api/patients/guests`).
class _CreateGuestProfileFormSheet extends StatefulWidget {
  final PatientRepository repository;
  final String? preselectedPackageName;

  const _CreateGuestProfileFormSheet({
    required this.repository,
    this.preselectedPackageName,
  });

  @override
  State<_CreateGuestProfileFormSheet> createState() =>
      _CreateGuestProfileFormSheetState();
}

class _CreateGuestProfileFormSheetState
    extends State<_CreateGuestProfileFormSheet> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _identityCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emergNameCtrl = TextEditingController();
  final _emergPhoneCtrl = TextEditingController();
  final _medicalHistoryCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _bpCtrl = TextEditingController();
  final _hrCtrl = TextEditingController();

  DateTime _selectedDob = DateTime(1995, 5, 15);
  String _selectedGender = 'Male';
  String _selectedBloodType = 'Unknown';
  bool _showVitals = false;

  bool _submitting = false;
  String? _submitError;

  // Live duplicate check state
  Timer? _dupTimer;
  List<PatientProfileModel> _duplicateCandidates = [];

  static const _bloodTypes = [
    'Unknown',
    'O+',
    'O-',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
  ];

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_scheduleDuplicateCheck);
    _identityCtrl.addListener(_scheduleDuplicateCheck);
  }

  @override
  void dispose() {
    _dupTimer?.cancel();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _identityCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _emergNameCtrl.dispose();
    _emergPhoneCtrl.dispose();
    _medicalHistoryCtrl.dispose();
    _allergiesCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _bpCtrl.dispose();
    _hrCtrl.dispose();
    super.dispose();
  }

  void _scheduleDuplicateCheck() {
    _dupTimer?.cancel();
    final idText = _identityCtrl.text.trim();
    final phoneText = _phoneCtrl.text.trim();
    final query = idText.length >= 6
        ? idText
        : (phoneText.length >= 6 ? phoneText : '');

    if (query.isEmpty) {
      if (_duplicateCandidates.isNotEmpty) {
        setState(() => _duplicateCandidates = []);
      }
      return;
    }

    _dupTimer = Timer(const Duration(milliseconds: 450), () async {
      try {
        final found = await widget.repository.searchPatients(
          search: query,
          page: 1,
          pageSize: 3,
        );
        if (mounted) {
          setState(() => _duplicateCandidates = found);
        }
      } catch (_) {}
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _submitError = null);
    if (!_formKey.currentState!.validate()) return;

    final allergies = _allergiesCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final height = double.tryParse(_heightCtrl.text.trim());
    final weight = double.tryParse(_weightCtrl.text.trim());
    final hr = int.tryParse(_hrCtrl.text.trim());
    final bp = _bpCtrl.text.trim();

    final vitals =
        (height != null || weight != null || hr != null || bp.isNotEmpty)
            ? PatientVitalsModel(
                heightCm: height,
                weightKg: weight,
                bloodPressure: bp.isEmpty ? null : bp,
                heartRateBpm: hr,
              )
            : null;

    final req = CreateGuestProfileRequestModel(
      fullName: _fullNameCtrl.text.trim(),
      dateOfBirth: DateFormat('yyyy-MM-dd').format(_selectedDob),
      gender: _selectedGender,
      phoneNumber: _phoneCtrl.text.trim(),
      identityNumber:
          _identityCtrl.text.trim().isEmpty ? null : _identityCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      address:
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      bloodType: _selectedBloodType,
      emergencyContactName: _emergNameCtrl.text.trim().isEmpty
          ? null
          : _emergNameCtrl.text.trim(),
      emergencyContactPhone: _emergPhoneCtrl.text.trim().isEmpty
          ? null
          : _emergPhoneCtrl.text.trim(),
      medicalHistory: _medicalHistoryCtrl.text.trim().isEmpty
          ? null
          : _medicalHistoryCtrl.text.trim(),
      allergies: allergies,
      vitals: vitals,
    );

    setState(() => _submitting = true);
    try {
      final created = await widget.repository.createGuestProfile(req);
      if (!mounted) return;
      Navigator.pop(context, created);
    } on PatientApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.message;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = 'Không thể lưu hồ sơ khách vãng lai: $e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(
                      Icons.person_add_alt_1,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tạo Hồ Sơ Khách Vãng Lai',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Create Guest Profile • POST /api/patients/guests',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 22),

              if (_submitError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.danger,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _submitError!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Live Duplicate Warning Banner
              if (_duplicateCandidates.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFFB45309),
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Phát hiện hồ sơ có SĐT / CCCD tương tự trong hệ thống:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ..._duplicateCandidates.map(
                        (dup) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '• ${dup.fullName} (${dup.patientCode}) — SĐT: ${dup.phoneNumber}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, dup),
                                child: const Text(
                                  'Dùng hồ sơ này',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 1. Full Name
              TextFormField(
                controller: _fullNameCtrl,
                decoration: _inputDeco(
                  label: 'Họ và tên bệnh nhân *',
                  hint: 'VD: Nguyễn Văn Khách',
                  icon: Icons.person_outline,
                ),
                validator: (val) {
                  final v = val?.trim() ?? '';
                  if (v.length < 2) {
                    return 'Họ và tên phải có từ 2 ký tự trở lên.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // 2. Date of Birth & Gender
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDob,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: _inputDeco(
                          label: 'Ngày sinh *',
                          icon: Icons.cake_outlined,
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_selectedDob),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      decoration: _inputDeco(
                        label: 'Giới tính *',
                        icon: Icons.wc_outlined,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Nam')),
                        DropdownMenuItem(value: 'Female', child: Text('Nữ')),
                        DropdownMenuItem(value: 'Other', child: Text('Khác')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedGender = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Phone & CCCD
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDeco(
                        label: 'Số điện thoại *',
                        hint: '0912345678',
                        icon: Icons.phone_outlined,
                      ),
                      validator: (val) {
                        final v = val?.trim() ?? '';
                        final reg = RegExp(r'^0[35789][0-9]{8}$');
                        if (!reg.hasMatch(v)) {
                          return 'SĐT 10 số (03/05/07/08/09...)';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _identityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco(
                        label: 'Số CCCD (12 chữ số)',
                        hint: '12 chữ số',
                        icon: Icons.credit_card_outlined,
                      ),
                      validator: (val) {
                        final v = val?.trim() ?? '';
                        if (v.isEmpty) return null;
                        if (!RegExp(r'^[0-9]{12}$').hasMatch(v)) {
                          return 'CCCD phải gồm đúng 12 số';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. Blood Type & Email
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedBloodType,
                      decoration: _inputDeco(
                        label: 'Nhóm máu',
                        icon: Icons.bloodtype_outlined,
                      ),
                      items: _bloodTypes
                          .map(
                            (b) => DropdownMenuItem(
                              value: b,
                              child: Text(b == 'Unknown' ? 'Chưa rõ' : b),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedBloodType = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDeco(
                        label: 'Email nhận KQ',
                        hint: 'khach@example.com',
                        icon: Icons.email_outlined,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 5. Address
              TextFormField(
                controller: _addressCtrl,
                decoration: _inputDeco(
                  label: 'Địa chỉ liên hệ',
                  hint: 'Số nhà, đường, phường/xã, quận/huyện...',
                  icon: Icons.location_on_outlined,
                ),
              ),
              const SizedBox(height: 12),

              // 6. Emergency Contact
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emergNameCtrl,
                      decoration: _inputDeco(
                        label: 'Người liên hệ khẩn cấp',
                        hint: 'Họ tên người nhà',
                        icon: Icons.contact_emergency_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _emergPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDeco(
                        label: 'SĐT khẩn cấp',
                        hint: '098xxxxxxx',
                        icon: Icons.phone_callback_outlined,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 7. Allergies & Medical History
              TextFormField(
                controller: _allergiesCtrl,
                decoration: _inputDeco(
                  label: 'Tiền sử dị ứng (cách nhau bằng dấu phẩy)',
                  hint: 'VD: Penicillin, Hải sản...',
                  icon: Icons.warning_amber_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _medicalHistoryCtrl,
                maxLines: 2,
                decoration: _inputDeco(
                  label: 'Tiền sử bệnh lý / Ghi chú lâm sàng',
                  hint: 'VD: Đái tháo đường type 2, Tăng huyết áp...',
                  icon: Icons.notes_outlined,
                ),
              ),
              const SizedBox(height: 10),

              // 8. Collapsible Vital Signs
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Ghi nhận chỉ số sinh hiệu ban đầu (Chiều cao, Cân nặng, HA)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                value: _showVitals,
                onChanged: (v) => setState(() => _showVitals = v),
              ),
              if (_showVitals) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _heightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputDeco(label: 'Cao (cm)', hint: '170'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _weightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputDeco(label: 'Nặng (kg)', hint: '65'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _bpCtrl,
                        decoration:
                            _inputDeco(label: 'Huyết áp', hint: '120/80'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _hrCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputDeco(label: 'Mạch (bpm)', hint: '75'),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _handleSubmit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _submitting
                        ? 'Đang tạo hồ sơ...'
                        : 'Xác Nhận Tạo Hồ Sơ Khách Vãng Lai',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 19) : null,
      isDense: true,
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }
}
