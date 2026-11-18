import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../appointment/presentation/book_appointment_screen.dart';
import '../../data/patient_portal_api.dart';

/// Tab 2 of PatientShellScreen — Appointments Listing, QR Check-in, Rescheduling & Cancellation.
class PatientAppointmentsTab extends StatefulWidget {
  const PatientAppointmentsTab({super.key});

  @override
  State<PatientAppointmentsTab> createState() => _PatientAppointmentsTabState();
}

class _PatientAppointmentsTabState extends State<PatientAppointmentsTab> {
  final PatientPortalApi _api = const PatientPortalApi();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getAppointments(page: 1, pageSize: 30);
      if (!mounted) return;
      setState(() {
        _items = list;
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

  List<Map<String, dynamic>> get _filtered {
    final kw = _searchCtrl.text.trim().toLowerCase();
    return _items.where((item) {
      final st = (item['status'] ?? '')
          .toString()
          .toLowerCase()
          .replaceAll('_', '');
      if (_statusFilter != 'all') {
        if (_statusFilter == 'confirmed' &&
            st != 'confirmed' &&
            st != 'pending' &&
            st != 'scheduled') {
          return false;
        } else if (_statusFilter == 'checkedin' && st != 'checkedin') {
          return false;
        } else if (_statusFilter == 'completed' && st != 'completed') {
          return false;
        } else if (_statusFilter == 'cancelled' && st != 'cancelled') {
          return false;
        }
      }
      if (kw.isNotEmpty) {
        final code =
            (item['appointmentCode'] ?? item['appointmentId'] ?? '')
                .toString()
                .toLowerCase();
        final doc = (item['doctorName'] ?? '').toString().toLowerCase();
        final pkg =
            (item['testPackageName'] ?? item['packageName'] ?? '')
                .toString()
                .toLowerCase();
        return code.contains(kw) || doc.contains(kw) || pkg.contains(kw);
      }
      return true;
    }).toList();
  }

  Future<void> _openDetailSheet(Map<String, dynamic> appt) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PatientAppointmentDetailSheet(
        api: _api,
        appointment: appt,
      ),
    );
    if (changed == true) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filtered;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              children: [
                BmsPageHeaderCard(
                  icon: Icons.calendar_month_rounded,
                  title: 'Lịch hẹn xét nghiệm',
                  subtitle:
                      'Quản lý lịch khám, xem mã QR check-in hoặc dời lịch hẹn trực tuyến',
                  trailing: FilledButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BookAppointmentScreen(),
                        ),
                      );
                      _load();
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Đặt lịch mới'),
                  ),
                ),
                const SizedBox(height: 12),
                BmsSearchFilterBar(
                  controller: _searchCtrl,
                  hintText: 'Tìm mã lịch hẹn, bác sĩ, gói khám...',
                  onChanged: (_) => setState(() {}),
                  filterChips: [
                    BmsFilterChipItem(
                      key: 'all',
                      label: 'Tất cả',
                      selected: _statusFilter == 'all',
                      onSelected: () => setState(() => _statusFilter = 'all'),
                    ),
                    BmsFilterChipItem(
                      key: 'confirmed',
                      label: 'Đã xác nhận',
                      selected: _statusFilter == 'confirmed',
                      onSelected: () =>
                          setState(() => _statusFilter = 'confirmed'),
                    ),
                    BmsFilterChipItem(
                      key: 'checkedin',
                      label: 'Đã check-in',
                      selected: _statusFilter == 'checkedin',
                      onSelected: () =>
                          setState(() => _statusFilter = 'checkedin'),
                    ),
                    BmsFilterChipItem(
                      key: 'completed',
                      label: 'Hoàn thành',
                      selected: _statusFilter == 'completed',
                      onSelected: () =>
                          setState(() => _statusFilter = 'completed'),
                    ),
                    BmsFilterChipItem(
                      key: 'cancelled',
                      label: 'Đã hủy',
                      selected: _statusFilter == 'cancelled',
                      onSelected: () =>
                          setState(() => _statusFilter = 'cancelled'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const BmsLoadingState(message: 'Đang tải danh sách lịch hẹn...')
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: BmsErrorState(message: _error!, onRetry: _load),
                    ),
                  )
                : visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: BmsEmptyState(
                        icon: Icons.event_note_rounded,
                        title: 'Không có lịch hẹn phù hợp',
                        subtitle:
                            'Đặt lịch xét nghiệm mới để được cấp mã QR check-in nhanh tại quầy.',
                        actionLabel: 'Đặt lịch mới',
                        onAction: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BookAppointmentScreen(),
                            ),
                          );
                          _load();
                        },
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final appt = visible[idx];
                        final code =
                            (appt['appointmentCode'] ??
                                    appt['appointmentId'] ??
                                    appt['id'] ??
                                    '')
                                .toString();
                        final pkg =
                            (appt['testPackageName'] ??
                                    appt['packageName'] ??
                                    appt['packageId'] ??
                                    'Khám & Xét nghiệm')
                                .toString();
                        final doc =
                            (appt['doctorName'] ?? 'Bác sĩ chuyên khoa')
                                .toString();
                        final status = (appt['status'] ?? 'Confirmed')
                            .toString();
                        final dateStr = BmsFormatters.date(
                          appt['appointmentDate'] ?? appt['appointmentTime'],
                        );
                        final slot = (appt['slotTime'] ?? '').toString();
                        final queueNumber = appt['queueNumber'];

                        return BmsSoftCard(
                          onTap: () => _openDetailSheet(appt),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    code,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  BmsStatusPill(status: status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                pkg,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.medical_services_outlined,
                                    size: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      doc,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    size: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$dateStr${slot.isNotEmpty ? ' · $slot' : ''}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (queueNumber != null) ...[
                                    const Spacer(),
                                    Text(
                                      'STT: Q-${queueNumber.toString().padLeft(3, '0')}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.successText,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PatientAppointmentDetailSheet extends StatefulWidget {
  final PatientPortalApi api;
  final Map<String, dynamic> appointment;

  const _PatientAppointmentDetailSheet({
    required this.api,
    required this.appointment,
  });

  @override
  State<_PatientAppointmentDetailSheet> createState() =>
      _PatientAppointmentDetailSheetState();
}

class _PatientAppointmentDetailSheetState
    extends State<_PatientAppointmentDetailSheet> {
  Map<String, dynamic>? _confirmation;
  bool _loading = true;
  bool _submitting = false;

  String get _appointmentId =>
      (widget.appointment['appointmentId'] ?? widget.appointment['id'] ?? '')
          .toString();

  String get _appointmentCode =>
      (widget.appointment['appointmentCode'] ?? _appointmentId).toString();

  @override
  void initState() {
    super.initState();
    _loadConfirmation();
  }

  Future<void> _loadConfirmation() async {
    try {
      final conf = await widget.api.getAppointmentConfirmation(
        _appointmentCode.isNotEmpty ? _appointmentCode : _appointmentId,
      );
      if (!mounted) return;
      setState(() {
        _confirmation = conf;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _handleCancel() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận hủy lịch hẹn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Bạn muốn hủy lịch hẹn $_appointmentCode?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Lý do hủy lịch',
                hintText: 'Nhập lý do thay đổi kế hoạch...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy lịch hẹn'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _submitting = true);
    try {
      await widget.api.updateAppointment(_appointmentId, {
        'status': 'Cancelled',
        'notes': reasonCtrl.text.trim().isEmpty
            ? 'Bệnh nhân chủ động hủy lịch trên ứng dụng di động'
            : reasonCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy lịch hẹn thành công.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _handleReschedule() async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RescheduleAppointmentSheet(
        api: widget.api,
        appointmentId: _appointmentId,
        currentDoctorId: (widget.appointment['doctorId'] ?? '').toString(),
      ),
    );
    if (updated == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (widget.appointment['status'] ?? 'Confirmed').toString();
    final lowerStatus = status.toLowerCase().replaceAll('_', '');
    final canModify =
        lowerStatus == 'confirmed' ||
        lowerStatus == 'pending' ||
        lowerStatus == 'scheduled' ||
        lowerStatus == 'rescheduled';

    final pkg =
        (_confirmation?['packageName'] ??
                widget.appointment['testPackageName'] ??
                widget.appointment['packageName'] ??
                'Khám & Xét nghiệm máu')
            .toString();
    final doctor =
        (_confirmation?['doctorName'] ??
                widget.appointment['doctorName'] ??
                'Bác sĩ chuyên khoa')
            .toString();
    final location =
        (_confirmation?['location'] ??
                widget.appointment['roomName'] ??
                widget.appointment['roomId'] ??
                'Khu khám lâm sàng BMS')
            .toString();
    final dateFormatted =
        (_confirmation?['dateFormatted'] ??
                BmsFormatters.date(
                  widget.appointment['appointmentDate'] ??
                      widget.appointment['appointmentTime'],
                ))
            .toString();
    final timeFormatted =
        (_confirmation?['timeFormatted'] ??
                widget.appointment['slotTime'] ??
                '')
            .toString();
    final fasting = (_confirmation?['fastingInstructions'] ?? '').toString();
    final qrData = (_confirmation?['qrCodeData'] ?? _appointmentCode)
        .toString();
    final queueNum = widget.appointment['queueNumber'];

    return DraggableScrollableSheet(
      initialChildSize: 0.84,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollCtrl) {
        return ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chi tiết phiếu hẹn',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                BmsStatusPill(status: status),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const BmsLoadingState(message: 'Đang tải mã QR xác nhận...')
            else
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: qrData.isEmpty ? _appointmentCode : qrData,
                        version: QrVersions.auto,
                        size: 170,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _appointmentCode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            BmsSoftCard(
              backgroundColor: AppColors.surfaceSoft,
              child: Column(
                children: [
                  BmsInfoRow(
                    label: 'Gói xét nghiệm',
                    value: pkg,
                    isBold: true,
                  ),
                  BmsInfoRow(label: 'Bác sĩ phụ trách', value: doctor),
                  BmsInfoRow(
                    label: 'Ngày & khung giờ',
                    value:
                        '$dateFormatted${timeFormatted.isNotEmpty ? ' · $timeFormatted' : ''}',
                  ),
                  BmsInfoRow(label: 'Địa điểm / Phòng', value: location),
                  if (queueNum != null)
                    BmsInfoRow(
                      label: 'Số thứ tự khám',
                      value: 'Q-${queueNum.toString().padLeft(3, '0')}',
                      isBold: true,
                      valueColor: AppColors.successText,
                    ),
                ],
              ),
            ),
            if (fasting.isNotEmpty) ...[
              const SizedBox(height: 12),
              BmsSoftCard(
                backgroundColor: AppColors.warningLight,
                borderColor: AppColors.warningBorder,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.restaurant_outlined,
                      size: 18,
                      color: AppColors.warningText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fasting,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.warningText,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (canModify) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting ? null : _handleCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.dangerBorder),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Hủy lịch hẹn'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _handleReschedule,
                      icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                      label: const Text('Đổi lịch hẹn'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RescheduleAppointmentSheet extends StatefulWidget {
  final PatientPortalApi api;
  final String appointmentId;
  final String currentDoctorId;

  const _RescheduleAppointmentSheet({
    required this.api,
    required this.appointmentId,
    required this.currentDoctorId,
  });

  @override
  State<_RescheduleAppointmentSheet> createState() =>
      _RescheduleAppointmentSheetState();
}

class _RescheduleAppointmentSheetState
    extends State<_RescheduleAppointmentSheet> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  List<Map<String, dynamic>> _doctors = [];
  String? _doctorId;
  List<Map<String, dynamic>> _slots = [];
  String? _slotTime;
  final TextEditingController _reasonCtrl = TextEditingController();

  bool _loadingDoctors = true;
  bool _loadingSlots = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _loadingDoctors = true;
      _slots = [];
      _slotTime = null;
    });
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final docs = await widget.api.getAvailableDoctors(dateStr);
    if (!mounted) return;
    String? nextDocId;
    if (docs.any((d) => d['doctorId']?.toString() == widget.currentDoctorId)) {
      nextDocId = widget.currentDoctorId;
    } else if (docs.isNotEmpty) {
      nextDocId = docs.first['doctorId']?.toString();
    }
    setState(() {
      _doctors = docs;
      _doctorId = nextDocId;
      _loadingDoctors = false;
    });
    if (nextDocId != null && nextDocId.isNotEmpty) {
      _loadSlots(nextDocId);
    }
  }

  Future<void> _loadSlots(String doctorId) async {
    setState(() {
      _loadingSlots = true;
      _slotTime = null;
    });
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final slots = await widget.api.getAvailableSlots(
      doctorId: doctorId,
      date: dateStr,
    );
    if (!mounted) return;
    setState(() {
      _slots = slots;
      _loadingSlots = false;
    });
  }

  Future<void> _submit() async {
    if (_doctorId == null || _slotTime == null) return;
    setState(() => _saving = true);
    try {
      await widget.api.updateAppointment(widget.appointmentId, {
        'doctorId': _doctorId,
        'appointmentDate': _selectedDate.toUtc().toIso8601String(),
        'slotTime': _slotTime,
        'reasonForRescheduling': _reasonCtrl.text.trim().isEmpty
            ? 'Đổi lịch khám từ ứng dụng bệnh nhân'
            : _reasonCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật khung giờ lịch hẹn mới.'),
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
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Đổi lịch hẹn khám',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 45)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                  _loadDoctors();
                }
              },
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(
                'Ngày khám mới: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingDoctors)
              const BmsLoadingState(message: 'Đang tải danh sách bác sĩ...')
            else
              DropdownButtonFormField<String>(
                initialValue: _doctorId,
                decoration: const InputDecoration(labelText: 'Bác sĩ phụ trách'),
                items: _doctors.map((d) {
                  final id = (d['doctorId'] ?? d['id'] ?? '').toString();
                  final name =
                      (d['doctorName'] ?? d['fullName'] ?? 'Bác sĩ').toString();
                  return DropdownMenuItem(value: id, child: Text(name));
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _doctorId = v);
                    _loadSlots(v);
                  }
                },
              ),
            const SizedBox(height: 12),
            if (_loadingSlots)
              const BmsLoadingState(message: 'Đang tải khung giờ trống...')
            else if (_slots.isEmpty)
              const Text(
                'Không có khung giờ trống trong ngày này.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _slots.map((s) {
                  final time =
                      (s['slotTime'] ?? s['startTime'] ?? '').toString();
                  final available = s['isAvailable'] != false;
                  final selected = _slotTime == time;
                  return ChoiceChip(
                    label: Text(time),
                    selected: selected,
                    onSelected: available
                        ? (_) => setState(() => _slotTime = time)
                        : null,
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Ghi chú đổi lịch',
                hintText: 'Lý do dời lịch hẹn (tùy chọn)',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: (_saving || _doctorId == null || _slotTime == null)
                  ? null
                  : _submit,
              child: Text(_saving ? 'Đang lưu...' : 'Xác nhận đổi lịch'),
            ),
          ],
        ),
      ),
    );
  }
}
