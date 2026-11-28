import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../data/staff_portal_api.dart';
import '../widgets/staff_account_tab.dart';
import '../widgets/staff_iot_monitor_tab.dart';
import '../widgets/staff_personal_shifts_tab.dart';

/// Lightweight 4-Tab System Monitoring Shell for Admin (RoleId = 1) — ZERO patient PHI:
/// 0: Tổng quan hệ thống (`GET /api/dashboard/admin-ops`)
/// 1: Giám sát IoT (chỉ xem theo RBAC)
/// 2: Lịch trực toàn viện (chỉ xem 3 nhóm BS/KTV/LT)
/// 3: Tài khoản & Đổi mật khẩu
class AdminMobileShell extends StatefulWidget {
  const AdminMobileShell({super.key});

  @override
  State<AdminMobileShell> createState() => _AdminMobileShellState();
}

class _AdminMobileShellState extends State<AdminMobileShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      _AdminSystemOverviewTab(),
      StaffIotMonitorTab(canAcknowledge: false),
      StaffPersonalShiftsTab(showAllStaffFilter: true),
      StaffAccountTab(
        webWorkstationNote:
            'Các nghiệp vụ quản trị hệ thống như quản lý tài khoản IAM, phân quyền RBAC, Audit Log, Sao lưu/Khôi phục dữ liệu và Danh mục y tế vui lòng thao tác trên BMS Web Workstation (máy tính).',
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
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield_rounded),
              label: 'Hệ thống',
            ),
            NavigationDestination(
              icon: Icon(Icons.sensors_outlined),
              selectedIcon: Icon(Icons.sensors_rounded),
              label: 'IoT',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Lịch trực',
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

class _AdminSystemOverviewTab extends StatefulWidget {
  const _AdminSystemOverviewTab();

  @override
  State<_AdminSystemOverviewTab> createState() =>
      _AdminSystemOverviewTabState();
}

class _AdminSystemOverviewTabState extends State<_AdminSystemOverviewTab> {
  final StaffPortalApi _api = const StaffPortalApi();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _ops = {};

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
      final data = await _api.getAdminOpsDashboard();
      if (!mounted) return;
      setState(() {
        _ops = data;
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

  int _readInt(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v.toInt();
      final p = int.tryParse(v?.toString() ?? '');
      if (p != null) return p;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final iam = _ops['iam'] is Map
        ? Map<String, dynamic>.from(_ops['iam'] as Map)
        : _ops;
    final logins = _ops['logins'] is Map
        ? Map<String, dynamic>.from(_ops['logins'] as Map)
        : _ops;
    final iot = _ops['iotDevices'] is Map
        ? Map<String, dynamic>.from(_ops['iotDevices'] as Map)
        : (_ops['iot'] is Map
              ? Map<String, dynamic>.from(_ops['iot'] as Map)
              : _ops);
    final backup = _ops['backup'] is Map
        ? Map<String, dynamic>.from(_ops['backup'] as Map)
        : _ops;

    var totalUsers = _readInt(iam, ['totalAccounts', 'totalUsers']);
    if (totalUsers == 0 && _ops['usersPerRole'] is Map) {
      for (final v in (_ops['usersPerRole'] as Map).values) {
        if (v is num) totalUsers += v.toInt();
      }
    }
    final lockedUsers = _readInt(_ops, ['lockedAccounts', 'lockedUsers']) +
        (_ops.containsKey('lockedAccounts') || _ops.containsKey('lockedUsers')
            ? 0
            : _readInt(iam, ['lockedAccounts', 'lockedUsers']));

    final logins24h = _readInt(logins, [
      'distinctAccountsLast24h',
      'loginsLast24h',
      'recentLogins24h',
    ]);
    final logins7d = _readInt(logins, ['distinctAccountsLast7d']);

    final iotOnline = _readInt(iot, ['online', 'onlineDevices', 'onlineCount']);
    final iotOffline = _readInt(iot, ['offline']);
    final iotTotal = _readInt(iot, ['totalDevices', 'deviceCount']) > 0
        ? _readInt(iot, ['totalDevices', 'deviceCount'])
        : (iotOnline + iotOffline);
    final auditRows = _readInt(_ops, ['auditLogRows']);

    final backupStatus =
        (backup['lastStatus'] ?? backup['lastBackupStatus'] ?? 'Sẵn sàng')
            .toString();
    final backupAt =
        backup['lastCompletedAtUtc'] ??
        backup['lastCreatedAtUtc'] ??
        backup['lastBackupAt'];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const BmsPageHeaderCard(
            icon: Icons.shield_outlined,
            badgeText: 'QUẢN TRỊ HỆ THỐNG • KHÔNG PHI BỆNH NHÂN',
            title: 'Tổng quan hạ tầng BMS',
            subtitle: 'Giám sát nhanh sức khỏe hệ thống, tài khoản, IoT & sao lưu',
          ),
          const SizedBox(height: 14),
          if (_loading)
            const BmsLoadingState(message: 'Đang kiểm tra trạng thái hệ thống...')
          else if (_error != null)
            BmsErrorState(message: _error!, onRetry: _load)
          else ...[
            BmsKpiGrid(
              cards: [
                BmsKpiCard(
                  label: 'Tổng tài khoản IAM',
                  value: '$totalUsers',
                  subtitle: '$lockedUsers tài khoản đang khóa',
                  icon: Icons.people_outline_rounded,
                  accentColor: AppColors.primary,
                ),
                BmsKpiCard(
                  label: 'Đăng nhập 24h',
                  value: '$logins24h',
                  subtitle: logins7d > 0
                      ? '$logins7d tài khoản trong 7 ngày'
                      : 'Phiên xác thực thành công',
                  icon: Icons.login_rounded,
                  accentColor: AppColors.success,
                ),
                BmsKpiCard(
                  label: 'Cảm biến IoT Online',
                  value: '$iotOnline / $iotTotal',
                  subtitle: '$auditRows bản ghi Audit Log',
                  icon: Icons.sensors_rounded,
                  accentColor: AppColors.teal,
                ),
                BmsKpiCard(
                  label: 'Sao lưu CSDL',
                  value: backupStatus,
                  subtitle: backupAt != null
                      ? BmsFormatters.dateTime(backupAt)
                      : 'MongoDB BMS_Database',
                  icon: Icons.backup_outlined,
                  accentColor: AppColors.warning,
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
                    Icons.verified_user_outlined,
                    color: AppColors.primary,
                    size: 19,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tuân thủ phân tách dữ liệu lâm sàng (Decision 10): Tài khoản Quản trị chỉ giám sát hạ tầng, không truy cập hồ sơ bệnh án PHI.',
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
