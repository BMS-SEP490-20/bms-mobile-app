import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../data/staff_portal_api.dart';
import '../widgets/staff_account_tab.dart';
import '../widgets/staff_iot_monitor_tab.dart';
import '../widgets/staff_personal_shifts_tab.dart';

/// Lightweight 4-Tab Mobile Monitoring Shell for Manager (RoleId = 6):
/// 0: Tổng quan KPI / Doanh thu / TAT
/// 1: Giám sát IoT (có quyền Acknowledge cảnh báo)
/// 2: Lịch trực & Phản hồi KH (chỉ xem)
/// 3: Tài khoản & Đổi mật khẩu
class ManagerMobileShell extends StatefulWidget {
  const ManagerMobileShell({super.key});

  @override
  State<ManagerMobileShell> createState() => _ManagerMobileShellState();
}

class _ManagerMobileShellState extends State<ManagerMobileShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      _ManagerOverviewTab(),
      StaffIotMonitorTab(canAcknowledge: true),
      _ManagerShiftsAndFeedbackTab(),
      StaffAccountTab(
        webWorkstationNote:
            'Các nghiệp vụ quản lý chuyên sâu như duyệt KQ kỹ thuật, kiểm soát Westgard IQC, phân ca trực, hóa đơn và tồn kho vật tư vui lòng thao tác trên BMS Web Workstation (máy tính).',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics_rounded),
              label: 'Tổng quan',
            ),
            NavigationDestination(
              icon: Icon(Icons.sensors_outlined),
              selectedIcon: Icon(Icons.sensors_rounded),
              label: 'IoT Lab',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_view_week_outlined),
              selectedIcon: Icon(Icons.calendar_view_week_rounded),
              label: 'Lịch & ĐG',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagerOverviewTab extends StatefulWidget {
  const _ManagerOverviewTab();

  @override
  State<_ManagerOverviewTab> createState() => _ManagerOverviewTabState();
}

class _ManagerOverviewTabState extends State<_ManagerOverviewTab> {
  final StaffPortalApi _api = const StaffPortalApi();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _revenue = {};
  Map<String, dynamic> _tat = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final from = DateFormat('yyyy-MM-dd').format(
        now.subtract(const Duration(days: 30)),
      );
      final to = DateFormat('yyyy-MM-dd').format(now);
      final res = await Future.wait([
        _api.getManagerStats(),
        _api.getRevenueSummary(fromDate: from, toDate: to),
        _api.getTatSummary(fromDate: from, toDate: to),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = res[0];
        _revenue = res[1];
        _tat = res[2];
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

  num _num(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v;
      final parsed = num.tryParse(v?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  Map<String, dynamic> _mapAt(Map<String, dynamic> m, String key) {
    final v = m[key];
    return v is Map ? Map<String, dynamic>.from(v) : const {};
  }

  @override
  Widget build(BuildContext context) {
    final revSummary = _mapAt(_revenue, 'summary').isNotEmpty
        ? _mapAt(_revenue, 'summary')
        : _revenue;
    final tatSummary = _mapAt(_tat, 'summary').isNotEmpty
        ? _mapAt(_tat, 'summary')
        : _tat;
    final managerData = _mapAt(_stats, 'managerData').isNotEmpty
        ? _mapAt(_stats, 'managerData')
        : _stats;

    final totalRevenue = _num(revSummary, [
      'netRevenue',
      'grossRevenue',
      'totalRevenue',
      'totalAmount',
    ]);
    final todayRevenue = _num(managerData, ['revenueToday']);
    final displayRevenue = totalRevenue > 0 ? totalRevenue : todayRevenue;

    final avgTat = _num(tatSummary, [
      'averageTatMinutes',
      'avgTatMinutes',
      'meanTatMinutes',
    ]);
    final fallbackTat = _num(managerData, ['averageTatMinutes']);
    final displayTat = avgTat > 0 ? avgTat : fallbackTat;

    final slaPct = _num(tatSummary, [
      'targetComplianceRate',
      'slaComplianceRate',
      'onTimeRate',
      'slaRate',
    ]);

    final orders30d = _num(revSummary, ['totalOrdersCount']);
    final todayOrders = _num(managerData, [
      'totalOrdersToday',
      'todayAppointments',
      'appointmentsToday',
      'totalAppointments',
    ]);
    final displayOrders = orders30d > 0 ? orders30d : todayOrders;

    final completedTests = _num(tatSummary, ['totalCompletedTests']);
    final pendingTests = _num(tatSummary, ['totalPendingTests']);
    var totalSamples = completedTests + pendingTests;
    if (totalSamples == 0 && _stats['summaryCards'] is List) {
      for (final c in (_stats['summaryCards'] as List).whereType<Map>()) {
        if (c['key']?.toString() == 'samples') {
          totalSamples = num.tryParse(c['value']?.toString() ?? '') ?? 0;
          break;
        }
      }
    }
    if (totalSamples == 0) {
      totalSamples = _num(managerData, [
        'todaySamples',
        'totalSamplesToday',
        'pendingSamples',
        'totalOrdersToday',
      ]);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const BmsPageHeaderCard(
            icon: Icons.analytics_outlined,
            badgeText: 'QUẢN LÝ PHÒNG LAB • GIÁM SÁT NHANH',
            title: 'Tổng quan vận hành',
            subtitle: 'Chỉ số KPI 30 ngày gần nhất về doanh thu, TAT và mẫu xét nghiệm',
          ),
          const SizedBox(height: 14),
          if (_loading)
            const BmsLoadingState(message: 'Đang tổng hợp chỉ số điều hành...')
          else if (_error != null)
            BmsErrorState(message: _error!, onRetry: _load)
          else ...[
            BmsKpiGrid(
              cards: [
                BmsKpiCard(
                  label: 'Doanh thu 30 ngày',
                  value: BmsFormatters.currency(displayRevenue),
                  subtitle: todayRevenue > 0
                      ? 'Hôm nay: ${BmsFormatters.currency(todayRevenue)}'
                      : null,
                  icon: Icons.payments_outlined,
                  accentColor: AppColors.success,
                ),
                BmsKpiCard(
                  label: 'TAT trung bình',
                  value: displayTat > 0
                      ? '${displayTat.toStringAsFixed(1)} phút'
                      : '—',
                  subtitle: slaPct > 0
                      ? 'Đạt SLA: ${slaPct.toStringAsFixed(1)}%'
                      : 'Chuẩn phòng Lab',
                  icon: Icons.timer_outlined,
                  accentColor: AppColors.primary,
                ),
                BmsKpiCard(
                  label: 'Đơn / Lịch hẹn',
                  value: '${displayOrders.toInt()}',
                  subtitle: 'Hôm nay: ${todayOrders.toInt()} đơn',
                  icon: Icons.calendar_month_outlined,
                  accentColor: AppColors.teal,
                ),
                BmsKpiCard(
                  label: 'Mẫu / Đơn XN',
                  value: '${totalSamples.toInt()}',
                  subtitle: (completedTests + pendingTests) > 0
                      ? 'Xong: ${completedTests.toInt()} • Chờ: ${pendingTests.toInt()}'
                      : null,
                  icon: Icons.biotech_outlined,
                  accentColor: const Color(0xFF7C3AED),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const BmsSoftCard(
              padding: EdgeInsets.all(14),
              backgroundColor: AppColors.surfaceSoft,
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 19,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Màn hình di động tối ưu cho theo dõi chỉ số nhanh & cảnh báo IoT khi không ở máy tính. Xuất báo cáo chi tiết và phê duyệt chuyên môn trên BMS Web Workstation.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ManagerShiftsAndFeedbackTab extends StatefulWidget {
  const _ManagerShiftsAndFeedbackTab();

  @override
  State<_ManagerShiftsAndFeedbackTab> createState() =>
      _ManagerShiftsAndFeedbackTabState();
}

class _ManagerShiftsAndFeedbackTabState
    extends State<_ManagerShiftsAndFeedbackTab> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: BmsSegmentedTabs(
            tabs: const ['Lịch trực toàn viện', 'Phản hồi KH'],
            selectedIndex: _segment,
            onChanged: (i) => setState(() => _segment = i),
          ),
        ),
        Expanded(
          child: _segment == 0
              ? const StaffPersonalShiftsTab(showAllStaffFilter: true)
              : const _ManagerFeedbackReadOnlyView(),
        ),
      ],
    );
  }
}

class _ManagerFeedbackReadOnlyView extends StatefulWidget {
  const _ManagerFeedbackReadOnlyView();

  @override
  State<_ManagerFeedbackReadOnlyView> createState() =>
      _ManagerFeedbackReadOnlyViewState();
}

class _ManagerFeedbackReadOnlyViewState
    extends State<_ManagerFeedbackReadOnlyView> {
  final StaffPortalApi _api = const StaffPortalApi();
  bool _loading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        _api.getFeedbackStatistics(),
        _api.getRecentFeedbacks(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = res[0] as Map<String, dynamic>;
        _items = (res[1] as List<Map<String, dynamic>>).take(20).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avg = ((_stats['averageRating'] ?? 0) as num).toDouble();
    final total = ((_stats['totalFeedbacks'] ?? _items.length) as num).toInt();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BmsKpiGrid(
            cards: [
              BmsKpiCard(
                label: 'Điểm hài lòng TB',
                value: avg > 0 ? '${avg.toStringAsFixed(1)} ★' : '—',
                icon: Icons.star_rounded,
                accentColor: AppColors.warning,
              ),
              BmsKpiCard(
                label: 'Tổng đánh giá',
                value: '$total',
                icon: Icons.reviews_outlined,
                accentColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const BmsLoadingState(message: 'Đang tải đánh giá khách hàng...')
          else if (_items.isEmpty)
            const BmsEmptyState(
              icon: Icons.reviews_outlined,
              title: 'Chưa có phản hồi khách hàng',
            )
          else
            ..._items.map((fb) {
              final stars = (fb['rating'] as num?)?.toInt() ?? 5;
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
                            (fb['servicePackageName'] ??
                                    fb['serviceCategory'] ??
                                    'Dịch vụ')
                                .toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Text(
                          '★' * stars,
                          style: const TextStyle(color: AppColors.warning),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (fb['title'] ?? '').toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      (fb['comment'] ?? '').toString(),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
