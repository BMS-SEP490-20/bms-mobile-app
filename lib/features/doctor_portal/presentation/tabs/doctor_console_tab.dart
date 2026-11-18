import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../../data/doctor_portal_api.dart';

/// Tab 2 — Live Consultation Room Console & Smart Queue Control for Doctor Role.
class DoctorConsoleTab extends StatefulWidget {
  final void Function(String patientId, int subTab) onOpenClinicalWork;

  const DoctorConsoleTab({super.key, required this.onOpenClinicalWork});

  @override
  State<DoctorConsoleTab> createState() => _DoctorConsoleTabState();
}

class _DoctorConsoleTabState extends State<DoctorConsoleTab> {
  final DoctorPortalApi _api = const DoctorPortalApi();

  List<Map<String, dynamic>> _rooms = [];
  String _selectedRoomId = 'ROOM-101';
  Map<String, dynamic>? _currentServing;
  List<Map<String, dynamic>> _waitingList = [];
  int _waitingCount = 0;
  int _inProgressCount = 0;
  bool _loading = true;
  bool _busyAction = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initConsole();
  }

  Future<void> _initConsole() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rooms = await _api.getConsultationRooms();
      if (!mounted) return;
      if (rooms.isNotEmpty) {
        final firstId = (rooms.first['id'] ?? rooms.first['code'] ?? 'ROOM-101')
            .toString();
        _rooms = rooms;
        if (!rooms.any((r) => (r['id'] ?? r['code']).toString() == _selectedRoomId)) {
          _selectedRoomId = firstId;
        }
      }
      await _refreshQueue();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('BmsApiException: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _refreshQueue() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getRoomQueueStatus(
        roomId: _selectedRoomId,
        doctorId: BmsAuth.currentUserId,
      );
      if (!mounted) return;

      final payload = res['data'] is Map
          ? Map<String, dynamic>.from(res['data'] as Map)
          : res;

      final serving = payload['currentServing'] is Map
          ? Map<String, dynamic>.from(payload['currentServing'] as Map)
          : null;
      final waiting = payload['waitingList'] is List
          ? (payload['waitingList'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _currentServing = serving;
        _waitingList = waiting;
        _waitingCount =
            int.tryParse((payload['waitingCount'] ?? waiting.length).toString()) ??
            waiting.length;
        _inProgressCount = int.tryParse(
              (payload['inProgressCount'] ?? (serving != null ? 1 : 0))
                  .toString(),
            ) ??
            (serving != null ? 1 : 0);
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

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.textPrimary,
      ),
    );
  }

  Future<void> _handleCallNext() async {
    setState(() => _busyAction = true);
    try {
      final res = await _api.callNextPatient(
        roomId: _selectedRoomId,
        doctorId: BmsAuth.currentUserId,
      );
      final msg = (res['message'] ?? 'Đã gọi bệnh nhân kế tiếp vào phòng khám.')
          .toString();
      _showSnack(msg);
      await _refreshQueue();
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('BmsApiException: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _handleRecall(String appointmentId) async {
    setState(() => _busyAction = true);
    try {
      final msg = await _api.recallPatient(
        appointmentId: appointmentId,
        roomId: _selectedRoomId,
      );
      _showSnack(msg);
      await _refreshQueue();
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('BmsApiException: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _handleSkip(String appointmentId) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đánh dấu vắng mặt / Bỏ qua'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Ghi chú lý do (tùy chọn)',
            hintText: 'Gọi loa 3 lần không phản hồi...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Đóng'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận bỏ qua'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyAction = true);
    try {
      final msg = await _api.skipPatient(
        appointmentId: appointmentId,
        reason: reasonCtrl.text,
      );
      _showSnack(msg);
      await _refreshQueue();
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('BmsApiException: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _handleComplete(String appointmentId) async {
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hoàn tất lượt khám bệnh'),
        content: TextField(
          controller: notesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Ghi chú kết thúc lượt khám',
            hintText: 'Đã tư vấn kết quả & chỉ định xét nghiệm...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hoàn tất khám'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyAction = true);
    try {
      final msg = await _api.completeConsultation(
        appointmentId: appointmentId,
        notes: notesCtrl.text,
      );
      _showSnack(msg);
      await _refreshQueue();
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('BmsApiException: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refreshQueue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          BmsPageHeaderCard(
            icon: Icons.meeting_room_rounded,
            badgeText: 'Điều phối phòng khám',
            title: 'Bàn khám lâm sàng',
            subtitle: 'Gọi số tự động, tiếp nhận bệnh nhân & liên thông bệnh án',
            trailing: IconButton(
              onPressed: _busyAction ? null : _refreshQueue,
              tooltip: 'Làm mới hàng đợi',
              icon: const Icon(Icons.refresh_rounded),
            ),
            bottom: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedRoomId,
                  decoration: const InputDecoration(
                    labelText: 'Phòng khám đang trực',
                    prefixIcon: Icon(Icons.door_front_door_outlined, size: 20),
                  ),
                  items: _rooms.map((r) {
                    final id = (r['id'] ?? r['code'] ?? 'ROOM-101').toString();
                    final name = (r['name'] ?? id).toString();
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text('$name ($id)'),
                    );
                  }).toList(),
                  onChanged: _busyAction
                      ? null
                      : (val) {
                          if (val == null || val == _selectedRoomId) return;
                          setState(() => _selectedRoomId = val);
                          _refreshQueue();
                        },
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busyAction ? null : _handleCallNext,
                  icon: _busyAction
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.campaign_rounded, size: 20),
                  label: const Text('Gọi bệnh nhân tiếp theo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          BmsKpiGrid(
            cards: [
              BmsKpiCard(
                label: 'Đang chờ trước phòng',
                value: '$_waitingCount',
                subtitle: 'Bệnh nhân đã check-in',
                icon: Icons.hourglass_top_rounded,
                accentColor: AppColors.warning,
              ),
              BmsKpiCard(
                label: 'Đang khám tại bàn',
                value: '$_inProgressCount',
                subtitle: _selectedRoomId,
                icon: Icons.medical_information_outlined,
                accentColor: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const BmsLoadingState(message: 'Đang tải danh sách hàng đợi phòng khám...')
          else if (_error != null)
            BmsErrorState(message: _error!, onRetry: _refreshQueue)
          else ...[
            const BmsSectionHeader(
              title: 'Bệnh nhân đang khám',
              subtitle: 'Lượt phục vụ hiện tại tại bàn khám',
            ),
            const SizedBox(height: 10),
            if (_currentServing == null)
              const BmsEmptyState(
                icon: Icons.person_search_rounded,
                title: 'Chưa có bệnh nhân đang khám',
                subtitle:
                    'Nhấn "Gọi bệnh nhân tiếp theo" để mời bệnh nhân đầu hàng đợi vào phòng.',
              )
            else
              _buildServingCard(_currentServing!),
            const SizedBox(height: 20),
            BmsSectionHeader(
              title: 'Danh sách chờ khám (${_waitingList.length})',
              subtitle: 'Thứ tự ưu tiên bệnh nhân đã check-in',
            ),
            const SizedBox(height: 10),
            if (_waitingList.isEmpty)
              const BmsEmptyState(
                icon: Icons.inbox_outlined,
                title: 'Hàng đợi phòng khám đang trống',
                subtitle: 'Bệnh nhân mới check-in tại quầy Lễ tân sẽ tự động xuất hiện.',
              )
            else
              ..._waitingList.map(_buildWaitingItem),
          ],
        ],
      ),
    );
  }

  Widget _buildServingCard(Map<String, dynamic> serving) {
    final appointmentId = (serving['appointmentId'] ?? serving['id'] ?? '')
        .toString();
    final appointmentCode = (serving['appointmentCode'] ?? '').toString();
    final queueNum = (serving['queueNumberFormatted'] ??
            (serving['queueNumber'] != null
                ? 'Q-${serving['queueNumber'].toString().padLeft(3, '0')}'
                : 'Đang khám'))
        .toString();
    final patientId = (serving['patientId'] ?? '').toString();
    final patientName = (serving['patientName'] ?? 'Bệnh nhân').toString();
    final patientPhone = (serving['patientPhone'] ?? '').toString();
    final recallCount = int.tryParse((serving['recallCount'] ?? '0').toString()) ?? 0;

    return BmsSoftCard(
      borderColor: AppColors.primary.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  queueNum,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  patientName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const BmsStatusPill(status: 'InProgress'),
            ],
          ),
          const SizedBox(height: 12),
          if (appointmentCode.isNotEmpty)
            BmsInfoRow(label: 'Mã lịch hẹn', value: appointmentCode, isMono: true),
          if (patientPhone.isNotEmpty)
            BmsInfoRow(label: 'Số điện thoại', value: patientPhone),
          BmsInfoRow(label: 'Số lần gọi loa', value: '$recallCount / 3 lần'),
          const Divider(height: 22),
          if (patientId.isNotEmpty) ...[
            const Text(
              'Tác vụ lâm sàng nhanh',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => widget.onOpenClinicalWork(patientId, 0),
                  icon: const Icon(Icons.folder_shared_outlined, size: 17),
                  label: const Text('Mở EMR'),
                ),
                OutlinedButton.icon(
                  onPressed: () => widget.onOpenClinicalWork(patientId, 1),
                  icon: const Icon(Icons.assignment_outlined, size: 17),
                  label: const Text('Chẩn đoán ICD-10'),
                ),
                OutlinedButton.icon(
                  onPressed: () => widget.onOpenClinicalWork(patientId, 2),
                  icon: const Icon(Icons.biotech_outlined, size: 17),
                  label: const Text('Chỉ định XN'),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busyAction || appointmentId.isEmpty
                      ? null
                      : () => _handleRecall(appointmentId),
                  icon: const Icon(Icons.volume_up_outlined, size: 17),
                  label: const Text('Gọi lại'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.dangerText,
                    side: const BorderSide(color: AppColors.dangerBorder),
                  ),
                  onPressed: _busyAction || appointmentId.isEmpty
                      ? null
                      : () => _handleSkip(appointmentId),
                  icon: const Icon(Icons.person_off_outlined, size: 17),
                  label: const Text('Vắng mặt'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: _busyAction || appointmentId.isEmpty
                  ? null
                  : () => _handleComplete(appointmentId),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Hoàn tất khám'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingItem(Map<String, dynamic> item) {
    final queueNum = (item['queueNumberFormatted'] ??
            (item['queueNumber'] != null
                ? 'Q-${item['queueNumber'].toString().padLeft(3, '0')}'
                : 'Chờ'))
        .toString();
    final patientName = (item['patientName'] ?? 'Bệnh nhân').toString();
    final patientId = (item['patientId'] ?? '').toString();
    final code = (item['appointmentCode'] ?? '').toString();
    final createdAt = BmsFormatters.time(item['createdAt']);

    return BmsSoftCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: patientId.isNotEmpty
          ? () => widget.onOpenClinicalWork(patientId, 0)
          : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Text(
              queueNum,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  code.isNotEmpty
                      ? '$code · Check-in lúc $createdAt'
                      : 'Check-in lúc $createdAt',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const BmsStatusPill(status: 'CheckedIn'),
        ],
      ),
    );
  }
}
