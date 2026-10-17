import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../models/dashboard_stats_model.dart';
import '../../../auth/presentation/screens/change_password_screen.dart';

/// Adaptive multi-role operational dashboard screen (UC12).
/// Renders specialized medical KPIs and operational cards tailored for:
/// - Patient: Appointments, lab results, turnaround estimates.
/// - Doctor: Assigned patient queues, pending result approvals.
/// - LabUser: Specimen run queues, in-process tests, STAT alerts.
/// - Receptionist: Daily check-in volumes, collection queues, cashier metrics.
/// - Manager: Lab turnaround time (TAT), daily revenue, IoT refrigerator telemetry.
class RoleDashboardScreen extends StatefulWidget {
  final String initialRole;

  const RoleDashboardScreen({
    super.key,
    this.initialRole = 'Patient',
  });

  @override
  State<RoleDashboardScreen> createState() => _RoleDashboardScreenState();
}

class _RoleDashboardScreenState extends State<RoleDashboardScreen> {
  late String _selectedRole;
  bool _isLoading = false;
  DashboardStatsModel? _stats;

  final List<Map<String, String>> _roles = [
    {'key': 'Patient', 'label': 'Bệnh Nhân', 'icon': 'person'},
    {'key': 'Doctor', 'label': 'Bác Sĩ', 'icon': 'medical_services'},
    {'key': 'LabUser', 'label': 'Kỹ Thuật Viên', 'icon': 'biotech'},
    {'key': 'Receptionist', 'label': 'Lễ Tân', 'icon': 'desk'},
    {'key': 'Manager', 'label': 'Quản Lý', 'icon': 'admin_panel_settings'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    setState(() => _isLoading = true);
    try {
      final json = await ApiClient.getDashboardStats(_selectedRole);
      setState(() {
        _stats = DashboardStatsModel.fromJson(json);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Color _getColorFromVariant(String variant) {
    switch (variant.toLowerCase()) {
      case 'success':
        return AppColors.success;
      case 'warning':
        return AppColors.warning;
      case 'danger':
        return AppColors.danger;
      case 'info':
        return const Color(0xFF0284C7);
      case 'primary':
      default:
        return AppColors.primary;
    }
  }

  IconData _getIconFromKey(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'calendar_today':
      case 'event':
        return Icons.calendar_today_outlined;
      case 'fact_check':
        return Icons.fact_check_outlined;
      case 'task_alt':
      case 'check_circle':
        return Icons.check_circle_outline;
      case 'hourglass_top':
        return Icons.hourglass_top_outlined;
      case 'biotech':
        return Icons.biotech_outlined;
      case 'emergency':
        return Icons.emergency_outlined;
      case 'how_to_reg':
        return Icons.how_to_reg_outlined;
      case 'people':
        return Icons.people_outline;
      case 'payments':
      case 'attach_money':
        return Icons.payments_outlined;
      case 'receipt_long':
        return Icons.receipt_long_outlined;
      case 'timer':
        return Icons.timer_outlined;
      case 'thermostat':
        return Icons.thermostat_outlined;
      case 'assignment_turned_in':
        return Icons.assignment_turned_in_outlined;
      case 'sync':
        return Icons.sync_outlined;
      default:
        return Icons.analytics_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'BMS Dashboard (UC12)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _fetchDashboardStats,
          ),
          IconButton(
            tooltip: 'Đổi mật khẩu (UC07)',
            icon: const Icon(Icons.lock_reset, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Profile Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: AppColors.primary, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _stats?.userName ?? 'Võ Gia Huy',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Vai trò đang xem: ${_roles.firstWhere((r) => r['key'] == _selectedRole)['label']}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Role Switcher Chips
              const Text(
                'Chuyển đổi vai trò kiểm thử (Multi-Role):',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _roles.map((r) {
                    final isSelected = r['key'] == _selectedRole;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(r['label']!),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        onSelected: (val) {
                          if (val && _selectedRole != r['key']) {
                            setState(() => _selectedRole = r['key']!);
                            _fetchDashboardStats();
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // KPI Metric Cards Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chỉ Số Hoạt Động (KPI Cards)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (_stats != null && _stats!.summaryCards.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: _stats!.summaryCards.length,
                  itemBuilder: (context, index) {
                    final card = _stats!.summaryCards[index];
                    final cardColor = _getColorFromVariant(card.colorVariant);
                    final iconData = _getIconFromKey(card.icon);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardColor.withValues(alpha: 0.35), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: cardColor.withValues(alpha: 0.12),
                                child: Icon(iconData, color: cardColor, size: 20),
                              ),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.value,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: cardColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                card.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (card.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  card.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
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

              const SizedBox(height: 24),

              // Quick Actions Card
              Card(
                elevation: 0,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thao Tác Nhanh',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE0F2FE),
                          child: Icon(Icons.lock_reset, color: AppColors.primary),
                        ),
                        title: const Text('Đổi mật khẩu tài khoản (UC07)'),
                        subtitle: const Text('Cập nhật mật khẩu bảo vệ tài khoản'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                          child: const Icon(Icons.logout, color: AppColors.danger),
                        ),
                        title: const Text('Đăng xuất phiên làm việc (UC06)'),
                        subtitle: const Text('Xóa token và trở về màn hình đăng nhập'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
