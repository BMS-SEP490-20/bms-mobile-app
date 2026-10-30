import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/bms_auth.dart';
import '../../data/test_result_notification_repository.dart';
import '../../models/test_result_notification_model.dart';
import 'export_test_result_screen.dart';

/// UC60 / BR-184: Notify Test Results (Mobile Client)
/// Allows patients to receive, view, filter, and acknowledge laboratory test notifications.
/// Features emergency panic/critical value highlights, clinical action alerts, and instant lab report navigation.
class TestResultNotificationsScreen extends StatefulWidget {
  final String? patientId;

  const TestResultNotificationsScreen({
    super.key,
    this.patientId,
  });

  @override
  State<TestResultNotificationsScreen> createState() => _TestResultNotificationsScreenState();
}

class _TestResultNotificationsScreenState extends State<TestResultNotificationsScreen>
    with SingleTickerProviderStateMixin {
  final TestResultNotificationRepository _repository = TestResultNotificationRepository();
  late TabController _tabController;

  List<TestResultNotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _unreadCount = 0;

  String get effectivePatientId {
    if (widget.patientId != null && widget.patientId!.isNotEmpty) {
      return widget.patientId!;
    }
    final userId = BmsAuth.user?['patientId'] ??
        BmsAuth.user?['patientCode'] ??
        BmsAuth.user?['userId'] ??
        BmsAuth.user?['id'];
    return userId?.toString() ?? '';
  }

  bool get _isAuthorizedPatient {
    final roleId = BmsAuth.user?['roleId'];
    final roleName = (BmsAuth.user?['roleName'] ?? BmsAuth.user?['role'] ?? '').toString().toLowerCase();
    if (roleId == null && roleName.isEmpty) return true;
    return roleId == 5 || roleId == '5' || roleName.contains('patient') || roleName.contains('bệnh nhân');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!_isAuthorizedPatient) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Chức năng nhận thông báo kết quả xét nghiệm trên ứng dụng di động chỉ dành cho vai trò Bệnh nhân (Patient).';
      });
      return;
    }

    if (effectivePatientId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Vui lòng đăng nhập tài khoản bệnh nhân để xem thông báo kết quả xét nghiệm.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _repository.getPatientNotifications(effectivePatientId);
      final unread = await _repository.getUnreadCount(effectivePatientId);

      if (mounted) {
        setState(() {
          _notifications = results;
          _unreadCount = unread;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<TestResultNotificationModel> get _filteredNotifications {
    switch (_tabController.index) {
      case 1: // Khẩn cấp (Panic / Critical)
        return _notifications.where((n) => n.isCriticalPanicValue).toList();
      case 2: // Chưa đọc
        return _notifications.where((n) => !n.isRead).toList();
      default: // Tất cả
        return _notifications;
    }
  }

  Future<void> _handleMarkAsRead(TestResultNotificationModel notification) async {
    if (notification.isRead) return;

    try {
      final success = await _repository.markAsRead(notification.notificationId);
      if (success && mounted) {
        setState(() {
          final index = _notifications.indexWhere((n) => n.notificationId == notification.notificationId);
          if (index != -1) {
            final old = _notifications[index];
            _notifications[index] = TestResultNotificationModel(
              id: old.id,
              notificationId: old.notificationId,
              testOrderId: old.testOrderId,
              specimenBarcode: old.specimenBarcode,
              patientId: old.patientId,
              patientName: old.patientName,
              patientPhone: old.patientPhone,
              patientEmail: old.patientEmail,
              title: old.title,
              message: old.message,
              channel: old.channel,
              priority: old.priority,
              status: 'Read',
              isCriticalPanicValue: old.isCriticalPanicValue,
              criticalParameters: old.criticalParameters,
              requiresImmediateAction: old.requiresImmediateAction,
              clinicalRecommendation: old.clinicalRecommendation,
              testPackageName: old.testPackageName,
              sentAt: old.sentAt,
              deliveredAt: old.deliveredAt,
              readAt: DateTime.now().toIso8601String(),
              failureReason: old.failureReason,
              retryCount: old.retryCount,
              createdAt: old.createdAt,
            );
            if (_unreadCount > 0) _unreadCount--;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showNotificationDetails(TestResultNotificationModel item) {
    _handleMarkAsRead(item);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildDetailBottomSheet(item),
    );
  }

  Widget _buildDetailBottomSheet(TestResultNotificationModel item) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Emergency Banner if Panic
            if (item.isCriticalPanicValue) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CẢNH BÁO: CHỈ SỐ XÉT NGHIỆM NGUY HIỂM',
                            style: TextStyle(
                              color: Color(0xFF991B1B),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Phòng xét nghiệm ghi nhận kết quả vượt ngưỡng an toàn lâm sàng. Vui lòng liên hệ bác sĩ hoặc cơ sở y tế gần nhất ngay lập tức.',
                            style: TextStyle(color: Color(0xFFB91C1C), fontSize: 13, height: 1.3),
                          ),
                          if (item.criticalParameters.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: item.criticalParameters.map((p) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFF87171)),
                                  ),
                                  child: Text(
                                    p,
                                    style: const TextStyle(
                                      color: Color(0xFF991B1B),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Title & Channel
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F2743),
                    ),
                  ),
                ),
                _buildChannelBadge(item.channel),
              ],
            ),
            const SizedBox(height: 8),

            // Timestamp
            Text(
              'Gửi lúc: ${item.sentAt ?? item.createdAt}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const Divider(height: 28),

            // Message Body
            const Text(
              'Nội dung thông báo:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                item.message,
                style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
              ),
            ),

            if (item.clinicalRecommendation != null && item.clinicalRecommendation!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Khuyến nghị lâm sàng:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.medical_services_outlined, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.clinicalRecommendation!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1D4ED8), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Order and Specimen metadata
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildMetaRow('Mã phiếu xét nghiệm:', item.testOrderId),
                  if (item.specimenBarcode != null) ...[
                    const SizedBox(height: 6),
                    _buildMetaRow('Mã mẫu bệnh phẩm:', item.specimenBarcode!),
                  ],
                  if (item.testPackageName != null) ...[
                    const SizedBox(height: 6),
                    _buildMetaRow('Gói xét nghiệm:', item.testPackageName!),
                  ],
                  if (item.patientEmail != null) ...[
                    const SizedBox(height: 6),
                    _buildMetaRow('Thư điện tử (Email):', item.patientEmail!),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Đóng'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExportTestResultScreen(orderId: item.testOrderId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Xem Phiếu Kết Quả'),
                    style: FilledButton.styleFrom(
                      backgroundColor: item.isCriticalPanicValue ? const Color(0xFFDC2626) : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildChannelBadge(String channel) {
    IconData icon;
    Color color;
    switch (channel.toLowerCase()) {
      case 'sms':
        icon = Icons.sms_outlined;
        color = const Color(0xFF059669);
        break;
      case 'email':
        icon = Icons.email_outlined;
        color = const Color(0xFFD97706);
        break;
      case 'push':
        icon = Icons.notifications_active_outlined;
        color = const Color(0xFF7C3AED);
        break;
      default:
        icon = Icons.app_registration;
        color = const Color(0xFF2563EB);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(channel, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Thông Báo Xét Nghiệm',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: const Color(0xFF0F2743),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Tất cả'),
                  if (_notifications.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _buildBadgeCount(_notifications.length, Colors.grey.shade200, Colors.black87),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Báo động'),
                  const SizedBox(width: 4),
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                  if (_notifications.any((n) => n.isCriticalPanicValue)) ...[
                    const SizedBox(width: 4),
                    _buildBadgeCount(
                      _notifications.where((n) => n.isCriticalPanicValue).length,
                      const Color(0xFFFEE2E2),
                      const Color(0xFFDC2626),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Chưa đọc'),
                  if (_unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildBadgeCount(_unreadCount, const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBadgeCount(int count, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 54, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _filteredNotifications;

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            const SizedBox(height: 100),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    _tabController.index == 1
                        ? 'Không có thông báo khẩn cấp nào.'
                        : 'Hiện tại bạn không có thông báo nào.',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildNotificationCard(item);
        },
      ),
    );
  }

  Widget _buildNotificationCard(TestResultNotificationModel item) {
    final isPanic = item.isCriticalPanicValue;

    return InkWell(
      onTap: () => _showNotificationDetails(item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPanic
                ? const Color(0xFFFCA5A5)
                : (item.isRead ? const Color(0xFFE2E8F0) : const Color(0xFF93C5FD)),
            width: isPanic ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isPanic ? const Color(0xFFEF4444).withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panic Emergency banner ribbon
            if (isPanic)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'CẢNH BÁO GIÁ TRỊ NGUY HIỂM (PANIC VALUE)',
                        style: TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Dot / Panic Icon
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isPanic
                              ? const Color(0xFFFEE2E2)
                              : (item.isRead ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF)),
                        ),
                        child: Icon(
                          isPanic
                              ? Icons.priority_high_rounded
                              : (item.isRead ? Icons.done_all_rounded : Icons.mark_email_unread_outlined),
                          color: isPanic
                              ? const Color(0xFFDC2626)
                              : (item.isRead ? const Color(0xFF64748B) : const Color(0xFF0284C7)),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                                      fontSize: 15,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                if (!item.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0284C7),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: item.isRead ? const Color(0xFF64748B) : const Color(0xFF334155),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Critical Parameters Tags
                  if (item.criticalParameters.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: item.criticalParameters.map((param) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Text(
                            param,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  if (item.patientEmail != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.mail_outline, size: 13, color: Color(0xFF2563EB)),
                        const SizedBox(width: 4),
                        Text(
                          'Email: ${item.patientEmail}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // Footer metadata & channel
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            item.sentAt ?? item.createdAt,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildChannelBadge(item.channel),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
