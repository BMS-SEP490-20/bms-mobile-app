import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bms_mobile_app/services/notification_service.dart';

/// Screen displaying past system notifications (appointment reminders, result readiness, system alerts)
/// for Patient, Doctor, and Staff roles.
class NotificationsHistoryScreen extends StatefulWidget {
  const NotificationsHistoryScreen({super.key});

  @override
  State<NotificationsHistoryScreen> createState() => _NotificationsHistoryScreenState();
}

class _NotificationsHistoryScreenState extends State<NotificationsHistoryScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;
  String _activeFilter = 'all'; // 'all', 'unread', 'result', 'appointment', 'alert'
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUserAndNotifications();
  }

  Future<void> _loadUserAndNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      _user = jsonDecode(userStr);
    }

    final userId = _user?['id']?.toString() ?? 'CURRENT_USER';
    final role = _user?['role']?.toString();

    setState(() => _loading = true);
    final result = await NotificationService.getUserNotifications(userId, role: role);

    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _notifications = result['data'] ?? [];
        }
        _loading = false;
      });
    }
  }

  Future<void> _handleMarkAsRead(String notificationId) async {
    await NotificationService.markAsRead(notificationId);
    setState(() {
      for (var item in _notifications) {
        if (item['notificationId'] == notificationId) {
          item['isRead'] = true;
        }
      }
    });
  }

  Future<void> _handleMarkAllAsRead() async {
    final userId = _user?['id']?.toString() ?? 'CURRENT_USER';
    await NotificationService.markAllAsRead(userId);
    setState(() {
      for (var item in _notifications) {
        item['isRead'] = true;
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đánh dấu tất cả thông báo là đã đọc.')),
      );
    }
  }

  List<dynamic> _getFilteredList() {
    switch (_activeFilter) {
      case 'unread':
        return _notifications.where((n) => n['isRead'] != true).toList();
      case 'checkin':
        return _notifications.where((n) => n['type'] == 'checkin_event').toList();
      case 'profile':
        return _notifications.where((n) => n['type'] == 'patient_profile_update').toList();
      case 'result':
        return _notifications.where((n) => n['type'] == 'result_ready').toList();
      case 'appointment':
        return _notifications.where((n) => n['type'] == 'appointment_reminder').toList();
      case 'receipt':
        return _notifications.where((n) => n['type'] == 'receipt_issued').toList();
      case 'sample':
        return _notifications.where((n) => n['type'] == 'sample_validated' || n['type'] == 'sample_received').toList();
      case 'alert':
        return _notifications.where((n) => n['type'] == 'system_alert').toList();
      default:
        return _notifications;
    }
  }

  int get _unreadCount => _notifications.where((n) => n['isRead'] != true).length;

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'checkin_event':
        return Icons.qr_code_scanner;
      case 'patient_profile_update':
        return Icons.manage_accounts;
      case 'sample_validated':
        return Icons.check_circle_outline;
      case 'sample_received':
        return Icons.science;
      case 'result_ready':
        return Icons.biotech;
      case 'appointment_reminder':
        return Icons.calendar_today;
      case 'receipt_issued':
        return Icons.receipt_long;
      case 'system_alert':
      default:
        return Icons.notifications_active;
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'checkin_event':
        return const Color(0xFF198754);
      case 'patient_profile_update':
        return const Color(0xFF6F42C1);
      case 'sample_validated':
        return const Color(0xFF20C997);
      case 'sample_received':
        return const Color(0xFF0D6EFD);
      case 'result_ready':
        return const Color(0xFF198754);
      case 'appointment_reminder':
        return const Color(0xFFFD7E14);
      case 'receipt_issued':
        return const Color(0xFF0DCAF0);
      case 'system_alert':
      default:
        return const Color(0xFFFFC107);
    }
  }

  String _formatTimestamp(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Vừa xong';
      if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
      if (diff.inHours < 24) return '${diff.inHours} giờ trước';
      if (diff.inDays == 1) return 'Hôm qua';
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch Sử Thông Báo', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF212529),
        elevation: 1,
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _handleMarkAllAsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Đọc tất cả', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'Tất cả (${_notifications.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('unread', 'Chưa đọc ($_unreadCount)'),
                  const SizedBox(width: 8),
                  _buildFilterChip('checkin', 'Check-in'),
                  const SizedBox(width: 8),
                  _buildFilterChip('profile', 'Hồ sơ'),
                  const SizedBox(width: 8),
                  _buildFilterChip('result', 'Kết quả'),
                  const SizedBox(width: 8),
                  _buildFilterChip('appointment', 'Lịch hẹn'),
                  const SizedBox(width: 8),
                  _buildFilterChip('receipt', 'Biên lai'),
                  const SizedBox(width: 8),
                  _buildFilterChip('alert', 'Cảnh báo'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Không có thông báo nào trong mục này',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUserAndNotifications,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = filtered[index] as Map<String, dynamic>;
                            final isUnread = item['isRead'] != true;
                            final type = item['type']?.toString();
                            final color = _getTypeColor(type);

                            return InkWell(
                              onTap: () {
                                if (isUnread) {
                                  _handleMarkAsRead(item['notificationId'].toString());
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isUnread ? const Color(0xFF0D6EFD).withValues(alpha: 0.3) : Colors.grey.shade200,
                                    width: isUnread ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(_getTypeIcon(type), color: color, size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item['title'] ?? 'Thông báo',
                                                  style: TextStyle(
                                                    fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                                    fontSize: 15,
                                                    color: isUnread ? const Color(0xFF212529) : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                _formatTimestamp(item['createdAt']?.toString()),
                                                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item['message'] ?? '',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isUnread) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF0D6EFD),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
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

  Widget _buildFilterChip(String key, String label) {
    final selected = _activeFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.grey.shade800,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: selected,
      selectedColor: const Color(0xFF0D6EFD),
      backgroundColor: const Color(0xFFF1F3F5),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (val) {
        if (val) setState(() => _activeFilter = key);
      },
    );
  }
}
