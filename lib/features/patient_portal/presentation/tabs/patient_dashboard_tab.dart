import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../../../appointment/presentation/book_appointment_screen.dart';
import '../../../catalog/data/catalog_repository.dart';
import '../../../catalog/models/test_package_model.dart';
import '../../../notification/presentation/screens/unified_notifications_screen.dart';
import '../../../patient/presentation/screens/export_test_result_screen.dart';
import '../../data/patient_portal_api.dart';
import '../screens/patient_feedback_screen.dart';
import 'patient_billing_tab.dart';

/// 1-to-1 Patient Home Tab matching Web `PatientHomePage.jsx`:
/// - Personalized Greeting + Canonical PID + Unread notification badge
/// - Package Search bar jumping straight to Catalog tab
/// - Latest Test Result Card (direct tap to ExportTestResultScreen / PDF A4)
/// - 5 Quick Actions (Đặt lịch, Lịch khám, Kết quả, Thanh toán SePay, Đánh giá)
/// - Top 4 Featured Packages with real star ratings & 1-tap booking
class PatientDashboardTab extends StatefulWidget {
  final void Function(int tabIndex, {int? subTabIndex, String? catalogSearch})
  onNavigateTab;

  const PatientDashboardTab({super.key, required this.onNavigateTab});

  @override
  State<PatientDashboardTab> createState() => _PatientDashboardTabState();
}

class _PatientDashboardTabState extends State<PatientDashboardTab> {
  final PatientPortalApi _api = const PatientPortalApi();
  final CatalogRepository _catalogRepo = const CatalogRepository();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String _patientCode = '';
  int _unreadCount = 0;
  Map<String, dynamic>? _recentTest;
  List<TestPackageModel> _featuredPackages = [];
  Map<String, PackageRatingSummary> _ratingsMap = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await _api.getMedicalProfile().catchError((_) => null);
      final pid =
          (profile?['patientCode'] ??
                  profile?['id'] ??
                  BmsAuth.user?['patientCode'] ??
                  BmsAuth.currentUserId)
              .toString();

      final results = await Future.wait<dynamic>([
        _catalogRepo
            .searchTestPackages(page: 1, pageSize: 4)
            .catchError(
              (_) => const TestPackageSearchResponse(
                items: [],
                categories: [],
                sampleTubes: [],
                totalCount: 0,
                page: 1,
                pageSize: 4,
                totalPages: 1,
              ),
            ),
        _catalogRepo.getPackageRatingsMap(),
        _api.getTestHistory(patientId: pid, pageSize: 1),
        _api.getReleasedResults(pid),
        _api.getCombinedNotifications(patientId: pid).catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;
      final catRes = results[0] as TestPackageSearchResponse;
      final ratings = results[1] as Map<String, PackageRatingSummary>;
      final hist = results[2] as List<Map<String, dynamic>>;
      final released = results[3] as List<Map<String, dynamic>>;
      final notifs = results[4] as List<Map<String, dynamic>>;

      setState(() {
        _patientCode = pid;
        _featuredPackages = catRes.items.take(4).toList();
        _ratingsMap = ratings;
        _recentTest = hist.isNotEmpty
            ? hist.first
            : (released.isNotEmpty ? released.first : null);
        _unreadCount = notifs.where((n) => n['isRead'] != true).length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = BmsAuth.currentUserName.isNotEmpty
        ? BmsAuth.currentUserName
        : 'Bệnh nhân';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Top Greeting & Notification Bell
          BmsPageHeaderCard(
            icon: Icons.favorite_outline_rounded,
            badgeText: _patientCode.isNotEmpty
                ? 'PID: $_patientCode'
                : 'CỔNG BỆNH NHÂN BMS',
            title: 'Xin chào, $name',
            subtitle: 'Theo dõi sức khỏe, đặt lịch & nhận phiếu KQ chuẩn ISO 15189',
            trailing: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton.outlined(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PatientNotificationsScreen(),
                      ),
                    );
                    _load();
                  },
                  icon: const Icon(Icons.notifications_outlined, size: 22),
                  tooltip: 'Thông báo',
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            bottom: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: (v) =>
                        widget.onNavigateTab(1, catalogSearch: v.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Tìm gói xét nghiệm theo tên, chuyên khoa...',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => widget.onNavigateTab(
                    1,
                    catalogSearch: _searchCtrl.text.trim(),
                  ),
                  child: const Text('Tìm'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Latest Test Result Card (1-1 Web PatientHomePage.jsx)
          if (_loading)
            const BmsLoadingState(message: 'Đang đồng bộ dữ liệu sức khỏe...')
          else
            _buildRecentResultCard(),
          const SizedBox(height: 14),

          // 5 Quick Actions Strip
          const BmsSectionHeader(title: 'Tiện ích nhanh'),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.15,
            children: [
              _quickAction(
                icon: Icons.add_circle_outline_rounded,
                label: 'Đặt lịch XN',
                color: AppColors.primary,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BookAppointmentScreen(),
                  ),
                ),
              ),
              _quickAction(
                icon: Icons.calendar_month_outlined,
                label: 'Lịch khám',
                color: AppColors.teal,
                onTap: () => widget.onNavigateTab(2),
              ),
              _quickAction(
                icon: Icons.track_changes_rounded,
                label: 'Tiến trình mẫu',
                color: const Color(0xFF7C3AED),
                onTap: () => widget.onNavigateTab(3, subTabIndex: 0),
              ),
              _quickAction(
                icon: Icons.picture_as_pdf_outlined,
                label: 'Lịch sử & PDF',
                color: AppColors.success,
                onTap: () => widget.onNavigateTab(3, subTabIndex: 1),
              ),
              _quickAction(
                icon: Icons.qr_code_2_rounded,
                label: 'Viện phí SePay',
                color: AppColors.warning,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const PatientBillingTab(asStandaloneScreen: true),
                  ),
                ),
              ),
              _quickAction(
                icon: Icons.star_outline_rounded,
                label: 'Đánh giá',
                color: const Color(0xFFEC4899),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PatientFeedbackScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Top 4 Packages with real star ratings
          BmsSectionHeader(
            title: 'Gói xét nghiệm phổ biến',
            subtitle: 'Đánh giá thực tế từ bệnh nhân đã sử dụng',
            trailing: TextButton(
              onPressed: () => widget.onNavigateTab(1),
              child: const Text('Xem tất cả'),
            ),
          ),
          const SizedBox(height: 10),
          ..._featuredPackages.map((pkg) {
            final rat = CatalogRepository.lookupRating(_ratingsMap, pkg);
            return BmsSoftCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BookAppointmentScreen(
                    initialPackageId: pkg.packageCode.isNotEmpty
                        ? pkg.packageCode
                        : pkg.id,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.science_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pkg.packageName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${pkg.category} • ${pkg.tat}${rat != null && rat.reviewCount > 0 ? ' • ★ ${rat.averageRating.toStringAsFixed(1)} (${rat.reviewCount})' : ''}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        BmsFormatters.currency(pkg.price),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const Text(
                        'Đặt ngay →',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.successText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRecentResultCard() {
    final t = _recentTest;
    if (t == null) {
      return BmsSoftCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chưa có phiếu kết quả xét nghiệm',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Đặt lịch xét nghiệm đầu tiên để nhận phiếu kết quả điện tử ký số.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final orderId =
        (t['resultCode'] ?? t['orderId'] ?? t['OrderId'] ?? t['id'] ?? '')
            .toString();
    final pkgName =
        (t['packageName'] ??
                t['PackageName'] ??
                t['testName'] ??
                'Gói xét nghiệm lâm sàng')
            .toString();
    final status =
        (t['overallStatus'] ?? t['OverallStatus'] ?? t['status'] ?? 'Completed')
            .toString();
    final dateRaw =
        t['releasedDate'] ?? t['ReleasedDate'] ?? t['orderDate'] ?? t['createdAt'];

    return BmsSoftCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.primaryBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'KẾT QUẢ XÉT NGHIỆM GẦN NHẤT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              BmsStatusPill(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pkgName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            'Mã phiếu: $orderId • ${BmsFormatters.date(dateRaw)}',
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: orderId.isEmpty
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ExportTestResultScreen(orderId: orderId),
                      ),
                    ),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('Xem Phiếu Kết Quả (PDF A4)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return BmsSoftCard(
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
