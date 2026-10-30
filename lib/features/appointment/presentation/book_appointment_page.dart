import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/appointment_repository.dart';
import '../domain/appointment_models.dart';
import 'appointment_confirmation_screen.dart';

/// Medical Blue tokens from AGENTS-DESIGN.md
const Color kMedicalBlue = Color(0xFF1E40AF);
const Color kMedicalAccent = Color(0xFF0EA5E9);

/// UC21 – Book Appointment screen for Patient Mobile App.
/// Bottom sticky CTA, touch targets ≥ 44px, Medical Blue theme.
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
      if (mounted) {
        setState(() {
          _doctors = list;
          _loadingDoctors = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _doctors = [];
          _loadingDoctors = false;
          _error = e.toString();
        });
      }
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
      final res = await widget.repository.getAvailableSlots(_doctorId!, dateStr);
      if (mounted) {
        setState(() {
          _slots = res.slots;
          _loadingSlots = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _slots = [];
          _loadingSlots = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: kMedicalBlue),
          ),
          child: child!,
        );
      },
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
      if (mounted) {
        setState(() {
          _result = result;
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _SuccessView(
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
      appBar: AppBar(
        title: const Text('Đặt lịch xét nghiệm'),
        backgroundColor: kMedicalBlue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Date
          const Text('Ngày khám', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20, color: kMedicalBlue),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('dd/MM/yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Doctor
          const Text('Bác sĩ', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _doctorId,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            hint: Text(_loadingDoctors ? 'Đang tải…' : '— Chọn bác sĩ —'),
            items: _doctors
                .map(
                  (d) => DropdownMenuItem(
                    value: d.doctorId,
                    child: Text('${d.doctorName} · ${d.specialty}'),
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
          const SizedBox(height: 20),

          // Slots
          const Text('Khung giờ', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_loadingSlots)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(color: kMedicalBlue)),
            )
          else if (_slots.isEmpty && _doctorId != null)
            const Text(
              'Không có khung giờ trống. Vui lòng chọn ngày khác.',
              style: TextStyle(color: Colors.grey),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _slots.map((slot) {
                final selected = _slotTime == slot.slotTime;
                return SizedBox(
                  height: 44,
                  child: ChoiceChip(
                    label: Text(slot.slotTime),
                    selected: selected,
                    onSelected: slot.isAvailable
                        ? (_) => setState(() => _slotTime = slot.slotTime)
                        : null,
                    selectedColor: kMedicalBlue,
                    labelStyle: TextStyle(
                      color: selected
                          ? Colors.white
                          : (slot.isAvailable ? Colors.black87 : Colors.grey),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),

          // Packages
          const Text(
            'Gói xét nghiệm *',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...widget.packages.map((pkg) {
            final checked = _selectedPackages.contains(pkg.packageId);
            return CheckboxListTile(
              value: checked,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedPackages.add(pkg.packageId);
                  } else {
                    _selectedPackages.remove(pkg.packageId);
                  }
                });
              },
              title: Text(pkg.packageName),
              subtitle: Text(
                '${NumberFormat.decimalPattern('vi').format(pkg.price)} đ'
                '${pkg.description != null ? ' · ${pkg.description}' : ''}',
              ),
              activeColor: kMedicalBlue,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
          const SizedBox(height: 12),

          // Notes
          const Text('Notes (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            maxLines: 2,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Triệu chứng, yêu cầu đặc biệt…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) => _notes = v,
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
            ),
          ],
        ],
      ),
      // Sticky bottom CTA (AGENTS-DESIGN Rule 13)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: kMedicalBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Xác nhận đặt lịch',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final BookAppointmentResponse result;
  final VoidCallback onBookAnother;

  const _SuccessView({required this.result, required this.onBookAnother});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt lịch thành công'),
        backgroundColor: kMedicalBlue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 40, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Đặt lịch thành công',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kMedicalBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              result.message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Appointment code', result.appointmentCode),
                  _infoRow('Doctor', '${result.doctorName} (${result.specialty})'),
                  _infoRow(
                    'Date / time',
                    '${_formatDate(result.appointmentDate)} · ${result.slotTime}',
                  ),
                  _infoRow(
                    'Test package',
                    (result.packageId != null && result.packageId!.isNotEmpty)
                        ? result.packageId!
                        : '—',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please arrive on time with your ID. Use the appointment code at check-in.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
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
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Xem mã QR Check-in & Hướng dẫn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMedicalBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: onBookAnother,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kMedicalBlue,
                  side: const BorderSide(color: kMedicalBlue),
                ),
                child: const Text('Đặt lịch khác'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return iso;
    }
  }
}
