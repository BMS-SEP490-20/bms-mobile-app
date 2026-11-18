import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../../../notification/presentation/screens/unified_notifications_screen.dart';
import '../../data/doctor_portal_api.dart';

/// Tab 1 — Clinical Overview Dashboard for Doctor Role.
class DoctorDashboardTab extends StatefulWidget {
  final VoidCallback onOpenConsole;
  final void Function(String patientId, int subTab) onOpenClinicalWork;
  final VoidCallback onOpenLabLookup;

  const DoctorDashboardTab({
    super.key,
    required this.onOpenConsole,
    required this.onOpenClinicalWork,
    required this.onOpenLabLookup,
  });

  @override
  State<DoctorDashboardTab> createState() => _DoctorDashboardTabState();
}

class _DoctorDashboardTabState extends State<DoctorDashboardTab> {
  final DoctorPortalApi _api = const DoctorPortalApi();

  Map<String, dynamic> _stats = {};
  Map<String, dynamic>? _staffProfile;
  List<Map<String, dynamic>> _upcomingShifts = [];
  List<Map<String, dynamic>> _todayAppointments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = BmsAuth.currentUserId;
      final now = DateTime.now();
      final todayIso = BmsFormatters.isoDate(now);
      final weekIso = BmsFormatters.isoDate(now.add(const Duration(days: 7)));

      final results = await Future.wait([
        _api.getDashboardStats(),
        _api.getStaffProfile(),
        _api.getShifts(from: todayIso, to: weekIso, doctorId: userId),
        _api.getAppointments(
          doctorId: userId,
          fromDate: todayIso,
          toDate: todayIso,
        ),
      ]);

      if (!mounted) return;
      final stats = results[0] as Map<String, dynamic>;
      final profile = results[1] as Map<String, dynamic>?;
      final shifts = results[2] as List<Map<String, dynamic>>;
      var appointments = results[3] as List<Map<String, dynamic>>;

      final doctorData = stats['doctorData'] is Map
          ? Map<String, dynamic>.from(stats['doctorData'] as Map)
          : <String, dynamic>{};

      if (appointments.isEmpty && doctorData['todaySchedule'] is List) {
        appointments = (doctorData['todaySchedule'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      setState(() {
        _stats = stats;
        _staffProfile = profile;
        _upcomingShifts = shifts;
        _todayAppointments = appointments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('BmsApiException: ', '');
        _loading = false;
      });
    }
  }

  int _readInt(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final doctorData = _stats['doctorData'] is Map
        ? Map<String, dynamic>.from(_stats['doctorData'] as Map)
        : <String, dynamic>{};

    final todayCount = _readInt(doctorData, 'todayAppointmentsCount') > 0
        ? _readInt(doctorData, 'todayAppointmentsCount')
        : _todayAppointments.length;
    final pendingApprovals = _readInt(doctorData, 'pendingApprovalsCount');
    final reviewedToday = _readInt(doctorData, 'reviewedTodayCount');

    final doctorName = (_staffProfile?['fullName'] ??
            BmsAuth.currentUserName)
        .toString()
        .trim();
    final specialty = (_staffProfile?['specialty'] ??
            _staffProfile?['department'] ??
            'Khoa Khám Bệnh & Xét Nghiệm')
        .toString()
        .trim();
    final employeeCode = (_staffProfile?['employeeCode'] ?? '').toString().trim();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          BmsPageHeaderCard(
            icon: Icons.medical_services_rounded,
            badgeText: employeeCode.isNotEmpty
                ? 'Bác sĩ điều trị · $employeeCode'
                : 'Bác sĩ điều trị',
            title: doctorName.isEmpty
                ? 'Bàn làm việc lâm sàng'
                : (RegExp(
                    r'^(BS\.|ThS\.|TS\.|PGS\.|GS\.)',
                    caseSensitive: false,
                  ).hasMatch(doctorName)
                    ? doctorName
                    : 'BS. $doctorName'),
            subtitle: specialty,
            trailing: IconButton(
              tooltip: 'Thông báo hệ thống',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PatientNotificationsScreen(),
                  ),
                );
              },
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.textPrimary,
              ),
            ),
            bottom: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onOpenConsole,
                    icon: const Icon(Icons.meeting_room_rounded, size: 18),
                    label: const Text('Mở bàn khám trực tiếp'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: widget.onOpenLabLookup,
                  icon: const Icon(Icons.science_outlined, size: 18),
                  label: const Text('Tra cứu XN'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const BmsLoadingState(message: 'Đang đồng bộ số liệu lâm sàng...')
          else if (_error != null)
            BmsErrorState(message: _error!, onRetry: _loadData)
          else ...[
            BmsKpiGrid(
              cards: [
                BmsKpiCard(
                  label: 'Lịch khám hôm nay',
                  value: '$todayCount',
                  subtitle: 'Bệnh nhân đăng ký',
                  icon: Icons.event_available_rounded,
                  accentColor: AppColors.primary,
                  onTap: widget.onOpenConsole,
                ),
                BmsKpiCard(
                  label: 'Chờ duyệt chuyên môn',
                  value: '$pendingApprovals',
                  subtitle: 'Cần bác sĩ xem xét',
                  icon: Icons.fact_check_outlined,
                  accentColor: AppColors.warning,
                  onTap: widget.onOpenLabLookup,
                ),
                BmsKpiCard(
                  label: 'Đã duyệt trong ngày',
                  value: '$reviewedToday',
                  subtitle: 'Hoàn tất phiên trực',
                  icon: Icons.verified_outlined,
                  accentColor: AppColors.success,
                ),
                BmsKpiCard(
                  label: 'Ca trực 7 ngày tới',
                  value: '${_upcomingShifts.length}',
                  subtitle: 'Lịch phân công khoa',
                  icon: Icons.schedule_rounded,
                  accentColor: AppColors.teal,
                ),
              ],
            ),
            const SizedBox(height: 20),
            BmsSectionHeader(
              title: 'Ca trực sắp tới',
              subtitle: 'Lịch trực cá nhân trong 7 ngày tiếp theo',
              trailing: IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 19),
                tooltip: 'Làm mới',
              ),
            ),
            const SizedBox(height: 10),
            if (_upcomingShifts.isEmpty)
              const BmsEmptyState(
                icon: Icons.calendar_today_outlined,
                title: 'Chưa có ca trực trong 7 ngày tới',
                subtitle: 'Lịch phân công mới từ trưởng khoa sẽ hiển thị tại đây.',
              )
            else
              ..._upcomingShifts.take(3).map((shift) {
                final dateStr = BmsFormatters.date(
                  shift['shiftDate'] ?? shift['date'],
                );
                final shiftType = BmsFormatters.shiftTypeVi(
                  (shift['shiftType'] ?? shift['shiftName'])?.toString(),
                );
                final room = (shift['roomName'] ??
                        shift['roomId'] ??
                        shift['department'] ??
                        'Phòng khám chuyên khoa')
                    .toString();
                final status = (shift['status'] ?? 'Confirmed').toString();

                return BmsSoftCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.access_time_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$dateStr · $shiftType',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              room,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      BmsStatusPill(status: status),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 18),
            BmsSectionHeader(
              title: 'Lịch khám bệnh trong ngày',
              subtitle: 'Danh sách bệnh nhân đặt hẹn hôm nay',
              trailing: TextButton(
                onPressed: widget.onOpenConsole,
                child: const Text('Vào bàn khám'),
              ),
            ),
            const SizedBox(height: 10),
            if (_todayAppointments.isEmpty)
              const BmsEmptyState(
                icon: Icons.people_outline_rounded,
                title: 'Chưa có lịch hẹn khám hôm nay',
                subtitle:
                    'Bạn có thể mở Bàn khám để tiếp nhận bệnh nhân vừa check-in tại quầy.',
              )
            else
              ..._todayAppointments.map((apt) {
                final code = (apt['appointmentCode'] ?? apt['code'] ?? '—')
                    .toString();
                final patientName = (apt['patientName'] ??
                        apt['fullName'] ??
                        'Bệnh nhân')
                    .toString();
                final patientId = (apt['patientId'] ?? '').toString();
                final pkgName = (apt['packageName'] ??
                        (apt['packages'] is List &&
                                (apt['packages'] as List).isNotEmpty
                            ? ((apt['packages'] as List).first['name'] ?? '')
                            : 'Khám & tư vấn xét nghiệm'))
                    .toString();
                final slot = (apt['slotTime'] ??
                        BmsFormatters.time(apt['appointmentTime']))
                    .toString();
                final status = (apt['status'] ?? 'Confirmed').toString();

                return BmsSoftCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  onTap: patientId.isNotEmpty
                      ? () => widget.onOpenClinicalWork(patientId, 0)
                      : widget.onOpenConsole,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              patientName,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          BmsStatusPill(status: status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$code · Khung giờ: $slot',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (pkgName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          pkgName,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}
