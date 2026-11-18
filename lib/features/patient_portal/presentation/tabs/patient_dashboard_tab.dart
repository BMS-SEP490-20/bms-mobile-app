import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../../../appointment/presentation/book_appointment_screen.dart';
import '../../../catalog/presentation/screens/service_catalog_screen.dart';
import '../../../notification/presentation/screens/unified_notifications_screen.dart';
import '../../data/patient_portal_api.dart';

/// Tab 1 of PatientShellScreen — Patient Clinical Overview & Instant QR Check-in.
class PatientDashboardTab extends StatefulWidget {
  final void Function(int tabIndex, {int? subTabIndex}) onNavigateTab;

  const PatientDashboardTab({super.key, required this.onNavigateTab});

  @override
  State<PatientDashboardTab> createState() => _PatientDashboardTabState();
}

class _PatientDashboardTabState extends State<PatientDashboardTab> {
  final PatientPortalApi _api = const PatientPortalApi();

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _medicalProfile;
  bool _medicalProfileMissing = false;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _trackings = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _api.getUserProfile(),
        _api.getMedicalProfile(),
        _api.getDashboardStats(),
        _api.getAppointments(page: 1, pageSize: 20),
        _api.getInvoices(page: 1, pageSize: 10),
      ]);

      final userProf = results[0] as Map<String, dynamic>?;
      final medProf = results[1] as Map<String, dynamic>?;
      final stats = results[2] as Map<String, dynamic>;
      final appts = results[3] as List<Map<String, dynamic>>;
      final invs = results[4] as List<Map<String, dynamic>>;

      final patId = (medProf?['id'] ?? BmsAuth.currentUserId).toString();
      List<Map<String, dynamic>> trackings = [];
      int unread = 0;
      if (patId.isNotEmpty) {
        final extra = await Future.wait<dynamic>([
          _api.getPatientTrackings(patId),
          _api.getUnreadResultNotificationCount(patId),
        ]);
        trackings = extra[0] as List<Map<String, dynamic>>;
        unread = extra[1] as int;
      }

      if (!mounted) return;
      setState(() {
        _userProfile = userProf;
        _medicalProfile = medProf;
        _medicalProfileMissing =
            medProf == null || medProf['isProfileComplete'] == false;
        _stats = stats;
        _appointments = appts;
        _invoices = invs;
        _trackings = trackings;
        _unreadCount = unread;
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

  Map<String, dynamic>? get _nextAppointment {
    final activeStatuses = {'confirmed', 'pending', 'scheduled', 'checkedin', 'checked_in', 'inprogress'};
    final candidates = _appointments.where((a) {
      final st = (a['status'] ?? '').toString().toLowerCase();
      return activeStatuses.contains(st);
    }).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final da = DateTime.tryParse(
        (a['appointmentDate'] ?? a['appointmentTime'] ?? '').toString(),
      );
      final db = DateTime.tryParse(
        (b['appointmentDate'] ?? b['appointmentTime'] ?? '').toString(),
      );
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    });
    return candidates.first;
  }

  int _statInt(String cardKey, int fallback) {
    final cards = _stats['summaryCards'];
    if (cards is List) {
      for (final item in cards.whereType<Map>()) {
        if ((item['key'] ?? '').toString().toLowerCase().contains(cardKey)) {
          final parsed = int.tryParse((item['value'] ?? '').toString());
          if (parsed != null) return parsed;
        }
      }
    }
    return fallback;
  }

  Future<void> _showQrCheckInModal(Map<String, dynamic> appointment) async {
    final idOrCode =
        (appointment['appointmentCode'] ??
                appointment['appointmentId'] ??
                appointment['id'] ??
                '')
            .toString();
    if (idOrCode.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AppointmentQrModal(
        api: _api,
        appointmentIdOrCode: idOrCode,
        fallbackAppointment: appointment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const BmsLoadingState(message: 'Đang đồng bộ dữ liệu sức khỏe...');
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: BmsErrorState(message: _error!, onRetry: _loadAll),
        ),
      );
    }

    final displayName =
        (_medicalProfile?['fullName'] ??
                _userProfile?['fullName'] ??
                BmsAuth.currentUserName)
            .toString();
    final patientCode =
        (_medicalProfile?['patientCode'] ??
                _userProfile?['patientCode'] ??
                'Chưa cấp mã')
            .toString();
    final bloodType =
        (_medicalProfile?['bloodType'] ?? _userProfile?['bloodType'] ?? '')
            .toString()
            .trim();

    final upcomingCount = _appointments.where((a) {
      final s = (a['status'] ?? '').toString().toLowerCase();
      return s == 'confirmed' || s == 'pending' || s == 'checkedin' || s == 'checked_in';
    }).length;
    final unpaidInvoicesCount = _invoices
        .where((i) => (i['status'] ?? '').toString().toLowerCase() == 'unpaid')
        .length;
    final activeSamplesCount = _trackings
        .where((t) => t['isCompleted'] != true && t['isRejected'] != true)
        .length;
    final readyResultsCount = _statInt('result', 0);

    final nextAppt = _nextAppointment;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          // Top Greeting Card
          BmsSoftCard(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Xin chào bệnh nhân',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayName.isEmpty ? 'Bệnh nhân BMS' : displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Mã BN: $patientCode',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (bloodType.isNotEmpty &&
                              bloodType.toLowerCase() != 'unknown')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.dangerLight,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Nhóm máu $bloodType',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.dangerText,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Thông báo',
                  onPressed: () async {
                    final patId =
                        (_medicalProfile?['id'] ?? BmsAuth.currentUserId)
                            .toString();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PatientNotificationsScreen(patientId: patId),
                      ),
                    );
                    _loadAll();
                  },
                  icon: Badge(
                    isLabelVisible: _unreadCount > 0,
                    label: Text('$_unreadCount'),
                    backgroundColor: AppColors.danger,
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.textPrimary,
                      size: 25,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_medicalProfileMissing) ...[
            const SizedBox(height: 12),
            BmsSoftCard(
              backgroundColor: AppColors.warningLight,
              borderColor: AppColors.warningBorder,
              child: Row(
                children: [
                  const Icon(
                    Icons.assignment_ind_outlined,
                    color: AppColors.warningText,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hoàn thiện hồ sơ y tế lâm sàng',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warningText,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Cập nhật nhóm máu, số CCCD và người liên hệ khẩn cấp để phục vụ lấy mẫu nhanh.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warningText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.warningText,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => widget.onNavigateTab(4),
                    child: const Text('Cập nhật'),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 4 KPI Cards
          BmsKpiGrid(
            cards: [
              BmsKpiCard(
                label: 'Lịch hẹn sắp tới',
                value: '$upcomingCount',
                subtitle: upcomingCount > 0 ? 'Sẵn sàng tiếp đón' : 'Chưa có lịch hẹn',
                icon: Icons.event_available_rounded,
                accentColor: AppColors.primary,
                onTap: () => widget.onNavigateTab(1),
              ),
              BmsKpiCard(
                label: 'Kết quả sẵn sàng',
                value: '$readyResultsCount',
                subtitle: 'Đã ký duyệt chuyên môn',
                icon: Icons.fact_check_outlined,
                accentColor: AppColors.success,
                onTap: () => widget.onNavigateTab(2, subTabIndex: 0),
              ),
              BmsKpiCard(
                label: 'Mẫu đang xử lý',
                value: '$activeSamplesCount',
                subtitle: 'Theo dõi 6 công đoạn',
                icon: Icons.biotech_rounded,
                accentColor: AppColors.teal,
                onTap: () => widget.onNavigateTab(2, subTabIndex: 1),
              ),
              BmsKpiCard(
                label: 'Hóa đơn chờ thu',
                value: '$unpaidInvoicesCount',
                subtitle: unpaidInvoicesCount > 0
                    ? 'Có thể thanh toán QR'
                    : 'Đã tất toán viện phí',
                icon: Icons.receipt_long_rounded,
                accentColor: unpaidInvoicesCount > 0
                    ? AppColors.warning
                    : AppColors.success,
                onTap: () => widget.onNavigateTab(3),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Next Appointment & Instant QR Check-in Card
          BmsSectionHeader(
            title: 'Lịch hẹn & Check-in QR',
            trailing: TextButton(
              onPressed: () => widget.onNavigateTab(1),
              child: const Text('Xem tất cả'),
            ),
          ),
          const SizedBox(height: 8),
          if (nextAppt == null)
            BmsSoftCard(
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
                      Icons.calendar_month_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chưa có lịch hẹn sắp tới',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Đặt lịch trước để nhận mã QR check-in ưu tiên tại quầy.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BookAppointmentScreen(),
                        ),
                      );
                      _loadAll();
                    },
                    child: const Text('Đặt lịch'),
                  ),
                ],
              ),
            )
          else
            _buildNextAppointmentCard(nextAppt),

          const SizedBox(height: 18),

          // Active Sample Progress Card
          BmsSectionHeader(
            title: 'Tiến trình mẫu xét nghiệm',
            trailing: TextButton(
              onPressed: () => widget.onNavigateTab(2, subTabIndex: 1),
              child: const Text('Chi tiết'),
            ),
          ),
          const SizedBox(height: 8),
          if (_trackings.isEmpty)
            const BmsSoftCard(
              child: Row(
                children: [
                  Icon(
                    Icons.science_outlined,
                    color: AppColors.textSecondary,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hiện chưa có mẫu bệnh phẩm nào đang trong dây chuyền phân tích.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            _buildActiveTrackingCard(_trackings.first),

          const SizedBox(height: 18),

          // Quick Actions
          const BmsSectionHeader(title: 'Tiện ích nhanh'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.add_task_rounded,
                  label: 'Đặt lịch xét nghiệm',
                  accent: AppColors.primary,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BookAppointmentScreen(),
                      ),
                    );
                    _loadAll();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.medical_information_outlined,
                  label: 'Danh mục gói khám',
                  accent: AppColors.teal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ServiceCatalogScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.timeline_rounded,
                  label: 'Tra cứu mã mẫu',
                  accent: AppColors.success,
                  onTap: () => widget.onNavigateTab(2, subTabIndex: 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Viện phí & Biên lai',
                  accent: AppColors.warning,
                  onTap: () => widget.onNavigateTab(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextAppointmentCard(Map<String, dynamic> appt) {
    final code = (appt['appointmentCode'] ?? appt['appointmentId'] ?? '')
        .toString();
    final pkgName =
        (appt['testPackageName'] ??
                appt['packageName'] ??
                appt['packageId'] ??
                'Khám & Xét nghiệm máu')
            .toString();
    final doctorName = (appt['doctorName'] ?? 'Bác sĩ chuyên khoa').toString();
    final status = (appt['status'] ?? 'Confirmed').toString();
    final isCheckedIn =
        status.toLowerCase() == 'checkedin' ||
        status.toLowerCase() == 'checked_in';
    final queueNum = appt['queueNumber'];
    final roomName = (appt['roomName'] ?? appt['roomId'] ?? '').toString();
    final slotTime = (appt['slotTime'] ?? '').toString();
    final dateLabel = BmsFormatters.date(
      appt['appointmentDate'] ?? appt['appointmentTime'],
    );

    return BmsSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                code,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              BmsStatusPill(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pkgName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$doctorName · $dateLabel${slotTime.isNotEmpty ? ' ($slotTime)' : ''}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (isCheckedIn && (queueNum != null || roomName.isNotEmpty)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.successBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    color: AppColors.successText,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Số thứ tự: ${queueNum != null ? 'Q-${queueNum.toString().padLeft(3, '0')}' : 'Đã ghi nhận'}${roomName.isNotEmpty ? ' · $roomName' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.successText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _showQrCheckInModal(appt),
            icon: const Icon(Icons.qr_code_2_rounded, size: 20),
            label: const Text('Mở mã QR Check-in nhanh'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTrackingCard(Map<String, dynamic> track) {
    final orderNum = (track['orderNumber'] ?? '').toString();
    final barcode = (track['barcode'] ?? '').toString();
    final stepNum = ((track['currentStepNumber'] as num?)?.toInt() ?? 1).clamp(
      1,
      6,
    );
    final stepName = (track['currentStepName'] ?? 'Đã tiếp nhận').toString();
    final pkgNames = track['testPackageNames'] is List
        ? (track['testPackageNames'] as List).join(', ')
        : 'Mẫu xét nghiệm máu';

    return BmsSoftCard(
      onTap: () => widget.onNavigateTab(2, subTabIndex: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                barcode.isNotEmpty ? barcode : orderNum,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Bước $stepNum/6 · $stepName',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pkgNames,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(6, (idx) {
              final active = idx < stepNum;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: idx < 5 ? 5 : 0),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BmsSoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentQrModal extends StatefulWidget {
  final PatientPortalApi api;
  final String appointmentIdOrCode;
  final Map<String, dynamic> fallbackAppointment;

  const _AppointmentQrModal({
    required this.api,
    required this.appointmentIdOrCode,
    required this.fallbackAppointment,
  });

  @override
  State<_AppointmentQrModal> createState() => _AppointmentQrModalState();
}

class _AppointmentQrModalState extends State<_AppointmentQrModal> {
  Map<String, dynamic>? _confirmation;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await widget.api.getAppointmentConfirmation(
        widget.appointmentIdOrCode,
      );
      if (!mounted) return;
      setState(() {
        _confirmation = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code =
        (_confirmation?['appointmentCode'] ??
                widget.fallbackAppointment['appointmentCode'] ??
                widget.appointmentIdOrCode)
            .toString();
    final qrPayload =
        (_confirmation?['qrCodeData'] ?? code).toString().trim();
    final pkgName =
        (_confirmation?['packageName'] ??
                widget.fallbackAppointment['testPackageName'] ??
                widget.fallbackAppointment['packageName'] ??
                'Khám & Xét nghiệm')
            .toString();
    final fasting = (_confirmation?['fastingInstructions'] ?? '').toString();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: _loading
            ? const SizedBox(
                height: 240,
                child: BmsLoadingState(message: 'Đang tạo mã QR Check-in...'),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Mã QR Tiếp đón & Check-in',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pkgName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: QrImageView(
                      data: qrPayload.isEmpty ? code : qrPayload,
                      version: QrVersions.auto,
                      size: 190,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  if (fasting.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warningBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppColors.warningText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fasting,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.warningText,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
