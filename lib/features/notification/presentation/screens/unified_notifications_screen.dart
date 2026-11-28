import 'package:flutter/material.dart';
import '../../../../core/network/bms_http_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../../../patient/presentation/screens/export_test_result_screen.dart';
import '../../../patient_portal/data/patient_portal_api.dart';

/// Unified Notification Center for Patient, Doctor, and Receptionist roles.
/// For Patients: merges Test Result Notifications (`/api/notifications/test-results/patient/{patientId}`),
/// Appointment Reminders (`/api/notifications/appointments`), and System Inbox (`/api/v1/notifications/user/{userId}`).
/// For Staff: loads `/api/v1/notifications/user/{userId}` with mark-read and mark-all-read support.
class PatientNotificationsScreen extends StatefulWidget {
  final String? patientId;

  const PatientNotificationsScreen({super.key, this.patientId});

  @override
  State<PatientNotificationsScreen> createState() =>
      _PatientNotificationsScreenState();
}

class _PatientNotificationsScreenState
    extends State<PatientNotificationsScreen> {
  final PatientPortalApi _patientApi = const PatientPortalApi();
  final BmsHttpClient _http = const BmsHttpClient();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!BmsAuth.isLoggedIn) {
      setState(() {
        _loading = false;
        _items = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (BmsAuth.isPatient) {
        var resolvedPatId = widget.patientId ?? '';
        if (resolvedPatId.isEmpty) {
          final med = await _patientApi.getMedicalProfile();
          resolvedPatId = (med?['id'] ?? BmsAuth.currentUserId).toString();
        }
        final combined = await _patientApi.getCombinedNotifications(
          patientId: resolvedPatId,
        );
        if (!mounted) return;
        setState(() {
          _items = combined;
          _loading = false;
        });
      } else {
        final userId = BmsAuth.currentUserId;
        final res = await _http.get(
          '/api/v1/notifications/user/${Uri.encodeComponent(userId)}',
        );
        final list = <Map<String, dynamic>>[];
        if (res.isSuccess) {
          final raw = res.data;
          final rawItems = raw is Map
              ? (raw['items'] ?? raw['Items'] ?? raw['data'])
              : raw;
          if (rawItems is List) {
            for (final item in rawItems.whereType<Map>()) {
              final m = Map<String, dynamic>.from(item);
              list.add({
                'id': (m['id'] ?? m['notificationId'] ?? '').toString(),
                'source': 'user',
                'title': (m['title'] ?? 'Thông báo hệ thống').toString(),
                'message': (m['message'] ?? m['body'] ?? '').toString(),
                'createdAt':
                    (m['createdAt'] ?? m['dispatchedAt'] ?? m['sentAt'] ?? '')
                        .toString(),
                'isRead':
                    m['isRead'] == true ||
                    m['readAt'] != null ||
                    (m['status'] ?? '').toString().toUpperCase() == 'READ',
                'isPanic':
                    (m['priority'] ?? '').toString().toLowerCase() ==
                    'critical',
                'raw': m,
              });
            }
          }
        }
        if (!mounted) return;
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    switch (_filter) {
      case 'unread':
        return _items.where((e) => e['isRead'] != true).toList();
      case 'test_result':
        return _items.where((e) => e['source'] == 'test_result').toList();
      case 'appointment':
        return _items.where((e) => e['source'] == 'appointment').toList();
      default:
        return _items;
    }
  }

  int get _unreadCount => _items.where((e) => e['isRead'] != true).length;

  Future<void> _markItemRead(Map<String, dynamic> item) async {
    if (item['isRead'] == true) return;
    final id = (item['id'] ?? '').toString();
    final source = (item['source'] ?? 'user').toString();
    setState(() => item['isRead'] = true);
    try {
      await _patientApi.markNotificationRead(id: id, source: source);
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    final userId = BmsAuth.currentUserId;
    for (final item in _items) {
      if (item['isRead'] != true && item['source'] != 'user') {
        await _patientApi.markNotificationRead(
          id: (item['id'] ?? '').toString(),
          source: (item['source'] ?? 'user').toString(),
        );
      }
    }
    if (userId.isNotEmpty) {
      await _patientApi.markAllUserNotificationsRead(userId);
    }
    if (!mounted) return;
    setState(() {
      for (final item in _items) {
        item['isRead'] = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã đánh dấu toàn bộ thông báo là đã đọc.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  IconData _iconForSource(String source, bool isPanic) {
    if (isPanic) return Icons.warning_amber_rounded;
    switch (source) {
      case 'test_result':
        return Icons.biotech_rounded;
      case 'appointment':
        return Icons.event_available_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  String _labelForSource(String source) {
    switch (source) {
      case 'test_result':
        return 'Kết quả XN';
      case 'appointment':
        return 'Lịch hẹn';
      default:
        return 'Hệ thống';
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filteredItems;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trung tâm thông báo'),
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Đọc tất cả'),
            ),
          IconButton(
            onPressed: _loadNotifications,
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: BmsSearchFilterBar(
              filterChips: [
                BmsFilterChipItem(
                  key: 'all',
                  label: 'Tất cả (${_items.length})',
                  selected: _filter == 'all',
                  onSelected: () => setState(() => _filter = 'all'),
                ),
                BmsFilterChipItem(
                  key: 'unread',
                  label: 'Chưa đọc ($_unreadCount)',
                  selected: _filter == 'unread',
                  onSelected: () => setState(() => _filter = 'unread'),
                ),
                if (BmsAuth.isPatient) ...[
                  BmsFilterChipItem(
                    key: 'test_result',
                    label: 'Kết quả xét nghiệm',
                    selected: _filter == 'test_result',
                    onSelected: () => setState(() => _filter = 'test_result'),
                  ),
                  BmsFilterChipItem(
                    key: 'appointment',
                    label: 'Lịch hẹn',
                    selected: _filter == 'appointment',
                    onSelected: () => setState(() => _filter = 'appointment'),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const BmsLoadingState(message: 'Đang tải thông báo...')
                : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: BmsErrorState(
                        message: _error!,
                        onRetry: _loadNotifications,
                      ),
                    ),
                  )
                : visible.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: BmsEmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'Chưa có thông báo nào',
                        subtitle:
                            'Các cập nhật về lịch hẹn, kết quả xét nghiệm và nhắc nhở sẽ hiển thị tại đây.',
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadNotifications,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final item = visible[idx];
                        final isUnread = item['isRead'] != true;
                        final isPanic = item['isPanic'] == true;
                        final source = (item['source'] ?? 'user').toString();
                        final orderId = (item['orderId'] ?? '').toString();

                        return BmsSoftCard(
                          backgroundColor: isPanic
                              ? AppColors.dangerLight
                              : AppColors.surface,
                          borderColor: isPanic
                              ? AppColors.dangerBorder
                              : (isUnread
                                    ? AppColors.primaryBorder
                                    : AppColors.cardBorder),
                          onTap: () async {
                            await _markItemRead(item);
                            if (!context.mounted) return;
                            if (orderId.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ExportTestResultScreen(orderId: orderId),
                                ),
                              );
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isPanic
                                          ? AppColors.danger.withValues(
                                              alpha: 0.14,
                                            )
                                          : AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _iconForSource(source, isPanic),
                                      color: isPanic
                                          ? AppColors.danger
                                          : AppColors.primary,
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (item['title'] ?? 'Thông báo')
                                              .toString(),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isUnread
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            color: isPanic
                                                ? AppColors.dangerText
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_labelForSource(source)} · ${BmsFormatters.dateTime(item['createdAt'])}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isUnread)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              if ((item['message'] ?? '')
                                  .toString()
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  item['message'].toString(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              if (orderId.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      _markItemRead(item);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ExportTestResultScreen(
                                                orderId: orderId,
                                              ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.description_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Xem phiếu kết quả'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
