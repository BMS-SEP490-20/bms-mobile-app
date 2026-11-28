import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/bms_http_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../widgets/otp_pin_field_group.dart';

class _AdminUnit {
  final String code;
  final String name;
  const _AdminUnit({required this.code, required this.name});

  factory _AdminUnit.fromJson(Map<String, dynamic> json) => _AdminUnit(
    code: (json['code'] ?? json['Code'] ?? '').toString(),
    name: (json['name'] ?? json['Name'] ?? '').toString(),
  );
}

const List<_AdminUnit> _kFallbackProvinces = [
  _AdminUnit(code: '79', name: 'Thành phố Hồ Chí Minh'),
  _AdminUnit(code: '1', name: 'Thành phố Hà Nội'),
  _AdminUnit(code: '48', name: 'Thành phố Đà Nẵng'),
  _AdminUnit(code: '92', name: 'Thành phố Cần Thơ'),
  _AdminUnit(code: '31', name: 'Thành phố Hải Phòng'),
  _AdminUnit(code: '46', name: 'Thành phố Huế'),
  _AdminUnit(code: '74', name: 'Tỉnh Bình Dương'),
  _AdminUnit(code: '75', name: 'Tỉnh Đồng Nai'),
  _AdminUnit(code: '77', name: 'Tỉnh Bà Rịa - Vũng Tàu'),
  _AdminUnit(code: '80', name: 'Tỉnh Long An'),
];

/// 4-Step Patient Self-Registration Wizard matching Web `Register.jsx` 1-1:
/// Step 1: Personal identity (Name, CCCD 12-digit, VN Phone, Email, DOB, Gender) + live `/api/auth/check-availability` + walk-in link banner
/// Step 2: 3-tier Vietnamese Administrative Address (`/api/administrative/provinces|districts|wards`) + Street Address
/// Step 3: Strong Password (BR-IAM-01) + Clinical Summary -> `POST /api/auth/register`
/// Step 4: 6-digit Email OTP verification -> `POST /api/auth/verify-otp` (max 3 attempts, 60s resend)
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final BmsHttpClient _http = const BmsHttpClient();

  int _step = 1;
  bool _loading = false;
  bool _checkingAvailability = false;
  String? _errorMsg;
  String? _successMsg;

  // Step 1
  final TextEditingController _fullNameCtrl = TextEditingController();
  final TextEditingController _cccdCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  DateTime? _dob;
  String _gender = 'Nam';
  Map<String, String> _fieldErrors = {};
  Map<String, String>? _walkInHint;

  // Step 2
  List<_AdminUnit> _provinces = _kFallbackProvinces;
  List<_AdminUnit> _districts = [];
  List<_AdminUnit> _wards = [];
  String? _provinceCode;
  String _provinceName = '';
  String? _districtCode;
  String _districtName = '';
  String? _wardCode;
  String _wardName = '';
  bool _loadingDistricts = false;
  bool _loadingWards = false;
  final TextEditingController _streetCtrl = TextEditingController();

  // Step 3
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();
  bool _obscurePwd = true;
  bool _obscureConfirm = true;

  // Step 4 (OTP)
  String _otp = '';
  int _otpAttempts = 0;
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchProvinces();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fullNameCtrl.dispose();
    _cccdCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _streetCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        t.cancel();
        setState(() => _countdown = 0);
      }
    });
  }

  List<_AdminUnit> _dedupeUnits(List<dynamic> rawList) {
    final map = <String, _AdminUnit>{};
    for (final raw in rawList.whereType<Map>()) {
      final u = _AdminUnit.fromJson(Map<String, dynamic>.from(raw));
      if (u.code.isNotEmpty) map.putIfAbsent(u.code, () => u);
    }
    return map.values.toList();
  }

  Future<void> _fetchProvinces() async {
    try {
      final res = await _http.get(
        '/api/administrative/provinces',
        includeAuth: false,
      );
      if (!mounted) return;
      final unique = _dedupeUnits(res.bodyAsList);
      if (res.isSuccess && unique.isNotEmpty) {
        setState(() {
          _provinces = unique;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchDistricts(String provinceCode) async {
    setState(() {
      _loadingDistricts = true;
      _districts = [];
      _wards = [];
      _districtCode = null;
      _districtName = '';
      _wardCode = null;
      _wardName = '';
    });
    try {
      final res = await _http.get(
        '/api/administrative/districts',
        query: {'provinceCode': provinceCode},
        includeAuth: false,
      );
      if (!mounted) return;
      setState(() {
        _districts = _dedupeUnits(res.bodyAsList);
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingDistricts = false);
    }
  }

  Future<void> _fetchWards(String districtCode) async {
    setState(() {
      _loadingWards = true;
      _wards = [];
      _wardCode = null;
      _wardName = '';
    });
    try {
      final res = await _http.get(
        '/api/administrative/wards',
        query: {'districtCode': districtCode},
        includeAuth: false,
      );
      if (!mounted) return;
      setState(() {
        _wards = _dedupeUnits(res.bodyAsList);
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingWards = false);
    }
  }

  String get _fullAddressPreview {
    final parts = <String>[
      if (_streetCtrl.text.trim().isNotEmpty) _streetCtrl.text.trim(),
      if (_wardName.isNotEmpty) _wardName,
      if (_districtName.isNotEmpty) _districtName,
      if (_provinceName.isNotEmpty) _provinceName,
    ];
    return parts.join(', ');
  }

  bool _validateStep1Local() {
    final errs = <String, String>{};
    final name = _fullNameCtrl.text.trim();
    final cccd = _cccdCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.length < 2) {
      errs['fullName'] = 'Họ và tên phải có tối thiểu 2 ký tự.';
    }
    if (!RegExp(r'^[0-9]{12}$').hasMatch(cccd)) {
      errs['identityCard'] = 'Số CCCD phải gồm chính xác 12 chữ số.';
    }
    if (!RegExp(r'^(03|05|07|08|09)[0-9]{8}$').hasMatch(phone)) {
      errs['phoneNumber'] =
          'SĐT phải gồm 10 số, bắt đầu bằng 03, 05, 07, 08 hoặc 09.';
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      errs['email'] = 'Địa chỉ Email không đúng định dạng chuẩn.';
    }
    if (_dob == null) {
      errs['dateOfBirth'] = 'Vui lòng chọn ngày sinh.';
    } else if (_dob!.isAfter(DateTime.now()) || _dob!.year < 1900) {
      errs['dateOfBirth'] = 'Ngày sinh không hợp lệ.';
    }

    setState(() {
      _fieldErrors = errs;
      _errorMsg = errs.isNotEmpty
          ? 'Vui lòng kiểm tra các trường thông tin chưa hợp lệ.'
          : null;
    });
    return errs.isEmpty;
  }

  Future<bool> _checkAvailability() async {
    setState(() => _checkingAvailability = true);
    try {
      final res = await _http.get(
        '/api/auth/check-availability',
        query: {
          'email': _emailCtrl.text.trim(),
          'phoneNumber': _phoneCtrl.text.trim(),
          'identityCard': _cccdCtrl.text.trim(),
        },
        includeAuth: false,
      );
      if (!mounted) return false;
      final data = res.bodyAsMap;
      final errs = Map<String, String>.from(_fieldErrors);
      if (data['emailTaken'] == true) {
        errs['email'] =
            (data['emailMessage'] ?? 'Email này đã được đăng ký.').toString();
      }
      if (data['phoneTaken'] == true) {
        errs['phoneNumber'] =
            (data['phoneMessage'] ?? 'Số điện thoại này đã được đăng ký.')
                .toString();
      }
      if (data['identityCardTaken'] == true) {
        errs['identityCard'] =
            (data['identityCardMessage'] ?? 'Số CCCD này đã được đăng ký.')
                .toString();
      }

      if (data['walkInDetected'] == true && data['identityCardTaken'] != true) {
        _walkInHint = {
          'patientCode': (data['walkInPatientCode'] ?? '').toString(),
          'maskedName': (data['walkInMaskedName'] ?? '').toString(),
          'message':
              (data['walkInMessage'] ??
                      'Phát hiện hồ sơ khám vãng lai trùng CCCD. Tài khoản mới sẽ tự động liên kết lịch sử khám trước đây.')
                  .toString(),
        };
      } else {
        _walkInHint = null;
      }

      final ok =
          data['available'] != false &&
          data['emailTaken'] != true &&
          data['phoneTaken'] != true &&
          data['identityCardTaken'] != true;

      setState(() {
        _fieldErrors = errs;
        if (!ok) {
          _errorMsg = (data['message'] ??
                  'Thông tin định danh (CCCD, SĐT hoặc Email) đã tồn tại trong hệ thống.')
              .toString();
        }
      });
      return ok;
    } catch (_) {
      return true;
    } finally {
      if (mounted) setState(() => _checkingAvailability = false);
    }
  }

  Future<void> _goToStep2() async {
    FocusScope.of(context).unfocus();
    if (!_validateStep1Local()) return;
    final available = await _checkAvailability();
    if (!available || !mounted) return;
    setState(() {
      _step = 2;
      _errorMsg = null;
    });
  }

  void _goToStep3() {
    FocusScope.of(context).unfocus();
    if (_provinceCode == null ||
        _districtCode == null ||
        _wardCode == null ||
        _streetCtrl.text.trim().length < 3) {
      setState(() {
        _errorMsg =
            'Vui lòng chọn đầy đủ Tỉnh/Huyện/Xã và nhập số nhà, tên đường (tối thiểu 3 ký tự).';
      });
      return;
    }
    setState(() {
      _step = 3;
      _errorMsg = null;
    });
  }

  Map<String, bool> get _pwdRules {
    final p = _passwordCtrl.text;
    return {
      'length': p.length >= 8,
      'upper': RegExp(r'[A-Z]').hasMatch(p),
      'lower': RegExp(r'[a-z]').hasMatch(p),
      'digit': RegExp(r'[0-9]').hasMatch(p),
      'special': RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(p),
      'match': p.isNotEmpty && p == _confirmPasswordCtrl.text,
    };
  }

  Map<String, dynamic> _buildRegisterPayload() => {
    'fullName': _fullNameCtrl.text.trim(),
    'email': _emailCtrl.text.trim(),
    'username': _emailCtrl.text.trim(),
    'password': _passwordCtrl.text,
    'confirmPassword': _confirmPasswordCtrl.text,
    'phoneNumber': _phoneCtrl.text.trim(),
    'identityCard': _cccdCtrl.text.trim(),
    'gender': _gender,
    'dateOfBirth': _dob?.toUtc().toIso8601String(),
    'province': _provinceName,
    'district': _districtName,
    'ward': _wardName,
    'streetAddress': _streetCtrl.text.trim(),
    'address': _fullAddressPreview,
  };

  Future<void> _submitRegister() async {
    FocusScope.of(context).unfocus();
    final rules = _pwdRules;
    if (rules.values.any((v) => !v)) {
      setState(() {
        _errorMsg =
            'Mật khẩu phải có tối thiểu 8 ký tự gồm chữ hoa, chữ thường, số, ký tự đặc biệt và khớp xác nhận.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
      _successMsg = null;
    });

    try {
      final res = await _http.post(
        '/api/auth/register',
        includeAuth: false,
        body: _buildRegisterPayload(),
      );
      if (!mounted) return;
      if (res.isSuccess) {
        setState(() {
          _step = 4;
          _otp = '';
          _otpAttempts = 0;
          _successMsg = res.extractMessage(
            'Đăng ký bước đầu thành công! Mã OTP 6 số đã được gửi tới ${_emailCtrl.text.trim()}.',
          );
        });
        _startCountdown();
      } else {
        final body = res.bodyAsMap;
        final conflict = (body['field'] ?? body['Field'] ?? '').toString();
        setState(() {
          _errorMsg = res.extractMessage(
            'Đăng ký không thành công. Vui lòng kiểm tra lại thông tin.',
          );
          if (const ['email', 'phoneNumber', 'identityCard']
              .contains(conflict)) {
            _fieldErrors[conflict] = _errorMsg!;
            _step = 1;
          }
        });
      }
    } on BmsApiException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp([String? code]) async {
    final otpVal = (code ?? _otp).trim();
    if (otpVal.length != 6) {
      setState(() => _errorMsg = 'Vui lòng nhập đủ 6 chữ số mã OTP.');
      return;
    }
    if (_otpAttempts >= 3) {
      setState(
        () => _errorMsg =
            'Bạn đã nhập sai OTP quá 3 lần. Vui lòng yêu cầu gửi lại mã mới.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final res = await _http.post(
        '/api/auth/verify-otp',
        includeAuth: false,
        body: {'email': _emailCtrl.text.trim(), 'otp': otpVal},
      );
      if (!mounted) return;
      if (res.isSuccess) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _otpAttempts++;
          _errorMsg = res.extractMessage(
            'Mã OTP không chính xác hoặc đã hết hạn.',
          );
        });
      }
    } on BmsApiException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_countdown > 0 || _loading) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      var res = await _http.post(
        '/api/auth/register',
        includeAuth: false,
        body: _buildRegisterPayload(),
      );
      if (!res.isSuccess) {
        res = await _http.post(
          '/api/auth/otp/send',
          includeAuth: false,
          body: {
            'destination': _emailCtrl.text.trim(),
            'purpose': 'Registration',
            'channel': 'Email',
          },
        );
      }
      if (!mounted) return;
      if (res.isSuccess) {
        setState(() {
          _otp = '';
          _otpAttempts = 0;
          _successMsg =
              'Mã OTP mới đã được gửi lại vào email ${_emailCtrl.text.trim()}.';
        });
        _startCountdown();
      } else {
        setState(
          () => _errorMsg = res.extractMessage('Không thể gửi lại mã OTP.'),
        );
      }
    } on BmsApiException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null && mounted) {
      setState(() {
        _dob = picked;
        _fieldErrors.remove('dateOfBirth');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const stepLabels = ['Cá nhân', 'Địa chỉ', 'Mật khẩu', 'Xác thực'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Đăng ký tài khoản Bệnh nhân')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 4-step indicator bar
              BmsSoftCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: Row(
                  children: List.generate(4, (i) {
                    final num = i + 1;
                    final done = _step > num;
                    final active = _step == num;
                    return Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done
                                  ? AppColors.success
                                  : active
                                  ? AppColors.primary
                                  : AppColors.surfaceMuted,
                            ),
                            child: Center(
                              child: done
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : Text(
                                      '$num',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: active
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            stepLabels[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 14),

              if (_errorMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.dangerBorder),
                  ),
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(
                      color: AppColors.dangerText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_successMsg != null && _errorMsg == null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.successBorder),
                  ),
                  child: Text(
                    _successMsg!,
                    style: const TextStyle(
                      color: AppColors.successText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              BmsSoftCard(
                padding: const EdgeInsets.all(18),
                child: _step == 1
                    ? _buildStep1()
                    : _step == 2
                    ? _buildStep2()
                    : _step == 3
                    ? _buildStep3()
                    : _buildStep4(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Bước 1: Thông tin cá nhân & định danh y tế',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Dữ liệu được đối soát chuẩn ISO 15189 & QĐ 2429/QĐ-BYT.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        if (_walkInHint != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.link_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_walkInHint!['message']} (${_walkInHint!['patientCode']})',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        TextField(
          controller: _fullNameCtrl,
          decoration: InputDecoration(
            labelText: 'Họ và tên bệnh nhân *',
            hintText: 'VD: Nguyễn Văn An',
            errorText: _fieldErrors['fullName'],
            prefixIcon: const Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cccdCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
          ],
          decoration: InputDecoration(
            labelText: 'Số CCCD (12 chữ số) *',
            hintText: '079201001234',
            errorText: _fieldErrors['identityCard'],
            prefixIcon: const Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            labelText: 'Số điện thoại (10 số) *',
            hintText: '0901234567',
            errorText: _fieldErrors['phoneNumber'],
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email nhận kết quả & OTP *',
            hintText: 'patient@example.com',
            errorText: _fieldErrors['email'],
            prefixIcon: const Icon(Icons.mail_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickDob,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Ngày sinh *',
              errorText: _fieldErrors['dateOfBirth'],
              prefixIcon: const Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              _dob != null
                  ? DateFormat('dd/MM/yyyy').format(_dob!)
                  : 'Chọn ngày sinh',
              style: TextStyle(
                color: _dob != null
                    ? AppColors.textPrimary
                    : AppColors.textPlaceholder,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _gender,
          decoration: const InputDecoration(
            labelText: 'Giới tính *',
            prefixIcon: Icon(Icons.wc_rounded),
          ),
          items: const [
            DropdownMenuItem(value: 'Nam', child: Text('Nam')),
            DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
            DropdownMenuItem(value: 'Khác', child: Text('Khác')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _gender = v);
          },
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _checkingAvailability ? null : _goToStep2,
            child: Text(
              _checkingAvailability
                  ? 'Đang kiểm tra định danh...'
                  : 'Tiếp tục: Địa chỉ thường trú',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Bước 2: Địa chỉ thường trú (3 cấp hành chính)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          key: ValueKey('prov_${_provinceCode ?? ''}_${_provinces.length}'),
          initialValue: _provinces.any((p) => p.code == _provinceCode)
              ? _provinceCode
              : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Tỉnh / Thành phố *',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          items: _provinces
              .map(
                (p) => DropdownMenuItem(
                  value: p.code,
                  child: Text(p.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (code) {
            if (code == null) return;
            final found = _provinces.firstWhere((p) => p.code == code);
            setState(() {
              _provinceCode = code;
              _provinceName = found.name;
            });
            _fetchDistricts(code);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('dist_${_districtCode ?? ''}_${_districts.length}'),
          initialValue: _districts.any((d) => d.code == _districtCode)
              ? _districtCode
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _loadingDistricts
                ? 'Đang tải Quận / Huyện...'
                : 'Quận / Huyện *',
            prefixIcon: const Icon(Icons.map_outlined),
          ),
          items: _districts
              .map(
                (d) => DropdownMenuItem(
                  value: d.code,
                  child: Text(d.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: _districts.isEmpty
              ? null
              : (code) {
                  if (code == null) return;
                  final found = _districts.firstWhere((d) => d.code == code);
                  setState(() {
                    _districtCode = code;
                    _districtName = found.name;
                  });
                  _fetchWards(code);
                },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('ward_${_wardCode ?? ''}_${_wards.length}'),
          initialValue: _wards.any((w) => w.code == _wardCode)
              ? _wardCode
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _loadingWards
                ? 'Đang tải Phường / Xã...'
                : 'Phường / Xã *',
            prefixIcon: const Icon(Icons.place_outlined),
          ),
          items: _wards
              .map(
                (w) => DropdownMenuItem(
                  value: w.code,
                  child: Text(w.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: _wards.isEmpty
              ? null
              : (code) {
                  if (code == null) return;
                  final found = _wards.firstWhere((w) => w.code == code);
                  setState(() {
                    _wardCode = code;
                    _wardName = found.name;
                  });
                },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _streetCtrl,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Số nhà, tên đường / thôn xóm *',
            hintText: 'VD: 120 Hai Bà Trưng',
            prefixIcon: Icon(Icons.home_outlined),
          ),
        ),
        if (_fullAddressPreview.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Text(
              'Địa chỉ đầy đủ: $_fullAddressPreview',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text('Quay lại'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _goToStep3,
                child: const Text('Tiếp tục: Mật khẩu'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3() {
    final rules = _pwdRules;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Bước 3: Thiết lập mật khẩu bảo mật',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePwd,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Mật khẩu bảo mật *',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
              icon: Icon(
                _obscurePwd
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPasswordCtrl,
          obscureText: _obscureConfirm,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Xác nhận mật khẩu *',
            prefixIcon: const Icon(Icons.lock_reset_rounded),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ruleRow('Tối thiểu 8 ký tự', rules['length']!),
        _ruleRow('Có ít nhất 1 chữ in hoa (A-Z)', rules['upper']!),
        _ruleRow('Có ít nhất 1 chữ thường (a-z)', rules['lower']!),
        _ruleRow('Có ít nhất 1 chữ số (0-9)', rules['digit']!),
        _ruleRow('Có ít nhất 1 ký tự đặc biệt (!@#\$...)', rules['special']!),
        _ruleRow('Khớp với mật khẩu xác nhận', rules['match']!),
        const Divider(height: 22),
        const Text(
          'Đối soát thông tin hồ sơ',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        BmsInfoRow(label: 'Họ và tên', value: _fullNameCtrl.text.trim()),
        BmsInfoRow(label: 'CCCD', value: _cccdCtrl.text.trim(), isMono: true),
        BmsInfoRow(label: 'Email', value: _emailCtrl.text.trim()),
        BmsInfoRow(label: 'Địa chỉ', value: _fullAddressPreview),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : () => setState(() => _step = 2),
                child: const Text('Quay lại'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _loading ? null : _submitRegister,
                child: Text(
                  _loading ? 'Đang gửi mã OTP...' : 'Đăng ký & Nhận OTP',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _ruleRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 16,
            color: ok ? AppColors.success : AppColors.textTertiary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ok ? AppColors.successText : AppColors.textSecondary,
              fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Bước 4: Xác thực mã OTP 6 chữ số',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Mã OTP đã gửi đến email ${_emailCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        OtpPinFieldGroup(
          length: 6,
          hasError: _errorMsg != null,
          enabled: !_loading,
          onChanged: (v) => setState(() => _otp = v),
          onCompleted: _verifyOtp,
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: (_loading || _otp.length != 6) ? null : _verifyOtp,
            child: Text(
              _loading ? 'Đang xác thực...' : 'Xác thực & Kích hoạt tài khoản',
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: (_countdown == 0 && !_loading) ? _resendOtp : null,
            child: Text(
              _countdown > 0
                  ? 'Gửi lại mã OTP sau ${_countdown}s'
                  : 'Gửi lại mã OTP mới',
            ),
          ),
        ),
      ],
    );
  }
}
