import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bms_ui_kit.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment_models.dart';
import 'appointment_confirmation_screen.dart';

/// Appointment Booking Form in Vietnamese Soft Healthcare SaaS Design.
class BookAppointmentPage extends StatefulWidget {
  final String patientId;
  final AppointmentRepository repository;
  final List<TestPackageOption> packages;
  final List<String> initialPackageIds;

  const BookAppointmentPage({
    super.key,
    required this.patientId,
    required this.repository,
    required this.packages,
    this.initialPackageIds = const [],
  });

  @override
  State<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends State<BookAppointmentPage> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  List<DoctorOption> _doctors = [];
  String? _doctorId;
  List<AvailableSlot> _slots = [];
  String? _slotTime;
  late Set<String> _selectedPackages;
  String _notes = '';

  bool _loadingDoctors = false;
  bool _loadingSlots = false;
  bool _submitting = false;
  String? _error;
  BookAppointmentResponse? _result;

  @override
  void initState() {
    super.initState();
    _selectedPackages = Set.from(widget.initialPackageIds);
    if (_selectedPackages.isEmpty && widget.packages.isNotEmpty) {
      _selectedPackages.add(widget.packages.first.packageId);
    }
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _loadingDoctors = true;
      _doctorId = null;
      _slots = [];
      _slotTime = null;
      _error = null;
    });
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final list = await widget.repository.getAvailableDoctors(dateStr);
      if (!mounted) return;
      setState(() {
        _doctors = list;
        _loadingDoctors = false;
        if (list.isNotEmpty) {
          _doctorId = list.first.doctorId;
        }
      });
      if (_doctorId != null) {
        await _loadSlots();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _doctors = [];
        _loadingDoctors = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadSlots() async {
    if (_doctorId == null) return;
    setState(() {
      _loadingSlots = true;
      _slotTime = null;
      _error = null;
    });
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final res = await widget.repository.getAvailableSlots(
        _doctorId!,
        dateStr,
      );
      if (!mounted) return;
      final firstAvailable = res.slots.where((s) => s.isAvailable);
      setState(() {
        _slots = res.slots;
        _loadingSlots = false;
        if (firstAvailable.isNotEmpty) {
          _slotTime = firstAvailable.first.slotTime;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _slots = [];
        _loadingSlots = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadDoctors();
    }
  }

  Future<void> _submit() async {
    if (_doctorId == null || _slotTime == null || _selectedPackages.isEmpty) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final request = BookAppointmentRequest(
        patientId: widget.patientId,
        doctorId: _doctorId!,
        appointmentDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
        slotTime: _slotTime!,
        packageIds: _selectedPackages.toList(),
        notes: _notes.trim().isEmpty ? null : _notes.trim(),
      );
      final result = await widget.repository.bookAppointment(request);
      if (!mounted) return;
      setState(() {
        _result = result;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _BookingSuccessView(
        result: _result!,
        onBookAnother: () {
          setState(() {
            _result = null;
            _slotTime = null;
            _notes = '';
          });
        },
      );
    }

    final canSubmit = _doctorId != null &&
        _slotTime != null &&
        _selectedPackages.isNotEmpty &&
        !_submitting;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Đặt lịch xét nghiệm')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          BmsSoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '1. Chọn ngày khám & bác sĩ tư vấn',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_rounded, size: 19),
                  label: Text(
                    'Ngày khám: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _doctorId,
                  decoration: InputDecoration(
                    labelText: _loadingDoctors
                        ? 'Đang tải lịch bác sĩ...'
                        : 'Chọn bác sĩ phụ trách',
                    prefixIcon: const Icon(Icons.medical_services_outlined),
                  ),
                  items: _doctors
                      .map(
                        (d) => DropdownMenuItem(
                          value: d.doctorId,
                          child: Text(
                            d.specialty.isNotEmpty
                                ? '${d.doctorName} · ${d.specialty}'
                                : d.doctorName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _loadingDoctors
                      ? null
                      : (v) {
                          setState(() => _doctorId = v);
                          _loadSlots();
                        },
                ),
                const SizedBox(height: 14),
                const Text(
                  '2. Chọn khung giờ lấy mẫu',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                if (_loadingSlots)
                  const BmsLoadingState(message: 'Đang kiểm tra khung giờ trống...')
                else if (_slots.isEmpty && _doctorId != null)
                  const Text(
                    'Chưa có khung giờ trống trong ngày này. Vui lòng chọn ngày khác.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _slots.map((slot) {
                      final selected = _slotTime == slot.slotTime;
                      return ChoiceChip(
                        label: Text(slot.slotTime),
                        selected: selected,
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        onSelected: slot.isAvailable
                            ? (_) => setState(() => _slotTime = slot.slotTime)
                            : null,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : (slot.isAvailable
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          BmsSoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '3. Gói xét nghiệm (${_selectedPackages.length} gói đã chọn)',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.packages.isEmpty)
                  const Text(
                    'Không có gói xét nghiệm khả dụng.',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  ...widget.packages.map((pkg) {
                    final checked = _selectedPackages.contains(pkg.packageId);
                    return CheckboxListTile(
                      value: checked,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        pkg.packageName,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${BmsFormatters.currency(pkg.price)}${pkg.description != null ? ' · ${pkg.description}' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedPackages.add(pkg.packageId);
                          } else {
                            _selectedPackages.remove(pkg.packageId);
                          }
                        });
                      },
                    );
                  }),
                const SizedBox(height: 12),
                TextField(
                  maxLines: 2,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú triệu chứng (tùy chọn)',
                    hintText: 'Nhập triệu chứng hoặc lưu ý nhịn ăn sáng...',
                  ),
                  onChanged: (v) => _notes = v,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            BmsErrorState(message: _error!),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.cardBorder)),
          ),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: canSubmit ? _submit : null,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 19),
              label: Text(
                _submitting ? 'Đang đặt lịch...' : 'Xác nhận đặt lịch hẹn',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingSuccessView extends StatelessWidget {
  final BookAppointmentResponse result;
  final VoidCallback onBookAnother;

  const _BookingSuccessView({
    required this.result,
    required this.onBookAnother,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Đặt lịch thành công')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          BmsSoftCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.successLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 36,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Đã ghi nhận lịch hẹn khám',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  result.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Divider(height: 26),
                BmsInfoRow(
                  label: 'Mã lịch hẹn',
                  value: result.appointmentCode,
                  isMono: true,
                  isBold: true,
                ),
                BmsInfoRow(
                  label: 'Bác sĩ phụ trách',
                  value: result.specialty.isNotEmpty
                      ? '${result.doctorName} (${result.specialty})'
                      : result.doctorName,
                ),
                BmsInfoRow(
                  label: 'Ngày & giờ hẹn',
                  value:
                      '${BmsFormatters.date(result.appointmentDate)} · ${result.slotTime}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Vui lòng mang theo thẻ CCCD và đưa mã QR lịch hẹn tại quầy tiếp đón trước giờ hẹn 15 phút.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AppointmentConfirmationScreen(
                      appointmentCode: result.appointmentCode,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_2_rounded, size: 20),
              label: const Text('Xem mã QR Check-in & Hướng dẫn'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: onBookAnother,
              child: const Text('Đặt thêm lịch hẹn khác'),
            ),
          ),
        ],
      ),
    );
  }
}
