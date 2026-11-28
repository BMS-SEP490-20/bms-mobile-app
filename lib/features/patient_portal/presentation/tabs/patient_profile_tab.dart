import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/account_service.dart';
import '../../../../services/bms_auth.dart';
import '../../../auth/presentation/screens/change_password_screen.dart';
import '../../../notification/presentation/screens/unified_notifications_screen.dart';
import '../../data/patient_portal_api.dart';
import '../screens/patient_feedback_screen.dart';
import 'patient_billing_tab.dart';

/// Tab 5 of PatientShellScreen — Clinical Medical Profile (`GET/PUT /api/patients/me`),
/// Account Contact (`PUT /api/users/{id}`), Dependents, Security & Logout.
class PatientProfileTab extends StatefulWidget {
  const PatientProfileTab({super.key});

  @override
  State<PatientProfileTab> createState() => _PatientProfileTabState();
}

class _PatientProfileTabState extends State<PatientProfileTab> {
  final PatientPortalApi _api = const PatientPortalApi();

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _medicalProfile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _api.getUserProfile(),
        _api.getMedicalProfile(),
      ]);
      if (!mounted) return;
      setState(() {
        _userProfile = results[0] as Map<String, dynamic>?;
        _medicalProfile = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openEditMedicalProfile() async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditMedicalProfileSheet(
        api: _api,
        initialMedical: _medicalProfile,
        initialUser: _userProfile,
      ),
    );
    if (updated == true) {
      _load();
    }
  }

  Future<void> _openEditAccountContact() async {
    final fullNameCtrl = TextEditingController(
      text: (_userProfile?['fullName'] ?? BmsAuth.currentUserName).toString(),
    );
    final emailCtrl = TextEditingController(
      text: (_userProfile?['email'] ?? BmsAuth.user?['email'] ?? '').toString(),
    );
    final phoneCtrl = TextEditingController(
      text:
          (_userProfile?['phoneNumber'] ?? BmsAuth.user?['phoneNumber'] ?? '')
              .toString(),
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cập nhật liên hệ tài khoản'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: fullNameCtrl,
                decoration: const InputDecoration(labelText: 'Họ và tên *'),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Nhập họ và tên hợp lệ'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email *'),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Nhập địa chỉ email hợp lệ'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final res = await AccountService.updateAccount(
                BmsAuth.currentUserId,
                fullName: fullNameCtrl.text,
                email: emailCtrl.text,
                phoneNumber: phoneCtrl.text,
              );
              if (!ctx.mounted) return;
              if (res['success'] == true) {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      res['message']?.toString() ?? 'Cập nhật thất bại.',
                    ),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
            child: const Text('Lưu liên hệ'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật thông tin liên hệ tài khoản.'),
          backgroundColor: AppColors.success,
        ),
      );
      _load();
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất tài khoản'),
        content: const Text(
          'Bạn có muốn kết thúc phiên đăng nhập trên thiết bị này?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await BmsAuth.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const BmsLoadingState(message: 'Đang tải hồ sơ bệnh nhân...');
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: BmsErrorState(message: _error!, onRetry: _load),
        ),
      );
    }

    final med = _medicalProfile ?? {};
    final usr = _userProfile ?? {};
    final fullName =
        (med['fullName'] ?? usr['fullName'] ?? BmsAuth.currentUserName)
            .toString();
    final patCode =
        (med['patientCode'] ?? usr['patientCode'] ?? 'Chưa cấp mã').toString();
    final bloodType =
        (med['bloodType'] ?? usr['bloodType'] ?? 'Chưa cập nhật').toString();
    final vitals = med['vitals'] is Map
        ? Map<String, dynamic>.from(med['vitals'] as Map)
        : <String, dynamic>{};
    final allergies = med['allergies'] is List
        ? (med['allergies'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final dependents = med['dependents'] is List
        ? (med['dependents'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          BmsPageHeaderCard(
            icon: Icons.badge_outlined,
            badgeText: 'Mã BN: $patCode',
            title: fullName.isEmpty ? 'Hồ sơ bệnh nhân' : fullName,
            subtitle:
                'Nhóm máu: $bloodType · ${BmsFormatters.genderVi((med['gender'] ?? usr['gender'])?.toString())}',
            trailing: FilledButton.icon(
              onPressed: _openEditMedicalProfile,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Sửa hồ sơ'),
            ),
          ),
          const SizedBox(height: 16),

          // Demographics & Clinical Profile
          const BmsSectionHeader(title: 'Hồ sơ y tế lâm sàng'),
          const SizedBox(height: 8),
          BmsSoftCard(
            child: Column(
              children: [
                BmsInfoRow(
                  label: 'Số CCCD (12 số)',
                  value:
                      (med['identityNumber'] ??
                              usr['identityCardNumber'] ??
                              'Chưa cập nhật')
                          .toString(),
                  isMono: true,
                ),
                BmsInfoRow(
                  label: 'Ngày sinh',
                  value: BmsFormatters.date(
                    med['dateOfBirth'] ?? usr['dateOfBirth'],
                  ),
                ),
                BmsInfoRow(
                  label: 'Số điện thoại',
                  value:
                      (med['phoneNumber'] ?? usr['phoneNumber'] ?? '—')
                          .toString(),
                ),
                BmsInfoRow(
                  label: 'Địa chỉ cư trú',
                  value: (med['address'] ?? usr['address'] ?? '—').toString(),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(),
                ),
                BmsInfoRow(
                  label: 'Chiều cao / Cân nặng',
                  value:
                      '${vitals['heightCm'] ?? '—'} cm · ${vitals['weightKg'] ?? '—'} kg',
                ),
                BmsInfoRow(
                  label: 'Huyết áp / Nhịp tim',
                  value:
                      '${vitals['bloodPressure'] ?? '—'} mmHg · ${vitals['heartRateBpm'] ?? '—'} bpm',
                ),
                BmsInfoRow(
                  label: 'Thân nhiệt / SpO2',
                  value:
                      '${vitals['temperatureC'] ?? '—'} °C · ${vitals['spo2Percent'] ?? '—'} %',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(),
                ),
                BmsInfoRow(
                  label: 'Tiền sử dị ứng',
                  value: allergies.isEmpty
                      ? 'Không ghi nhận'
                      : allergies.join(', '),
                  valueColor: allergies.isEmpty ? null : AppColors.dangerText,
                ),
                BmsInfoRow(
                  label: 'Rối loạn đông máu',
                  value: (med['coagulationDisorders'] ?? 'Không ghi nhận')
                      .toString(),
                ),
                BmsInfoRow(
                  label: 'Thuốc đang dùng',
                  value: (med['currentMedications'] ?? 'Không có').toString(),
                ),
                BmsInfoRow(
                  label: 'Tiền sử bệnh lý',
                  value: (med['medicalHistory'] ?? 'Không ghi nhận').toString(),
                ),
                BmsInfoRow(
                  label: 'Liên hệ khẩn cấp',
                  value:
                      '${med['emergencyContactName'] ?? '—'} (${med['emergencyContactRelationship'] ?? 'Người thân'}) · ${med['emergencyContactPhone'] ?? '—'}',
                ),
              ],
            ),
          ),

          if (dependents.isNotEmpty) ...[
            const SizedBox(height: 16),
            const BmsSectionHeader(title: 'Người phụ thuộc đã liên kết'),
            const SizedBox(height: 8),
            ...dependents.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: BmsSoftCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.family_restroom_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (d['fullName'] ?? '').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${d['relationship'] ?? 'Người phụ thuộc'} · ${BmsFormatters.date(d['dateOfBirth'])}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
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
          ],

          const SizedBox(height: 16),
          const BmsSectionHeader(title: 'Dịch vụ, Tài khoản & Bảo mật'),
          const SizedBox(height: 8),
          BmsSoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Viện phí & Thanh toán SePay',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Hóa đơn chờ thanh toán & biên lai điện tử',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const PatientBillingTab(asStandaloneScreen: true),
                      ),
                    );
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(
                    Icons.star_outline_rounded,
                    color: AppColors.warning,
                  ),
                  title: const Text(
                    'Đánh giá & Góp ý Y tế',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Đánh giá các gói xét nghiệm đã sử dụng',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PatientFeedbackScreen(),
                      ),
                    );
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(
                    Icons.contact_mail_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Cập nhật thông tin tài khoản',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    (usr['email'] ?? BmsAuth.user?['email'] ?? '').toString(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openEditAccountContact,
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Thông báo của tôi',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientNotificationsScreen(
                          patientId: (med['id'] ?? BmsAuth.currentUserId)
                              .toString(),
                        ),
                      ),
                    );
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(
                    Icons.lock_reset_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Đổi mật khẩu đăng nhập',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.danger,
                  ),
                  title: const Text(
                    'Đăng xuất tài khoản',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.danger,
                    ),
                  ),
                  onTap: _confirmLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditMedicalProfileSheet extends StatefulWidget {
  final PatientPortalApi api;
  final Map<String, dynamic>? initialMedical;
  final Map<String, dynamic>? initialUser;

  const _EditMedicalProfileSheet({
    required this.api,
    this.initialMedical,
    this.initialUser,
  });

  @override
  State<_EditMedicalProfileSheet> createState() =>
      _EditMedicalProfileSheetState();
}

class _EditMedicalProfileSheetState extends State<_EditMedicalProfileSheet> {
  static const List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _cccdCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _bpCtrl;
  late final TextEditingController _hrCtrl;
  late final TextEditingController _tempCtrl;
  late final TextEditingController _spo2Ctrl;
  late final TextEditingController _medHistoryCtrl;
  late final TextEditingController _allergiesCtrl;
  late final TextEditingController _coagCtrl;
  late final TextEditingController _medicationsCtrl;
  late final TextEditingController _emergNameCtrl;
  late final TextEditingController _emergPhoneCtrl;
  late final TextEditingController _emergRelCtrl;

  DateTime _dob = DateTime(1998, 1, 1);
  String _gender = 'Male';
  String _bloodType = 'O+';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.initialMedical ?? {};
    final u = widget.initialUser ?? {};
    final v = m['vitals'] is Map
        ? Map<String, dynamic>.from(m['vitals'] as Map)
        : <String, dynamic>{};

    _fullNameCtrl = TextEditingController(
      text: (m['fullName'] ?? u['fullName'] ?? BmsAuth.currentUserName)
          .toString(),
    );
    _cccdCtrl = TextEditingController(
      text: (m['identityNumber'] ?? u['identityCardNumber'] ?? '').toString(),
    );
    _phoneCtrl = TextEditingController(
      text: (m['phoneNumber'] ?? u['phoneNumber'] ?? '')
          .toString()
          .replaceAll(' ', ''),
    );
    _emailCtrl = TextEditingController(
      text: (m['email'] ?? u['email'] ?? '').toString(),
    );
    _addressCtrl = TextEditingController(
      text: (m['address'] ?? u['address'] ?? '').toString(),
    );

    _heightCtrl = TextEditingController(
      text: v['heightCm']?.toString() ?? '',
    );
    _weightCtrl = TextEditingController(
      text: v['weightKg']?.toString() ?? '',
    );
    _bpCtrl = TextEditingController(
      text: v['bloodPressure']?.toString() ?? '',
    );
    _hrCtrl = TextEditingController(
      text: v['heartRateBpm']?.toString() ?? '',
    );
    _tempCtrl = TextEditingController(
      text: v['temperatureC']?.toString() ?? '',
    );
    _spo2Ctrl = TextEditingController(
      text: v['spo2Percent']?.toString() ?? '',
    );

    _medHistoryCtrl = TextEditingController(
      text: (m['medicalHistory'] ?? '').toString(),
    );
    final allergyList = m['allergies'] is List
        ? (m['allergies'] as List).map((e) => e.toString()).join(', ')
        : '';
    _allergiesCtrl = TextEditingController(text: allergyList);
    _coagCtrl = TextEditingController(
      text: (m['coagulationDisorders'] ?? '').toString(),
    );
    _medicationsCtrl = TextEditingController(
      text: (m['currentMedications'] ?? '').toString(),
    );
    _emergNameCtrl = TextEditingController(
      text: (m['emergencyContactName'] ?? '').toString(),
    );
    _emergPhoneCtrl = TextEditingController(
      text: (m['emergencyContactPhone'] ?? '').toString(),
    );
    _emergRelCtrl = TextEditingController(
      text: (m['emergencyContactRelationship'] ?? 'Người thân').toString(),
    );

    final parsedDob = DateTime.tryParse(
      (m['dateOfBirth'] ?? '').toString(),
    );
    if (parsedDob != null) _dob = parsedDob;

    final rawGender = (m['gender'] ?? u['gender'] ?? 'Male').toString();
    if (rawGender == 'Female' || rawGender == 'Nữ') {
      _gender = 'Female';
    } else if (rawGender == 'Other') {
      _gender = 'Other';
    } else {
      _gender = 'Male';
    }

    final rawBt = (m['bloodType'] ?? u['bloodType'] ?? 'O+').toString();
    if (_bloodGroups.contains(rawBt)) _bloodType = rawBt;
  }

  @override
  void dispose() {
    for (final c in [
      _fullNameCtrl,
      _cccdCtrl,
      _phoneCtrl,
      _emailCtrl,
      _addressCtrl,
      _heightCtrl,
      _weightCtrl,
      _bpCtrl,
      _hrCtrl,
      _tempCtrl,
      _spo2Ctrl,
      _medHistoryCtrl,
      _allergiesCtrl,
      _coagCtrl,
      _medicationsCtrl,
      _emergNameCtrl,
      _emergPhoneCtrl,
      _emergRelCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final allergies = _allergiesCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final vitalsPayload = <String, dynamic>{
      if (double.tryParse(_heightCtrl.text.trim()) != null)
        'heightCm': double.parse(_heightCtrl.text.trim()),
      if (double.tryParse(_weightCtrl.text.trim()) != null)
        'weightKg': double.parse(_weightCtrl.text.trim()),
      if (_bpCtrl.text.trim().isNotEmpty)
        'bloodPressure': _bpCtrl.text.trim(),
      if (int.tryParse(_hrCtrl.text.trim()) != null)
        'heartRateBpm': int.parse(_hrCtrl.text.trim()),
      if (double.tryParse(_tempCtrl.text.trim()) != null)
        'temperatureC': double.parse(_tempCtrl.text.trim()),
      if (int.tryParse(_spo2Ctrl.text.trim()) != null)
        'spo2Percent': int.parse(_spo2Ctrl.text.trim()),
    };

    try {
      await widget.api.updateMedicalProfile({
        'fullName': _fullNameCtrl.text.trim(),
        'dateOfBirth': _dob.toUtc().toIso8601String(),
        'gender': _gender,
        'phoneNumber': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'identityNumber': _cccdCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'bloodType': _bloodType,
        'vitals': vitalsPayload.isEmpty ? null : vitalsPayload,
        'medicalHistory': _medHistoryCtrl.text.trim(),
        'coagulationDisorders': _coagCtrl.text.trim(),
        'currentMedications': _medicationsCtrl.text.trim(),
        'allergies': allergies,
        'emergencyContactName': _emergNameCtrl.text.trim(),
        'emergencyContactPhone': _emergPhoneCtrl.text.trim(),
        'emergencyContactRelationship': _emergRelCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật hồ sơ y tế bệnh nhân thành công.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.65,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollCtrl) {
          return Form(
            key: _formKey,
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Cập nhật hồ sơ y tế lâm sàng',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fullNameCtrl,
                  decoration: const InputDecoration(labelText: 'Họ và tên *'),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Nhập họ và tên đầy đủ'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dob,
                            firstDate: DateTime(1920),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => _dob = picked);
                        },
                        icon: const Icon(Icons.cake_outlined, size: 18),
                        label: Text(DateFormat('dd/MM/yyyy').format(_dob)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: const ['Male', 'Female', 'Other'].contains(_gender)
                            ? _gender
                            : 'Male',
                        decoration: const InputDecoration(
                          labelText: 'Giới tính *',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Nam')),
                          DropdownMenuItem(value: 'Female', child: Text('Nữ')),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Khác'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _gender = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cccdCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  decoration: const InputDecoration(
                    labelText: 'Số CCCD (12 chữ số) *',
                    counterText: '',
                  ),
                  validator: (v) =>
                      RegExp(r'^\d{12}$').hasMatch((v ?? '').trim())
                      ? null
                      : 'Số CCCD phải gồm đúng 12 chữ số',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại liên hệ *',
                  ),
                  validator: (v) => (v == null || v.trim().length < 9)
                      ? 'Nhập số điện thoại hợp lệ'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ cư trú',
                  ),
                ),
                const SizedBox(height: 16),

                // 4x2 ABO/Rh Blood Type Selector
                const Text(
                  'Nhóm máu hệ ABO / Rh *',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.1,
                  children: _bloodGroups.map((bg) {
                    final active = _bloodType == bg;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _bloodType = bg),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: active
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          bg,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: active
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Chỉ số sinh hiệu (Tùy chọn)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _heightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Chiều cao (cm)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _weightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cân nặng (kg)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _bpCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Huyết áp (VD: 120/80)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _hrCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Nhịp tim (bpm)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tempCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Thân nhiệt (°C)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _spo2Ctrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'SpO2 (%)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _allergiesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dị ứng (ngăn cách bằng dấu phẩy)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _coagCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tiền sử rối loạn đông máu',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _medicationsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Thuốc đang sử dụng',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _medHistoryCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Tiền sử bệnh lý',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Người liên hệ khẩn cấp *',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emergNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Họ tên người liên hệ *',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nhập họ tên người liên hệ khẩn cấp'
                      : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emergPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'SĐT khẩn cấp *',
                        ),
                        validator: (v) => (v == null || v.trim().length < 9)
                            ? 'Nhập SĐT hợp lệ'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _emergRelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Mối quan hệ',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Đang lưu...' : 'Lưu hồ sơ y tế'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
