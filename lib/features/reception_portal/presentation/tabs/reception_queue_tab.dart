import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../data/reception_portal_api.dart';

/// Tab 3 — Live Phlebotomy & Reception Queue Board for Receptionist Role.
class ReceptionQueueTab extends StatefulWidget {
  const ReceptionQueueTab({super.key});

  @override
  State<ReceptionQueueTab> createState() => _ReceptionQueueTabState();
}

class _ReceptionQueueTabState extends State<ReceptionQueueTab> {
  static const List<String> _counters = ['Quầy 1', 'Quầy 2', 'Quầy 3'];

  final ReceptionPortalApi _api = const ReceptionPortalApi();

  String _selectedCounter = 'Quầy 1';
  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic> _stats = {};
  String _nextNumber = '—';
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBoard();
  }

  Future<void> _loadBoard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final board = await _api.getLiveQueueBoard();
      if (!mounted) return;
      final list = board['currentQueue'] is List
          ? (board['currentQueue'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      final stats = board['stats'] is Map
          ? Map<String, dynamic>.from(board['stats'] as Map)
          : <String, dynamic>{};

      setState(() {
        _tickets = list;
        _stats = stats;
        _nextNumber = (board['nextNumber'] ?? '—').toString();
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

  Future<void> _callNext() async {
    setState(() => _busy = true);
    try {
      final called = await _api.callNextQueueTicket(_selectedCounter);
      if (called == null || called.isEmpty) {
        _showSnack('Hiện không còn phiếu chờ trong hàng đợi.');
      } else {
        final numStr = (called['ticketNumber'] ?? '').toString();
        final patName = (called['patientName'] ?? '').toString();
        _showSnack('Đã gọi số $numStr ($patName) vào $_selectedCounter.');
      }
      await _loadBoard();
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('BmsApiException: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openIssueTicketModal() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final pkgCtrl = TextEditingController(text: 'Xét nghiệm máu tổng quát');
    String priority = 'Routine';
    bool isWalkIn = true;
    bool saving = false;

    final issued = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cấp số thứ tự lấy mẫu',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Họ tên bệnh nhân *',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mã bệnh nhân (nếu có)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pkgCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nội dung xét nghiệm',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: 'Độ ưu tiên'),
                items: const [
                  DropdownMenuItem(value: 'Routine', child: Text('Thường quy')),
                  DropdownMenuItem(value: 'Urgent', child: Text('Khẩn (Urgent)')),
                  DropdownMenuItem(
                    value: 'STAT',
                    child: Text('Cấp cứu (STAT)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setSheetState(() => priority = v);
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppColors.primary,
                value: isWalkIn,
                title: const Text('Khách vãng lai trực tiếp tại quầy'),
                onChanged: (v) => setSheetState(() => isWalkIn = v ?? true),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (nameCtrl.text.trim().isEmpty) {
                          _showSnack(
                            'Vui lòng nhập họ tên bệnh nhân.',
                            isError: true,
                          );
                          return;
                        }
                        setSheetState(() => saving = true);
                        try {
                          await _api.issueQueueTicket(
                            patientName: nameCtrl.text.trim(),
                            patientCode: codeCtrl.text.trim(),
                            packageName: pkgCtrl.text.trim(),
                            isWalkIn: isWalkIn,
                            priority: priority,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          setSheetState(() => saving = false);
                          _showSnack(
                            e.toString().replaceFirst('BmsApiException: ', ''),
                            isError: true,
                          );
                        }
                      },
                child: Text(saving ? 'Đang cấp số...' : 'In & Cấp số thứ tự'),
              ),
            ],
          ),
        ),
      ),
    );

    if (issued == true) {
      _showSnack('Đã cấp số thứ tự mới thành công.');
      await _loadBoard();
    }
  }

  Future<void> _callSpecificTicket(String id) async {
    setState(() => _busy = true);
    try {
      await _api.callTicketToCounter(id, _selectedCounter);
      _showSnack('Đã phát loa mời bệnh nhân vào $_selectedCounter.');
      await _loadBoard();
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('BmsApiException: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateTicketStatus(String id, String status) async {
    setState(() => _busy = true);
    try {
      await _api.updateQueueTicketStatus(
        id,
        status: status,
        counterName: _selectedCounter,
      );
      _showSnack('Đã cập nhật trạng thái phiếu thứ tự.');
      await _loadBoard();
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('BmsApiException: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inQueue = (_stats['inQueueNow'] ?? _tickets.length).toString();
    final avgWait = (_stats['avgWaitMinutes'] ?? 0).toString();
    final servedToday = (_stats['servedToday'] ?? 0).toString();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadBoard,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          BmsPageHeaderCard(
            icon: Icons.confirmation_number_rounded,
            badgeText: 'Điều phối lấy mẫu xét nghiệm',
            title: 'Bảng hàng đợi trực tuyến',
            subtitle: 'Quản lý gọi số theo quầy, ưu tiên mẫu STAT và cập nhật lấy mẫu',
            trailing: IconButton(
              onPressed: _busy ? null : _loadBoard,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Làm mới',
            ),
            bottom: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _counters.map((c) {
                      final active = _selectedCounter == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: active,
                          showCheckmark: false,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: active ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) => setState(() => _selectedCounter = c),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _callNext,
                        icon: const Icon(Icons.campaign_rounded, size: 19),
                        label: const Text('Gọi số kế tiếp'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _openIssueTicketModal,
                      icon: const Icon(Icons.add_rounded, size: 19),
                      label: const Text('Cấp số thứ tự'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          BmsKpiGrid(
            cards: [
              BmsKpiCard(
                label: 'Đang chờ trong hàng',
                value: inQueue,
                subtitle: 'Số tiếp theo: $_nextNumber',
                icon: Icons.groups_outlined,
                accentColor: AppColors.primary,
              ),
              BmsKpiCard(
                label: 'Chờ trung bình',
                value: '$avgWait phút',
                subtitle: 'Đã phục vụ: $servedToday lượt',
                icon: Icons.timer_outlined,
                accentColor: AppColors.teal,
              ),
            ],
          ),
          const SizedBox(height: 18),
          BmsSectionHeader(
            title: 'Danh sách phiếu thứ tự (${_tickets.length})',
            subtitle: 'Thao tác nhanh tại $_selectedCounter',
          ),
          const SizedBox(height: 10),
          if (_loading)
            const BmsLoadingState(message: 'Đang đồng bộ bảng hàng đợi...')
          else if (_error != null)
            BmsErrorState(message: _error!, onRetry: _loadBoard)
          else if (_tickets.isEmpty)
            const BmsEmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'Chưa có bệnh nhân trong hàng đợi',
              subtitle: 'Nhấn "Cấp số thứ tự" để phát phiếu mới cho bệnh nhân.',
            )
          else
            ..._tickets.map((t) {
              final id = (t['id'] ?? '').toString();
              final ticketNo = (t['ticketNumber'] ?? '—').toString();
              final patName = (t['patientName'] ?? 'Bệnh nhân').toString();
              final pkg = (t['packageName'] ?? 'Lấy mẫu xét nghiệm').toString();
              final priority = (t['priority'] ?? 'Routine').toString();
              final status = (t['status'] ?? 'Waiting').toString();
              final waitMin = (t['waitTimeMinutes'] ?? 0).toString();
              final counter = (t['counterName'] ?? '').toString();

              return BmsSoftCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            ticketNo,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            patName,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (priority.toLowerCase() != 'routine') ...[
                          BmsStatusPill(status: priority),
                          const SizedBox(width: 6),
                        ],
                        BmsStatusPill(status: status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$pkg · Chờ $waitMin phút${counter.isNotEmpty ? ' · $counter' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy || id.isEmpty
                              ? null
                              : () => _callSpecificTicket(id),
                          icon: const Icon(Icons.volume_up_outlined, size: 16),
                          label: const Text('Gọi loa'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy || id.isEmpty
                              ? null
                              : () => _updateTicketStatus(id, 'Collecting'),
                          icon: const Icon(Icons.colorize_outlined, size: 16),
                          label: const Text('Đang lấy mẫu'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _busy || id.isEmpty
                              ? null
                              : () => _updateTicketStatus(id, 'Completed'),
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                          ),
                          label: const Text('Hoàn tất'),
                        ),
                        TextButton(
                          onPressed: _busy || id.isEmpty
                              ? null
                              : () => _updateTicketStatus(id, 'Skipped'),
                          child: const Text(
                            'Bỏ qua',
                            style: TextStyle(color: AppColors.dangerText),
                          ),
                        ),
                      ],
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
