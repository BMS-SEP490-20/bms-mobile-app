import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bms_ui_kit.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/models/test_package_model.dart';
import '../../patient_portal/data/patient_portal_api.dart';
import '../../patient_portal/presentation/screens/sepay_checkout_screen.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment_models.dart';

class _ShiftDef {
  final String id;
  final String name;
  final String range;
  final int startHour;
  final int endHour;
  const _ShiftDef(this.id, this.name, this.range, this.startHour, this.endHour);
}

const List<_ShiftDef> _kShifts = [
  _ShiftDef('Morning', 'Ca Sáng', '07:00 – 11:30', 7, 12),
  _ShiftDef('Afternoon', 'Ca Chiều', '13:00 – 17:00', 12, 17),
  _ShiftDef('Evening', 'Ca Tối', '17:30 – 20:30', 17, 22),
];

/// 1-to-1 Patient Appointment Booking Screen matching Web `BookAppointmentPage.jsx`:
/// - Uses crash-proof BMS Bottom-Sheet Package Picker & Doctor Radio Cards (ZERO DropdownButton assertions!)
/// - Monthly calendar grid (past dates disabled)
/// - 3 shifts (`Morning`, `Afternoon`, `Evening`) synced with doctor shifts from `GET /api/appointments/doctors`
/// - Strictly deduplicates doctors by `doctorId` per shift & shows exact Clinic Room name
/// - Available slots (`GET /api/appointments/slots`) filtering past slots on today
/// - 15-minute reservation notice -> submits `POST /api/appointments` -> redirects to `SePayCheckoutScreen`
class BookAppointmentScreen extends StatefulWidget {
  final String? initialPackageId;

  const BookAppointmentScreen({super.key, this.initialPackageId});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final CatalogRepository _catalogRepo = const CatalogRepository();
  final AppointmentRepository _apptRepo = AppointmentRepository();
  final PatientPortalApi _patientApi = const PatientPortalApi();
  final TextEditingController _notesCtrl = TextEditingController();

  bool _loadingInit = true;
  bool _loadingDoctors = false;
  bool _loadingSlots = false;
  bool _submitting = false;
  String? _error;

  String _patientId = '';
  String _patientName = '';
  List<TestPackageModel> _packages = [];
  TestPackageModel? _selectedPackage;

  late DateTime _selectedDate;
  late DateTime _calendarMonth;
  String _selectedShift = 'Morning';

  List<DoctorOption> _doctorShifts = [];
  DoctorOption? _selectedDoctor;

  List<AvailableSlot> _allSlots = [];
  String? _selectedSlot;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _calendarMonth = DateTime(now.year, now.month, 1);
    if (now.hour >= 17) {
      _selectedShift = 'Evening';
    } else if (now.hour >= 11) {
      _selectedShift = 'Afternoon';
    }
    _initData();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  String _packageKey(TestPackageModel p) =>
      p.id.trim().isNotEmpty ? p.id.trim() : p.packageCode.trim();

  /// Deduplicated doctors working in [shiftId].
  List<DoctorOption> _uniqueDoctorsForShift(String shiftId) {
    final byId = <String, DoctorOption>{};
    for (final d in _doctorShifts) {
      if (d.doctorId.isEmpty) continue;
      final matchesShift =
          d.shiftType.isEmpty ||
          d.shiftType.toLowerCase() == shiftId.toLowerCase() ||
          d.shiftType.toLowerCase() == 'fullday';
      if (matchesShift) {
        byId.putIfAbsent(d.doctorId, () => d);
      }
    }
    return byId.values.toList();
  }

  List<DoctorOption> get _visibleDoctors =>
      _uniqueDoctorsForShift(_selectedShift);

  Future<void> _initData() async {
    setState(() {
      _loadingInit = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _catalogRepo.searchTestPackages(page: 1, pageSize: 60),
        _patientApi.getMedicalProfile().catchError((_) => null),
      ]);
      if (!mounted) return;
      final catalogRes = results[0] as TestPackageSearchResponse;
      final profile = results[1] as Map<String, dynamic>?;

      _patientId =
          (profile?['patientCode'] ??
                  profile?['id'] ??
                  AppointmentRepository.currentPatientId() ??
                  '')
              .toString();
      _patientName = (profile?['fullName'] ?? '').toString();

      final uniquePkgMap = <String, TestPackageModel>{};
      for (final p in catalogRes.items) {
        final key = _packageKey(p);
        if (key.isNotEmpty) {
          uniquePkgMap.putIfAbsent(key, () => p);
        }
      }
      final uniquePackages = uniquePkgMap.values.toList();

      TestPackageModel? matched;
      if (widget.initialPackageId != null &&
          widget.initialPackageId!.trim().isNotEmpty) {
        final needle = widget.initialPackageId!.trim().toLowerCase();
        for (final p in uniquePackages) {
          if (p.id.toLowerCase() == needle ||
              p.packageCode.toLowerCase() == needle) {
            matched = p;
            break;
          }
        }
      }
      matched ??= uniquePackages.isNotEmpty ? uniquePackages.first : null;

      setState(() {
        _packages = uniquePackages;
        _selectedPackage = matched;
        _loadingInit = false;
      });
      await _loadDoctors();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingInit = false;
      });
    }
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _loadingDoctors = true;
      _doctorShifts = [];
      _selectedDoctor = null;
      _allSlots = [];
      _selectedSlot = null;
    });
    try {
      var list = await _apptRepo.getAvailableDoctors(
        _dateKey,
        specialty: _selectedPackage?.category,
      );
      if (list.isEmpty) {
        list = await _apptRepo.getAvailableDoctors(_dateKey);
      }
      if (!mounted) return;

      _doctorShifts = list;

      var shiftDocs = _uniqueDoctorsForShift(_selectedShift);
      var nextShift = _selectedShift;
      if (shiftDocs.isEmpty && list.isNotEmpty) {
        for (final sh in _kShifts) {
          final candidates = _uniqueDoctorsForShift(sh.id);
          if (candidates.isNotEmpty) {
            nextShift = sh.id;
            shiftDocs = candidates;
            break;
          }
        }
      }

      setState(() {
        _selectedShift = nextShift;
        _selectedDoctor = shiftDocs.isNotEmpty ? shiftDocs.first : null;
        _loadingDoctors = false;
      });
      if (_selectedDoctor != null) {
        await _loadSlots();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDoctors = false);
    }
  }

  Future<void> _onShiftChanged(int idx) async {
    final nextShift = _kShifts[idx].id;
    final shiftDocs = _uniqueDoctorsForShift(nextShift);
    final prevDocId = _selectedDoctor?.doctorId;
    DoctorOption? nextDoc;
    if (prevDocId != null) {
      for (final d in shiftDocs) {
        if (d.doctorId == prevDocId) {
          nextDoc = d;
          break;
        }
      }
    }
    nextDoc ??= shiftDocs.isNotEmpty ? shiftDocs.first : null;

    final doctorChanged = nextDoc?.doctorId != prevDocId;
    setState(() {
      _selectedShift = nextShift;
      _selectedDoctor = nextDoc;
      if (nextDoc == null) {
        _allSlots = [];
        _selectedSlot = null;
      } else if (!doctorChanged) {
        final avail = _visibleSlots.where((s) => s.isAvailable).toList();
        _selectedSlot = avail.isNotEmpty ? avail.first.slotTime : null;
      }
    });

    if (nextDoc != null && (doctorChanged || _allSlots.isEmpty)) {
      await _loadSlots();
    }
  }

  Future<void> _loadSlots() async {
    final doc = _selectedDoctor;
    if (doc == null) return;
    setState(() {
      _loadingSlots = true;
      _allSlots = [];
      _selectedSlot = null;
    });
    try {
      final res = await _apptRepo.getAvailableSlots(doc.doctorId, _dateKey);
      if (!mounted) return;
      setState(() {
        _allSlots = res.slots;
        _loadingSlots = false;
        final filtered = _visibleSlots;
        final firstAvail = filtered.where((s) => s.isAvailable).toList();
        _selectedSlot = firstAvail.isNotEmpty
            ? firstAvail.first.slotTime
            : null;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  List<AvailableSlot> get _visibleSlots {
    final shift = _kShifts.firstWhere((s) => s.id == _selectedShift);
    final now = DateTime.now();
    final isToday =
        _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    return _allSlots.where((slot) {
      final parts = slot.slotTime.split(':');
      if (parts.length < 2) return true;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      if (h < shift.startHour || h >= shift.endHour) return false;
      if (isToday && (h < now.hour || (h == now.hour && m <= now.minute))) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _openPackagePickerSheet() async {
    if (_packages.isEmpty) return;
    final picked = await showModalBottomSheet<TestPackageModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Chọn gói xét nghiệm',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(14),
                itemCount: _packages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final p = _packages[i];
                  final selected =
                      _selectedPackage != null &&
                      _packageKey(p) == _packageKey(_selectedPackage!);
                  return BmsSoftCard(
                    padding: const EdgeInsets.all(13),
                    backgroundColor: selected
                        ? AppColors.primaryLight
                        : AppColors.surface,
                    borderColor: selected
                        ? AppColors.primary
                        : AppColors.cardBorder,
                    onTap: () => Navigator.of(ctx).pop(p),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.packageName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${p.packageCode} • ${p.category}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          BmsFormatters.currency(p.price),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (picked != null && mounted) {
      setState(() => _selectedPackage = picked);
      _loadDoctors();
    }
  }

  Future<void> _submitBooking() async {
    if (_selectedPackage == null ||
        _selectedDoctor == null ||
        _selectedSlot == null) {
      setState(() {
        _error =
            'Vui lòng chọn đầy đủ gói xét nghiệm, bác sĩ và khung giờ khám.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final pkgId = _packageKey(_selectedPackage!);
      final resp = await _apptRepo.bookAppointment(
        BookAppointmentRequest(
          patientId: _patientId,
          doctorId: _selectedDoctor!.doctorId,
          appointmentDate: _dateKey,
          slotTime: _selectedSlot!,
          packageIds: [pkgId],
          notes: _notesCtrl.text.trim(),
          type: 'ClinicVisit',
        ),
      );
      if (!mounted) return;
      setState(() => _submitting = false);

      final apptId = resp.appointmentId.isNotEmpty
          ? resp.appointmentId
          : resp.appointmentCode;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SePayCheckoutScreen(
            appointmentId: apptId,
            appointmentCode: resp.appointmentCode,
            packageName: _selectedPackage!.packageName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleDocs = _visibleDoctors;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Đặt lịch xét nghiệm')),
      body: SafeArea(
        child: _loadingInit
            ? const BmsLoadingState(message: 'Đang tải thông tin đặt lịch...')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    BmsErrorState(message: _error!),
                    const SizedBox(height: 12),
                  ],

                  // 1. Selected Package Card (BottomSheet picker — 100% crash-proof!)
                  BmsSoftCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.science_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '1. Gói xét nghiệm đã chọn',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (_packages.length > 1)
                              TextButton(
                                onPressed: _openPackagePickerSheet,
                                child: const Text('Đổi gói'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_selectedPackage != null) ...[
                          BmsSoftCard(
                            padding: const EdgeInsets.all(12),
                            backgroundColor: AppColors.primaryLight,
                            borderColor: AppColors.primaryBorder,
                            onTap: _packages.length > 1
                                ? _openPackagePickerSheet
                                : null,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedPackage!.packageName,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_selectedPackage!.packageCode} • ${_selectedPackage!.category}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      BmsFormatters.currency(
                                        _selectedPackage!.price,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    if (_packages.length > 1)
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_selectedPackage!.requiresFasting) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.warningLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.warningBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppColors.warningText,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedPackage!.displayPreparation,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.warningText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ] else
                          const Text(
                            'Chưa có gói xét nghiệm khả dụng.',
                            style: TextStyle(color: AppColors.dangerText),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Date Picker Calendar Grid
                  BmsSoftCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '2. Chọn ngày lấy mẫu',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() {
                                _calendarMonth = DateTime(
                                  _calendarMonth.year,
                                  _calendarMonth.month - 1,
                                  1,
                                );
                              }),
                              icon: const Icon(Icons.chevron_left_rounded),
                              visualDensity: VisualDensity.compact,
                            ),
                            Text(
                              DateFormat('MM/yyyy').format(_calendarMonth),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() {
                                _calendarMonth = DateTime(
                                  _calendarMonth.year,
                                  _calendarMonth.month + 1,
                                  1,
                                );
                              }),
                              icon: const Icon(Icons.chevron_right_rounded),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildMonthGrid(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Shift, On-Duty Doctors (Radio Cards — ZERO DropdownButton!) & Slots
                  BmsSoftCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '3. Chọn ca khám, bác sĩ & khung giờ',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        BmsSegmentedTabs(
                          tabs: _kShifts.map((s) {
                            final count = _uniqueDoctorsForShift(s.id).length;
                            return count > 0 ? '${s.name} ($count)' : s.name;
                          }).toList(),
                          selectedIndex: _kShifts.indexWhere(
                            (s) => s.id == _selectedShift,
                          ),
                          onChanged: _onShiftChanged,
                        ),
                        const SizedBox(height: 12),
                        if (_loadingDoctors)
                          const BmsLoadingState(
                            message: 'Đang tìm bác sĩ trực chuyên khoa...',
                          )
                        else if (visibleDocs.isEmpty)
                          const Text(
                            'Chưa có bác sĩ trực trong ca này. Hãy chọn ca có số lượng bác sĩ hoặc đổi ngày khám.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.dangerText,
                            ),
                          )
                        else ...[
                          const Text(
                            'Bác sĩ phụ trách trực chuyên khoa',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...visibleDocs.map((doc) {
                            final isSelected =
                                _selectedDoctor?.doctorId == doc.doctorId;
                            return BmsSoftCard(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              backgroundColor: isSelected
                                  ? AppColors.primaryLight
                                  : AppColors.surfaceSoft,
                              borderColor: isSelected
                                  ? AppColors.primary
                                  : AppColors.cardBorder,
                              onTap: () {
                                setState(() => _selectedDoctor = doc);
                                _loadSlots();
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textTertiary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doc.doctorName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (doc.specialty.isNotEmpty)
                                          Text(
                                            doc.specialty,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        if (doc.roomName.isNotEmpty)
                                          Text(
                                            'Phòng: ${doc.roomName}${doc.shiftStart.isNotEmpty ? ' • ${doc.shiftStart}–${doc.shiftEnd}' : ''}',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 6),
                          const Text(
                            'Khung giờ lấy mẫu trống',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_loadingSlots)
                            const BmsLoadingState(
                              message: 'Đang tải khung giờ trống...',
                            )
                          else if (_visibleSlots.isEmpty)
                            const Text(
                              'Không còn khung giờ trống trong ca này. Hãy thử chuyển sang ca khác hoặc ngày mai.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _visibleSlots.map((slot) {
                                final active = _selectedSlot == slot.slotTime;
                                return ChoiceChip(
                                  label: Text(slot.slotTime),
                                  selected: active,
                                  showCheckmark: false,
                                  onSelected: slot.isAvailable
                                      ? (_) => setState(
                                          () => _selectedSlot = slot.slotTime,
                                        )
                                      : null,
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: active
                                        ? Colors.white
                                        : slot.isAvailable
                                        ? AppColors.textPrimary
                                        : AppColors.textDisabled,
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. Notes & 15-min hold notice
                  BmsSoftCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_patientName.isNotEmpty) ...[
                          BmsInfoRow(
                            label: 'Bệnh nhân',
                            value: _patientName,
                            isBold: true,
                          ),
                          const SizedBox(height: 8),
                        ],
                        TextField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText:
                                'Ghi chú triệu chứng / yêu cầu (tùy chọn)',
                            hintText: 'VD: Đang dùng thuốc huyết áp...',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Lịch hẹn được giữ chỗ trong 15 phút để hoàn tất thanh toán VietQR SePay.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : _submitBooking,
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                            ),
                            label: Text(
                              _submitting
                                  ? 'Đang tạo lịch hẹn...'
                                  : 'Xác nhận đặt lịch & Thanh toán SePay',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  Widget _buildMonthGrid() {
    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final first = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final lead = first.weekday - 1;
    final daysInMonth = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + 1,
      0,
    ).day;

    final cells = <DateTime?>[
      ...List.filled(lead, null),
      ...List.generate(
        daysInMonth,
        (i) => DateTime(_calendarMonth.year, _calendarMonth.month, i + 1),
      ),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        Row(
          children: weekdays
              .map(
                (w) => Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (_, idx) {
            final d = cells[idx];
            if (d == null) return const SizedBox.shrink();
            final isPast = d.isBefore(today);
            final isSelected =
                d.year == _selectedDate.year &&
                d.month == _selectedDate.month &&
                d.day == _selectedDate.day;
            return InkWell(
              onTap: isPast
                  ? null
                  : () {
                      setState(() => _selectedDate = d);
                      _loadDoctors();
                    },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : d == today
                      ? AppColors.primaryLight
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected || d == today
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : isPast
                          ? AppColors.textDisabled
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
