import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../notification/presentation/screens/unified_notifications_screen.dart';
import '../../../scanQRcheckin/qr_checkin_scanner_screen.dart';
import '../../data/reception_portal_api.dart';

/// Tab 1 — Reception Dashboard, Instant QR Check-in & Today's Appointments.
class ReceptionCheckInTab extends StatefulWidget {
  final VoidCallback onOpenQueueTab;
  final VoidCallback onOpenWalkInTab;

  const ReceptionCheckInTab({
    super.key,
    required this.onOpenQueueTab,
    required this.onOpenWalkInTab,
  });

  @override
  State<ReceptionCheckInTab> createState() => _ReceptionCheckInTabState();
}

class _ReceptionCheckInTabState extends State<ReceptionCheckInTab> {
  final ReceptionPortalApi _api = const ReceptionPortalApi();
  final TextEditingController _manualCodeCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _todayAppointments = [];
  String _statusFilter = '';
  bool _loading = true;
  bool _checkingIn = false;
  String? _error;

  static const List<({String key, String label})> _filters = [
    (key: '', label: 'Tất cả'),
    (key: 'Confirmed', label: 'Chờ đến'),
    (key: 'CheckedIn', label: 'Đã check-in'),
    (key: 'Completed', label: 'Hoàn thành'),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _manualCodeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final todayIso = BmsFormatters.isoDate(DateTime.now());
      final res = await Future.wait([
        _api.getDashboardStats(),
        _api.getAppointments(
          fromDate: todayIso,
          toDate: todayIso,
          keyword: _searchCtrl.text,
          status: _statusFilter.isEmpty ? null : _statusFilter,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = res[0] as Map<String, dynamic>;
        _todayAppointments = res[1] as List<Map<String, dynamic>>;
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

  int _readInt(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  num _readNum(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
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

  Future<void> _lookupManualCode() async {
    final code = _manualCodeCtrl.text.trim();
    if (code.isEmpty) {
      _showSnack('Vui lòng nhập mã lịch hẹn (APT-...).', isError: true);
      return;
    }

    setState(() => _checkingIn = true);
    try {
      final apt = await _api.getAppointmentByCodeOrId(code);
      if (!mounted) return;
      setState(() => _checkingIn = false);
      await _confirmAndCheckIn(apt);
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingIn = false);
      _showSnack(
        e.toString().replaceFirst('BmsApiException: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _confirmAndCheckIn(Map<String, dynamic> apt) async {
    final id = (apt['id'] ?? '').toString();
    final code = (apt['appointmentCode'] ?? id).toString();
    final patientId = (apt['patientId'] ?? '').toString();
    final patientName = (apt['patientName'] ?? 'Bệnh nhân').toString();
    final pkgName = (apt['packageName'] ?? 'Xét nghiệm máu').toString();
    final status = (apt['status'] ?? 'Confirmed').toString();

    if (status.toLowerCase() == 'checkedin') {
      _showSnack('Lịch hẹn $code đã được check-in trước đó.');
      return;
    }

    bool issueQueue = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Check-in lịch hẹn $code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bệnh nhân: $patientName',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text('Dịch vụ: $pkgName'),
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppColors.primary,
                value: issueQueue,
                title: const Text('Cấp số thứ tự lấy mẫu ngay'),
                onChanged: (v) => setDlgState(() => issueQueue = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận Check-in'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || id.isEmpty) return;

    setState(() => _checkingIn = true);
    try {
      await _api.checkInAppointment(id);
      String? ticketNo;
      if (issueQueue) {
        try {
          final ticket = await _api.issueQueueTicket(
            patientId: patientId.isEmpty ? null : patientId,
            patientName: patientName,
            packageName: pkgName,
            isWalkIn: false,
            priority: 'Routine',
          );
          ticketNo = ticket['ticketNumber']?.toString();
        } catch (_) {}
      }
      _manualCodeCtrl.clear();
      _showSnack(
        ticketNo != null && ticketNo.isNotEmpty
            ? 'Đã check-in $code · Đã cấp số: $ticketNo'
            : 'Đã xác nhận check-in $code thành công.',
      );
      await _loadData();
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('BmsApiException: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recData = _stats['receptionistData'] is Map
        ? Map<String, dynamic>.from(_stats['receptionistData'] as Map)
        : <String, dynamic>{};

    final checkInsToday = _readInt(recData, 'checkInsToday');
    final waitingQueue = _readInt(recData, 'waitingQueueCount');
    final totalWalkIns = _readInt(recData, 'totalWalkIns');
    final paymentsToday = _readNum(recData, 'paymentsCollectedToday');

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          BmsPageHeaderCard(
            icon: Icons.support_agent_rounded,
            badgeText: 'Quầy tiếp đón bệnh nhân',
            title: 'Tiếp đón & Quét QR',
            subtitle: 'Check-in nhanh mã QR, cấp số thứ tự và quản lý lịch hẹn trong ngày',
            trailing: IconButton(
              tooltip: 'Thông báo',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PatientNotificationsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(height: 14),
          BmsKpiGrid(
            cards: [
              BmsKpiCard(
                label: 'Đã check-in hôm nay',
                value: '$checkInsToday',
                subtitle: 'Lượt đến quầy',
                icon: Icons.how_to_reg_rounded,
                accentColor: AppColors.primary,
              ),
              BmsKpiCard(
                label: 'Đang chờ lấy mẫu',
                value: '$waitingQueue',
                subtitle: 'Phiếu chờ hàng đợi',
                icon: Icons.people_alt_outlined,
                accentColor: AppColors.warning,
                onTap: widget.onOpenQueueTab,
              ),
              BmsKpiCard(
                label: 'Khách vãng lai',
                value: '$totalWalkIns',
                subtitle: 'Đăng ký trực tiếp',
                icon: Icons.person_add_alt_1_outlined,
                accentColor: AppColors.teal,
                onTap: widget.onOpenWalkInTab,
              ),
              BmsKpiCard(
                label: 'Thu phí trong ngày',
                value: BmsFormatters.currency(paymentsToday),
                subtitle: 'Tổng doanh thu quầy',
                icon: Icons.payments_outlined,
                accentColor: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 16),
          BmsSoftCard(
            borderColor: AppColors.primary.withValues(alpha: 0.3),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Quét QR Check-in một chạm',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Quét mã QR từ điện thoại bệnh nhân hoặc nhập mã lịch hẹn thủ công.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const QrCheckinScannerScreen(),
                      ),
                    );
                    if (changed == true) _loadData();
                  },
                  icon: const Icon(Icons.camera_alt_outlined, size: 19),
                  label: const Text('Mở Camera Quét QR'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualCodeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        onSubmitted: (_) => _lookupManualCode(),
                        decoration: const InputDecoration(
                          hintText: 'Nhập mã lịch hẹn thủ công (APT-...)',
                          prefixIcon: Icon(Icons.tag_rounded, size: 19),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _checkingIn ? null : _lookupManualCode,
                      child: Text(_checkingIn ? 'Đang tra...' : 'Check-in'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          BmsSectionHeader(
            title: 'Lịch hẹn trong ngày (${_todayAppointments.length})',
            subtitle: 'Danh sách bệnh nhân dự kiến đến khám hôm nay',
            trailing: IconButton(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          BmsSearchFilterBar(
            controller: _searchCtrl,
            hintText: 'Tìm tên bệnh nhân, SĐT hoặc mã lịch hẹn...',
            onSubmitted: (_) => _loadData(),
            onClear: _loadData,
            filterChips: _filters.map((f) {
              return BmsFilterChipItem(
                key: f.key,
                label: f.label,
                selected: _statusFilter == f.key,
                onSelected: () {
                  setState(() => _statusFilter = f.key);
                  _loadData();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const BmsLoadingState(message: 'Đang tải danh sách lịch hẹn hôm nay...')
          else if (_error != null)
            BmsErrorState(message: _error!, onRetry: _loadData)
          else if (_todayAppointments.isEmpty)
            const BmsEmptyState(
              icon: Icons.event_available_outlined,
              title: 'Không có lịch hẹn phù hợp hôm nay',
              subtitle: 'Khách đến trực tiếp có thể tiếp nhận tại mục Khách vãng lai.',
            )
          else
            ..._todayAppointments.map((apt) {
              final code = (apt['appointmentCode'] ?? apt['id'] ?? '—')
                  .toString();
              final name = (apt['patientName'] ?? 'Bệnh nhân').toString();
              final phone = (apt['patientPhone'] ?? apt['guestPhone'] ?? '')
                  .toString();
              final slot = (apt['slotTime'] ??
                      BmsFormatters.time(apt['appointmentTime']))
                  .toString();
              final pkg = (apt['packageName'] ?? 'Xét nghiệm lâm sàng').toString();
              final status = (apt['status'] ?? 'Confirmed').toString();
              final lower = status.toLowerCase();
              final canCheckIn = lower == 'confirmed' ||
                  lower == 'pending' ||
                  lower == 'scheduled' ||
                  lower == 'rescheduled';

              return BmsSoftCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
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
                      '$code · Giờ hẹn: $slot${phone.isNotEmpty ? ' · SĐT: $phone' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pkg,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (canCheckIn) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonalIcon(
                          onPressed: _checkingIn
                              ? null
                              : () => _confirmAndCheckIn(apt),
                          icon: const Icon(Icons.how_to_reg_rounded, size: 17),
                          label: const Text('Check-in'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
