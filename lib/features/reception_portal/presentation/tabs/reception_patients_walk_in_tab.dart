import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../data/reception_portal_api.dart';

/// Tab 2 — Walk-in Registration (CCCD/Phone lookup + Queue/Booking) & Patient Directory.
class ReceptionPatientsWalkInTab extends StatefulWidget {
  final VoidCallback onOpenQueueTab;

  const ReceptionPatientsWalkInTab({super.key, required this.onOpenQueueTab});

  @override
  State<ReceptionPatientsWalkInTab> createState() =>
      _ReceptionPatientsWalkInTabState();
}

class _ReceptionPatientsWalkInTabState
    extends State<ReceptionPatientsWalkInTab> {
  final ReceptionPortalApi _api = const ReceptionPortalApi();

  int _subTab = 0;

  // Walk-in form controllers
  final TextEditingController _lookupCtrl = TextEditingController();
  final TextEditingController _fullNameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _cccdCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  DateTime _dob = DateTime(1992, 5, 15);
  String _gender = 'Male';
  String _bloodType = '';
  String _priority = 'NORMAL';
  bool _lookingUp = false;
  bool _registering = false;
  Map<String, dynamic>? _registeredWalkIn;

  // Directory state
  final TextEditingController _dirSearchCtrl = TextEditingController();
  bool? _isGuestFilter;
  List<Map<String, dynamic>> _patients = [];
  bool _loadingDirectory = false;
  String? _directoryError;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  @override
  void dispose() {
    _lookupCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _cccdCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _dirSearchCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.textPrimary,
      ),
    );
  }

  Future<void> _quickLookup() async {
    final q = _lookupCtrl.text.trim();
    if (q.isEmpty) {
      _showSnack('Nhập số CCCD (12 số) hoặc số điện thoại để tra cứu.', isError: true);
      return;
    }

    setState(() => _lookingUp = true);
    try {
      final res = q.length == 12
          ? await _api.lookupWalkInByIdentity(q)
          : await _api.lookupWalkInByPhone(q);

      if (!mounted) return;
      setState(() => _lookingUp = false);

      final data = res?['data'] is Map
          ? Map<String, dynamic>.from(res!['data'] as Map)
          : res;

      if (data != null &&
          (data['fullName'] != null || data['patientId'] != null || data['id'] != null)) {
        setState(() {
          _fullNameCtrl.text = (data['fullName'] ?? '').toString();
          _phoneCtrl.text =
              (data['phoneNumber'] ?? data['phone'] ?? _phoneCtrl.text)
                  .toString();
          _cccdCtrl.text =
              (data['identityNumber'] ?? _cccdCtrl.text).toString();
          _emailCtrl.text = (data['email'] ?? '').toString();
          _addressCtrl.text = (data['address'] ?? '').toString();
          final parsedDob = DateTime.tryParse(
            (data['dateOfBirth'] ?? '').toString(),
          );
          if (parsedDob != null) _dob = parsedDob;
          final g = (data['gender'] ?? '').toString();
          if (g == 'Female' || g == 'Male') _gender = g;
        });
        _showSnack('Đã tìm thấy hồ sơ sẵn có và điền tự động thông tin.');
      } else {
        if (q.length == 12) {
          _cccdCtrl.text = q;
        } else {
          _phoneCtrl.text = q;
        }
        _showSnack('Chưa có hồ sơ cũ. Vui lòng điền thông tin tiếp nhận mới.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _lookingUp = false);
      _showSnack('Chưa tìm thấy hồ sơ trùng khớp, mời nhập mới.');
    }
  }

  Future<void> _submitWalkIn() async {
    final name = _fullNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final cccd = _cccdCtrl.text.trim();

    if (name.length < 2) {
      _showSnack('Vui lòng nhập đầy đủ họ và tên bệnh nhân.', isError: true);
      return;
    }
    if (phone.length < 9) {
      _showSnack('Số điện thoại liên hệ không hợp lệ.', isError: true);
      return;
    }
    if (cccd.isNotEmpty && cccd.length != 12) {
      _showSnack('Số CCCD phải gồm đúng 12 chữ số (hoặc để trống cho khách vãng lai).', isError: true);
      return;
    }

    setState(() => _registering = true);
    try {
      final result = await _api.registerWalkInPatient(
        fullName: name,
        dateOfBirth: _dob,
        gender: _gender,
        phone: phone,
        identityNumber: cccd.isEmpty ? null : cccd,
        email: _emailCtrl.text,
        address: _addressCtrl.text,
        bloodType: _bloodType.isEmpty ? null : _bloodType,
        priority: _priority,
      );
      if (!mounted) return;
      final data = result['data'] is Map
          ? Map<String, dynamic>.from(result['data'] as Map)
          : result;
      setState(() {
        _registeredWalkIn = {
          ...data,
          'fullName': data['fullName'] ?? name,
          'phoneNumber': data['phoneNumber'] ?? data['phone'] ?? phone,
        };
        _registering = false;
      });
      _showSnack('Đã tiếp nhận hồ sơ vãng lai thành công.');
      _loadDirectory();
    } catch (e) {
      if (!mounted) return;
      setState(() => _registering = false);
      _showSnack(
        e.toString().replaceFirst('BmsApiException: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _issueTicketForPatient(Map<String, dynamic> patient) async {
    final patId = (patient['patientId'] ?? patient['id'] ?? '').toString();
    final patName = (patient['fullName'] ?? 'Bệnh nhân').toString();
    final patCode = (patient['patientCode'] ?? '').toString();
    final queuePriority = _priority == 'STAT'
        ? 'STAT'
        : (_priority == 'URGENT' ? 'Urgent' : 'Routine');

    try {
      final ticket = await _api.issueQueueTicket(
        patientId: patId.isEmpty ? null : patId,
        patientName: patName,
        patientCode: patCode.isEmpty ? null : patCode,
        isWalkIn: true,
        priority: queuePriority,
      );
      final numStr = (ticket['ticketNumber'] ?? 'mới').toString();
      _showSnack('Đã cấp phiếu thứ tự $numStr cho $patName.');
      widget.onOpenQueueTab();
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('BmsApiException: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _loadDirectory() async {
    setState(() {
      _loadingDirectory = true;
      _directoryError = null;
    });
    try {
      final list = await _api.searchPatients(
        search: _dirSearchCtrl.text,
        isGuest: _isGuestFilter,
      );
      if (!mounted) return;
      setState(() {
        _patients = list;
        _loadingDirectory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _directoryError = e.toString().replaceFirst('BmsApiException: ', '');
        _loadingDirectory = false;
      });
    }
  }

  Future<void> _openPatientDetailSheet(Map<String, dynamic> summary) async {
    final id = (summary['id'] ?? '').toString();
    Map<String, dynamic> detail = summary;
    if (id.isNotEmpty) {
      try {
        detail = await _api.getPatientById(id);
      } catch (_) {}
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              (detail['fullName'] ?? 'Hồ sơ bệnh nhân').toString(),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            BmsInfoRow(
              label: 'Mã bệnh nhân',
              value: (detail['patientCode'] ?? id).toString(),
              isMono: true,
            ),
            BmsInfoRow(
              label: 'Ngày sinh',
              value: BmsFormatters.date(detail['dateOfBirth']),
            ),
            BmsInfoRow(
              label: 'Giới tính',
              value: BmsFormatters.genderVi(detail['gender']?.toString()),
            ),
            BmsInfoRow(
              label: 'Số điện thoại',
              value: (detail['phoneNumber'] ?? detail['phone'] ?? '—')
                  .toString(),
            ),
            BmsInfoRow(
              label: 'Số CCCD',
              value: (detail['identityNumber'] ?? 'Chưa cập nhật').toString(),
            ),
            BmsInfoRow(
              label: 'Nhóm máu',
              value: (detail['bloodType'] ?? 'Chưa xác định').toString(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _issueTicketForPatient(detail);
                    },
                    icon: const Icon(Icons.confirmation_number_outlined, size: 17),
                    label: const Text('Cấp số thứ tự'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openBookOnBehalfSheet(detail);
                    },
                    icon: const Icon(Icons.event_available_rounded, size: 17),
                    label: const Text('Đặt lịch hộ BN'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBookOnBehalfSheet(Map<String, dynamic> patient) async {
    final patId = (patient['patientId'] ?? patient['id'] ?? '').toString();
    final patName = (patient['fullName'] ?? 'Bệnh nhân').toString();
    if (patId.isEmpty) return;

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    final packages = await _api.searchTestPackages();
    final doctors = await _api.getAvailableDoctors(
      BmsFormatters.isoDate(selectedDate),
    );
    if (!mounted) return;

    String selectedDoctorId = doctors.isNotEmpty
        ? (doctors.first['id'] ?? doctors.first['doctorId'] ?? '').toString()
        : '';
    List<Map<String, dynamic>> slots = selectedDoctorId.isNotEmpty
        ? await _api.getAvailableSlots(
            doctorId: selectedDoctorId,
            date: BmsFormatters.isoDate(selectedDate),
          )
        : [];
    if (!mounted) return;

    String selectedSlot = slots.isNotEmpty
        ? (slots.first['slotTime'] ?? slots.first['time'] ?? '08:00').toString()
        : '08:00';
    final selectedPkgIds = <String>{
      if (packages.isNotEmpty) (packages.first['id'] ?? '').toString(),
    }..removeWhere((e) => e.isEmpty);

    final notesCtrl = TextEditingController(
      text: 'Đặt lịch trực tiếp tại quầy Lễ tân',
    );
    bool saving = false;

    final booked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final slotStrings = slots.isNotEmpty
              ? slots
                  .map((s) => (s['slotTime'] ?? s['time'] ?? '').toString())
                  .where((s) => s.isNotEmpty)
                  .toList()
              : const ['07:30', '08:00', '08:30', '09:00', '14:00', '15:00'];

          return Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Đặt lịch khám hộ: $patName',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (d != null) {
                        final nextDoctors = await _api.getAvailableDoctors(
                          BmsFormatters.isoDate(d),
                        );
                        setSheetState(() {
                          selectedDate = d;
                          if (nextDoctors.isNotEmpty) {
                            selectedDoctorId = (nextDoctors.first['id'] ??
                                    nextDoctors.first['doctorId'] ??
                                    '')
                                .toString();
                          }
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: Text(
                      'Ngày khám: ${BmsFormatters.date(selectedDate)}',
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (doctors.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedDoctorId,
                      decoration: const InputDecoration(
                        labelText: 'Bác sĩ phụ trách',
                      ),
                      items: doctors.map((doc) {
                        final id =
                            (doc['id'] ?? doc['doctorId'] ?? '').toString();
                        final name =
                            (doc['fullName'] ?? doc['doctorName'] ?? id)
                                .toString();
                        return DropdownMenuItem(value: id, child: Text(name));
                      }).toList(),
                      onChanged: (val) async {
                        if (val == null) return;
                        final nextSlots = await _api.getAvailableSlots(
                          doctorId: val,
                          date: BmsFormatters.isoDate(selectedDate),
                        );
                        setSheetState(() {
                          selectedDoctorId = val;
                          slots = nextSlots;
                        });
                      },
                    ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: slotStrings.contains(selectedSlot)
                        ? selectedSlot
                        : slotStrings.first,
                    decoration: const InputDecoration(
                      labelText: 'Khung giờ hẹn',
                    ),
                    items: slotStrings
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheetState(() => selectedSlot = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Chọn gói xét nghiệm:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: packages.length,
                      itemBuilder: (_, idx) {
                        final pkg = packages[idx];
                        final id = (pkg['id'] ?? '').toString();
                        final name = (pkg['name'] ?? '').toString();
                        final price = num.tryParse(
                          (pkg['price'] ?? '0').toString(),
                        );
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.primary,
                          value: selectedPkgIds.contains(id),
                          title: Text(name, style: const TextStyle(fontSize: 13)),
                          subtitle: Text(BmsFormatters.currency(price)),
                          onChanged: (v) {
                            setSheetState(() {
                              if (v == true) {
                                selectedPkgIds.add(id);
                              } else {
                                selectedPkgIds.remove(id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'Ghi chú'),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (selectedPkgIds.isEmpty) {
                              _showSnack(
                                'Vui lòng chọn ít nhất 1 gói xét nghiệm.',
                                isError: true,
                              );
                              return;
                            }
                            setSheetState(() => saving = true);
                            try {
                              await _api.bookAppointmentForPatient(
                                patientId: patId,
                                doctorId: selectedDoctorId,
                                appointmentDate: BmsFormatters.isoDate(
                                  selectedDate,
                                ),
                                slotTime: selectedSlot,
                                packageIds: selectedPkgIds.toList(),
                                notes: notesCtrl.text,
                              );
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setSheetState(() => saving = false);
                              _showSnack(
                                e.toString().replaceFirst(
                                  'BmsApiException: ',
                                  '',
                                ),
                                isError: true,
                              );
                            }
                          },
                    child: Text(saving ? 'Đang đặt lịch...' : 'Xác nhận đặt lịch'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (booked == true) {
      _showSnack('Đã đặt lịch khám hộ bệnh nhân $patName thành công.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        const BmsPageHeaderCard(
          icon: Icons.person_add_alt_1_rounded,
          badgeText: 'Quản lý tiếp nhận bệnh nhân',
          title: 'Khách vãng lai & Hồ sơ BN',
          subtitle: 'Tra cứu nhanh CCCD/SĐT, đăng ký vãng lai và đặt lịch khám hộ',
        ),
        const SizedBox(height: 14),
        BmsSegmentedTabs(
          tabs: const ['Tiếp nhận vãng lai', 'Hồ sơ bệnh nhân'],
          selectedIndex: _subTab,
          onChanged: (idx) => setState(() => _subTab = idx),
        ),
        const SizedBox(height: 14),
        if (_subTab == 0) _buildWalkInView() else _buildDirectoryView(),
      ],
    );
  }

  Widget _buildWalkInView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BmsSoftCard(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tra cứu nhanh hồ sơ sẵn có',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lookupCtrl,
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _quickLookup(),
                      decoration: const InputDecoration(
                        hintText: 'Nhập 12 số CCCD hoặc số điện thoại...',
                        prefixIcon: Icon(Icons.badge_outlined, size: 19),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _lookingUp ? null : _quickLookup,
                    child: Text(_lookingUp ? 'Đang tìm...' : 'Tra cứu'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_registeredWalkIn != null) ...[
          const SizedBox(height: 12),
          BmsSoftCard(
            backgroundColor: AppColors.successLight,
            borderColor: AppColors.successBorder,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Đã tạo hồ sơ: ${_registeredWalkIn!['fullName']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: AppColors.successText,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            _issueTicketForPatient(_registeredWalkIn!),
                        icon: const Icon(
                          Icons.confirmation_number_outlined,
                          size: 17,
                        ),
                        label: const Text('Cấp số thứ tự'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _openBookOnBehalfSheet(_registeredWalkIn!),
                        icon: const Icon(
                          Icons.event_available_outlined,
                          size: 17,
                        ),
                        label: const Text('Đặt lịch hẹn'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        BmsSoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Phiếu đăng ký khách vãng lai',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fullNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên bệnh nhân *',
                ),
              ),
              const SizedBox(height: 10),
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
                      label: Text('NS: ${BmsFormatters.date(_dob)}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(labelText: 'Giới tính'),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Nam')),
                        DropdownMenuItem(value: 'Female', child: Text('Nữ')),
                        DropdownMenuItem(value: 'Other', child: Text('Khác')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _gender = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại *',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _cccdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Số CCCD (12 số)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Độ ưu tiên tiếp đón',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'NORMAL',
                          child: Text('Thường quy'),
                        ),
                        DropdownMenuItem(
                          value: 'URGENT',
                          child: Text('Ưu tiên / Khẩn'),
                        ),
                        DropdownMenuItem(
                          value: 'STAT',
                          child: Text('Cấp cứu (STAT)'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _priority = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _bloodType,
                      decoration: const InputDecoration(labelText: 'Nhóm máu'),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Chưa rõ')),
                        DropdownMenuItem(value: 'A+', child: Text('A+')),
                        DropdownMenuItem(value: 'B+', child: Text('B+')),
                        DropdownMenuItem(value: 'O+', child: Text('O+')),
                        DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                        DropdownMenuItem(value: 'O-', child: Text('O-')),
                      ],
                      onChanged: (v) => setState(() => _bloodType = v ?? ''),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ cư trú',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _registering ? null : _submitWalkIn,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                label: Text(
                  _registering ? 'Đang đăng ký...' : 'Đăng ký tiếp nhận vãng lai',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDirectoryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BmsSearchFilterBar(
          controller: _dirSearchCtrl,
          hintText: 'Tìm họ tên, mã BN, số điện thoại, CCCD...',
          onSubmitted: (_) => _loadDirectory(),
          onClear: _loadDirectory,
          trailing: FilledButton(
            onPressed: _loadDirectory,
            child: const Text('Tìm'),
          ),
          filterChips: [
            BmsFilterChipItem(
              key: 'all',
              label: 'Tất cả BN',
              selected: _isGuestFilter == null,
              onSelected: () {
                setState(() => _isGuestFilter = null);
                _loadDirectory();
              },
            ),
            BmsFilterChipItem(
              key: 'registered',
              label: 'Có tài khoản',
              selected: _isGuestFilter == false,
              onSelected: () {
                setState(() => _isGuestFilter = false);
                _loadDirectory();
              },
            ),
            BmsFilterChipItem(
              key: 'guest',
              label: 'Khách vãng lai',
              selected: _isGuestFilter == true,
              onSelected: () {
                setState(() => _isGuestFilter = true);
                _loadDirectory();
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_loadingDirectory)
          const BmsLoadingState(message: 'Đang tải danh mục bệnh nhân...')
        else if (_directoryError != null)
          BmsErrorState(message: _directoryError!, onRetry: _loadDirectory)
        else if (_patients.isEmpty)
          const BmsEmptyState(
            icon: Icons.people_outline_rounded,
            title: 'Không tìm thấy bệnh nhân',
            subtitle: 'Thử thay đổi bộ lọc hoặc đăng ký mới ở tab Tiếp nhận vãng lai.',
          )
        else
          ..._patients.map((p) {
            final name = (p['fullName'] ?? 'Bệnh nhân').toString();
            final code = (p['patientCode'] ?? p['id'] ?? '').toString();
            final phone = (p['phoneNumber'] ?? p['phone'] ?? '—').toString();
            final isGuest = p['isGuest'] == true;

            return BmsSoftCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              onTap: () => _openPatientDetailSheet(p),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$code · SĐT: $phone',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  BmsStatusPill(
                    status: isGuest ? 'Pending' : 'Confirmed',
                    customLabel: isGuest ? 'Vãng lai' : 'Thành viên',
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
