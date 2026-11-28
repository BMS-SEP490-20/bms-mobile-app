import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../../data/staff_portal_api.dart';

/// Shared Weekly Shift Schedule Tab (`GET /api/shifts`):
/// - For Doctor, Lab, Receptionist: shows personal assigned shifts for Mon-Sun.
/// - For Admin & Manager (`showAllStaffFilter: true`): read-only hospital-wide shifts with 3 role group filters.
class StaffPersonalShiftsTab extends StatefulWidget {
  final bool showAllStaffFilter;
  final String? headerTitle;
  final String? headerSubtitle;

  const StaffPersonalShiftsTab({
    super.key,
    this.showAllStaffFilter = false,
    this.headerTitle,
    this.headerSubtitle,
  });

  @override
  State<StaffPersonalShiftsTab> createState() => _StaffPersonalShiftsTabState();
}

class _StaffPersonalShiftsTabState extends State<StaffPersonalShiftsTab> {
  final StaffPortalApi _api = const StaffPortalApi();

  late DateTime _weekStart;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _shifts = [];
  String _roleFilter = 'ALL'; // ALL | Doctor | Lab | Receptionist

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _weekStart = today.subtract(Duration(days: today.weekday - 1));
    _load();
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getShifts(
        fromDate: DateFormat('yyyy-MM-dd').format(_weekStart),
        toDate: DateFormat('yyyy-MM-dd').format(_weekEnd),
      );
      if (!mounted) return;
      list.sort((a, b) {
        final da = (a['shiftDate'] ?? a['date'] ?? '').toString();
        final db = (b['shiftDate'] ?? b['date'] ?? '').toString();
        final cmp = da.compareTo(db);
        if (cmp != 0) return cmp;
        return (a['shiftStart'] ?? a['startTime'] ?? '').toString().compareTo(
          (b['shiftStart'] ?? b['startTime'] ?? '').toString(),
        );
      });
      setState(() {
        _shifts = list;
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

  void _shiftWeek(int deltaDays) {
    setState(() => _weekStart = _weekStart.add(Duration(days: deltaDays)));
    _load();
  }

  List<Map<String, dynamic>> get _filteredShifts {
    if (!widget.showAllStaffFilter || _roleFilter == 'ALL') return _shifts;
    return _shifts.where((s) {
      final role =
          (s['employeeRole'] ??
                  s['staffRole'] ??
                  s['role'] ??
                  s['roleName'] ??
                  '')
              .toString()
              .toLowerCase();
      final roleId = int.tryParse((s['roleId'] ?? '').toString());
      switch (_roleFilter) {
        case 'Doctor':
          return roleId == 2 || role.contains('doctor') || role.contains('bác sĩ');
        case 'Lab':
          return roleId == 3 || role.contains('lab') || role.contains('ktv');
        case 'Receptionist':
          return roleId == 4 || role.contains('recep') || role.contains('lễ tân');
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rangeLabel =
        '${DateFormat('dd/MM').format(_weekStart)} – ${DateFormat('dd/MM/yyyy').format(_weekEnd)}';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BmsPageHeaderCard(
            icon: Icons.calendar_today_rounded,
            badgeText: widget.showAllStaffFilter
                ? 'CHỈ XEM • LỊCH TRỰC TOÀN VIỆN'
                : BmsAuth.roleLabelVi.toUpperCase(),
            title: widget.headerTitle ??
                (widget.showAllStaffFilter
                    ? 'Lịch ca trực toàn viện'
                    : 'Lịch ca trực cá nhân'),
            subtitle: widget.headerSubtitle ??
                (widget.showAllStaffFilter
                    ? 'Theo dõi phân ca Bác sĩ, KTV Lab và Lễ tân theo tuần'
                    : 'Xem lịch phân công ca trực hàng tuần của bạn'),
            bottom: Row(
              children: [
                IconButton.outlined(
                  onPressed: () => _shiftWeek(-7),
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Tuần trước',
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Text(
                    'Tuần: $rangeLabel',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton.outlined(
                  onPressed: () => _shiftWeek(7),
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Tuần sau',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          if (widget.showAllStaffFilter) ...[
            const SizedBox(height: 12),
            BmsSearchFilterBar(
              filterChips: [
                _roleChip('ALL', 'Tất cả (${_shifts.length})'),
                _roleChip('Doctor', 'Bác sĩ'),
                _roleChip('Lab', 'KTV Lab'),
                _roleChip('Receptionist', 'Lễ tân'),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (_loading)
            const BmsLoadingState(message: 'Đang tải lịch ca trực...')
          else if (_error != null)
            BmsErrorState(message: _error!, onRetry: _load)
          else if (_filteredShifts.isEmpty)
            const BmsEmptyState(
              icon: Icons.event_available_outlined,
              title: 'Không có ca trực nào trong tuần này',
              subtitle:
                  'Thử chuyển sang tuần trước hoặc tuần sau để xem lịch phân công.',
            )
          else
            ..._filteredShifts.map(_buildShiftCard),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  BmsFilterChipItem _roleChip(String key, String label) => BmsFilterChipItem(
    key: key,
    label: label,
    selected: _roleFilter == key,
    onSelected: () => setState(() => _roleFilter = key),
  );

  Widget _buildShiftCard(Map<String, dynamic> shift) {
    final shiftDate = BmsFormatters.date(
      shift['shiftDate'] ?? shift['date'] ?? shift['workDate'],
    );
    final shiftType = BmsFormatters.shiftTypeVi(
      (shift['shiftType'] ?? shift['type'] ?? '').toString(),
    );
    final start = (shift['shiftStart'] ?? shift['startTime'] ?? '').toString();
    final end = (shift['shiftEnd'] ?? shift['endTime'] ?? '').toString();
    final room = (shift['roomName'] ?? shift['roomId'] ?? shift['location'] ?? '—')
        .toString();
    final staffName =
        (shift['employeeName'] ??
                shift['staffName'] ??
                shift['doctorName'] ??
                shift['fullName'] ??
                '')
            .toString();
    final dept = (shift['department'] ?? shift['specialty'] ?? '').toString();
    final status = (shift['status'] ?? 'Approved').toString();
    final note = (shift['notes'] ?? shift['note'] ?? '').toString().trim();

    return BmsSoftCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  shiftDate,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  start.isNotEmpty && end.isNotEmpty
                      ? '$start – $end'
                      : shiftType,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              BmsStatusPill(status: status),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.showAllStaffFilter && staffName.isNotEmpty)
            BmsInfoRow(label: 'Nhân sự trực', value: staffName, isBold: true),
          BmsInfoRow(label: 'Ca trực', value: shiftType),
          BmsInfoRow(label: 'Phòng / Quầy', value: room, isBold: true),
          if (dept.isNotEmpty) BmsInfoRow(label: 'Khoa / Bộ phận', value: dept),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Ghi chú: $note',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
