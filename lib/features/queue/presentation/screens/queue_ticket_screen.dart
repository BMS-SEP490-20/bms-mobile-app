import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../data/queue_repository.dart';
import '../../domain/queue_model.dart';

/// Live Queue Board & Ticket Issuance Screen in Vietnamese Soft Healthcare SaaS design.
class QueueTicketScreen extends StatefulWidget {
  final QueueRepository? repository;

  const QueueTicketScreen({super.key, this.repository});

  @override
  State<QueueTicketScreen> createState() => _QueueTicketScreenState();
}

class _QueueTicketScreenState extends State<QueueTicketScreen> {
  late final QueueRepository _repo;
  QueueBoardModel? _board;
  bool _isLoading = true;
  bool _isIssuing = false;
  String? _myTicketNumber;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? QueueRepository();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _repo.fetchLiveQueue();
      if (!mounted) return;
      setState(() {
        _board = QueueBoardModel.fromJson(res);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _board = null;
        _isLoading = false;
        _error = 'Không thể kết nối bảng hàng đợi trực tuyến.';
      });
    }
  }

  Future<void> _issueTicket() async {
    setState(() => _isIssuing = true);
    try {
      final ticket = await _repo.issueTicket(
        patientName: 'Khách tiếp đón tại quầy',
        packageName: 'Lấy mẫu xét nghiệm máu',
      );
      if (!mounted) return;
      final data = ticket['data'] is Map
          ? Map<String, dynamic>.from(ticket['data'] as Map)
          : ticket;
      setState(() {
        _myTicketNumber = (data['ticketNumber'] ?? '').toString();
        _isIssuing = false;
      });
      await _loadQueue();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isIssuing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Không thể cấp số thứ tự mới. Vui lòng thử lại.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = _board?.currentQueue ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hàng đợi lấy mẫu'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loadQueue,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadQueue,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BmsPageHeaderCard(
              icon: Icons.confirmation_number_rounded,
              badgeText: 'Xếp hàng tự động',
              title: 'Bảng gọi số thứ tự',
              subtitle: 'Theo dõi lượt gọi lấy mẫu xét nghiệm theo thời gian thực',
              bottom: FilledButton.icon(
                onPressed: _isIssuing ? null : _issueTicket,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: Text(
                  _isIssuing ? 'Đang cấp số...' : 'Nhận phiếu thứ tự mới',
                ),
              ),
            ),
            if (_myTicketNumber != null) ...[
              const SizedBox(height: 12),
              BmsSoftCard(
                backgroundColor: AppColors.successLight,
                borderColor: AppColors.successBorder,
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Số thứ tự vừa cấp của bạn: $_myTicketNumber',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.successText,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (_isLoading)
              const BmsLoadingState(message: 'Đang tải danh sách hàng đợi...')
            else if (_error != null)
              BmsErrorState(message: _error!, onRetry: _loadQueue)
            else if (queue.isEmpty)
              const BmsEmptyState(
                icon: Icons.people_outline_rounded,
                title: 'Hiện không có lượt chờ trong hàng đợi',
                subtitle: 'Bệnh nhân có thể nhận số và vào quầy lấy mẫu ngay.',
              )
            else
              ...queue.map((item) {
                return BmsSoftCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.ticketNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.patientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              item.packageName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      BmsStatusPill(status: item.status),
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
