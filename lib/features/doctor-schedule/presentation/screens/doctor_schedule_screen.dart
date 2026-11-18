import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../data/schedule_repository.dart';
import '../../models/doctor_schedule_model.dart';

/// Department Doctor Schedule Lookup Screen (`GET /api/v1/schedules/doctors`).
class DoctorScheduleScreen extends StatefulWidget {
  final ScheduleRepository? repository;

  const DoctorScheduleScreen({super.key, this.repository});

  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  late final ScheduleRepository _repo;
  final TextEditingController _searchCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  DoctorScheduleResponse? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ScheduleRepository();
    _loadSchedule();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    if (widget.repository == null) _repo.dispose();
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dateIso = DateFormat('yyyy-MM-dd').format(_date);
      final res = await _repo.getDaySchedule(
        date: dateIso,
        search: _searchCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _data = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ScheduleException
            ? e.message
            : 'Không thể tải lịch trực bác sĩ.';
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _date = picked);
      await _loadSchedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctors = _data?.doctors ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch trực bác sĩ toàn khoa'),
        actions: [
          IconButton(
            tooltip: 'Chọn ngày xem lịch',
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadSchedule,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            BmsPageHeaderCard(
              icon: Icons.calendar_view_week_rounded,
              badgeText: 'Ngày trực: ${BmsFormatters.date(_date)}',
              title: 'Bảng phân công ca khám',
              subtitle: 'Tra cứu phòng khám, chuyên khoa và khung giờ bác sĩ trực',
              trailing: OutlinedButton(
                onPressed: _pickDate,
                child: const Text('Đổi ngày'),
              ),
            ),
            const SizedBox(height: 12),
            BmsSearchFilterBar(
              controller: _searchCtrl,
              hintText: 'Tìm tên bác sĩ hoặc chuyên khoa...',
              onSubmitted: (_) => _loadSchedule(),
              onClear: _loadSchedule,
              trailing: FilledButton(
                onPressed: _loadSchedule,
                child: const Text('Tìm'),
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const BmsLoadingState(message: 'Đang tải lịch trực bác sĩ...')
            else if (_error != null)
              BmsErrorState(message: _error!, onRetry: _loadSchedule)
            else if (doctors.isEmpty)
              const BmsEmptyState(
                icon: Icons.event_busy_outlined,
                title: 'Chưa có lịch bác sĩ trực trong ngày này',
                subtitle: 'Vui lòng chọn ngày khác để kiểm tra ca phân công.',
              )
            else
              ...doctors.map((doc) {
                return BmsSoftCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              doc.fullName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          BmsStatusPill(status: doc.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${doc.specialty}${doc.roomName.isNotEmpty ? ' · ${doc.roomName}' : ''}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (doc.slots.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: doc.slots.map((s) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: s.isAvailable
                                    ? AppColors.successLight
                                    : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: s.isAvailable
                                      ? AppColors.successBorder
                                      : AppColors.cardBorder,
                                ),
                              ),
                              child: Text(
                                '${s.startTime} - ${s.endTime}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: s.isAvailable
                                      ? AppColors.successText
                                      : AppColors.textSecondary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
