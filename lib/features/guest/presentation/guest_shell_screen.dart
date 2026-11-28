import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bms_ui_kit.dart';
import '../../auth/presentation/screens/login_screen.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/models/test_package_model.dart';
import '../../catalog/presentation/screens/service_catalog_screen.dart';
import '../../patient_portal/data/patient_portal_api.dart';

/// 1-to-1 Public Guest Portal Shell matching Web Guest Home / Catalog / Public Tracking / Login.
class GuestShellScreen extends StatefulWidget {
  final int initialIndex;

  const GuestShellScreen({super.key, this.initialIndex = 0});

  @override
  State<GuestShellScreen> createState() => _GuestShellScreenState();
}

class _GuestShellScreenState extends State<GuestShellScreen> {
  late int _index;
  String? _catalogSearch;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  void _openCatalog([String? search]) {
    setState(() {
      _catalogSearch = search;
      _index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _GuestHomeTab(
        onSearchCatalog: _openCatalog,
        onOpenTracking: () => setState(() => _index = 2),
        onOpenLogin: () => setState(() => _index = 3),
      ),
      ServiceCatalogScreen(
        key: ValueKey('guest_catalog_${_catalogSearch ?? ''}'),
        embedded: true,
        isGuest: true,
        initialSearch: _catalogSearch,
      ),
      const _PublicTrackingTab(),
      const LoginScreen(embeddedInGuestTab: true),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.medical_information_outlined),
              selectedIcon: Icon(Icons.medical_information_rounded),
              label: 'Gói XN',
            ),
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_outlined),
              selectedIcon: Icon(Icons.qr_code_scanner_rounded),
              label: 'Tra cứu',
            ),
            NavigationDestination(
              icon: Icon(Icons.login_outlined),
              selectedIcon: Icon(Icons.login_rounded),
              label: 'Đăng nhập',
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestHomeTab extends StatefulWidget {
  final ValueChanged<String?> onSearchCatalog;
  final VoidCallback onOpenTracking;
  final VoidCallback onOpenLogin;

  const _GuestHomeTab({
    required this.onSearchCatalog,
    required this.onOpenTracking,
    required this.onOpenLogin,
  });

  @override
  State<_GuestHomeTab> createState() => _GuestHomeTabState();
}

class _GuestHomeTabState extends State<_GuestHomeTab> {
  final CatalogRepository _repo = const CatalogRepository();
  final TextEditingController _searchCtrl = TextEditingController();

  List<TestPackageModel> _featured = [];
  Map<String, PackageRatingSummary> _ratings = {};
  bool _loading = true;

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
    try {
      final results = await Future.wait([
        _repo.searchTestPackages(page: 1, pageSize: 4),
        _repo.getPackageRatingsMap(),
      ]);
      if (!mounted) return;
      final cat = results[0] as TestPackageSearchResponse;
      final rat = results[1] as Map<String, PackageRatingSummary>;
      setState(() {
        _featured = cat.items.take(4).toList();
        _ratings = rat;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero Card
          BmsSoftCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'CHUẨN Y KHOA ISO 15189 • BMS LAB',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: widget.onOpenLogin,
                      child: const Text('Đăng nhập'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Quản Lý Xét Nghiệm Máu Chính Xác, Khép Kín & Tin Cậy',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Đặt lịch trực tuyến, quét mã vạch Barcode định danh duy nhất, theo dõi 6 giai đoạn realtime và nhận phiếu kết quả ký số A4.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onSubmitted: (v) => widget.onSearchCatalog(v),
                        decoration: const InputDecoration(
                          hintText: 'Tìm gói xét nghiệm, triệu chứng...',
                          prefixIcon: Icon(Icons.search_rounded, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () =>
                          widget.onSearchCatalog(_searchCtrl.text.trim()),
                      child: const Text('Tìm'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onOpenTracking,
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                        label: const Text('Tra cứu mẫu'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: widget.onOpenLogin,
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: const Text('Đặt lịch ngay'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4 Clinical Pillars
          const BmsKpiGrid(
            cards: [
              BmsKpiCard(
                label: 'Mã vạch 1D/2D',
                value: '100%',
                subtitle: 'Định danh duy nhất mẫu máu',
                icon: Icons.qr_code_2_rounded,
                accentColor: AppColors.primary,
              ),
              BmsKpiCard(
                label: 'Nội kiểm QC',
                value: 'Westgard',
                subtitle: 'Kiểm soát sai số liên tục',
                icon: Icons.verified_outlined,
                accentColor: AppColors.success,
              ),
              BmsKpiCard(
                label: 'Bác sĩ thẩm định',
                value: 'Ký số',
                subtitle: 'SHA-256 chuẩn ISO 15189',
                icon: Icons.medical_services_outlined,
                accentColor: AppColors.teal,
              ),
              BmsKpiCard(
                label: 'Chuỗi lạnh IoT',
                value: '2 – 6°C',
                subtitle: 'Giám sát tủ bảo quản 24/7',
                icon: Icons.thermostat_rounded,
                accentColor: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 18),

          BmsSectionHeader(
            title: 'Gói xét nghiệm nổi bật',
            subtitle: 'Bảng giá niêm yết công khai từ hệ thống',
            trailing: TextButton(
              onPressed: () => widget.onSearchCatalog(null),
              child: const Text('Xem tất cả'),
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const BmsLoadingState(message: 'Đang tải gói xét nghiệm...')
          else
            ..._featured.map((pkg) {
              final rat = CatalogRepository.lookupRating(_ratings, pkg);
              return BmsSoftCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                onTap: () => widget.onSearchCatalog(pkg.packageCode),
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
                        Icons.biotech_rounded,
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
                            '${pkg.category} • ${pkg.tat}${rat != null && rat.reviewCount > 0 ? ' • ★ ${rat.averageRating.toStringAsFixed(1)}' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      BmsFormatters.currency(pkg.price),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
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
}

class _PublicTrackingTab extends StatefulWidget {
  const _PublicTrackingTab();

  @override
  State<_PublicTrackingTab> createState() => _PublicTrackingTabState();
}

class _PublicTrackingTabState extends State<_PublicTrackingTab> {
  final PatientPortalApi _api = const PatientPortalApi();
  final TextEditingController _codeCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _tracking;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Vui lòng nhập mã đơn xét nghiệm hoặc mã barcode mẫu.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _tracking = null;
    });
    try {
      final data = await _api.lookupTrackingByCode(code, includeAuth: false);
      if (!mounted) return;
      setState(() {
        _tracking = data;
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

  @override
  Widget build(BuildContext context) {
    final stages = (_tracking?['stages'] ?? _tracking?['timeline'] ?? const [])
        as List<dynamic>;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const BmsPageHeaderCard(
          icon: Icons.track_changes_rounded,
          badgeText: 'TRA CỨU CÔNG KHAI • BẢO MẬT PII',
          title: 'Tra cứu tiến trình mẫu máu',
          subtitle:
              'Nhập mã Barcode (VD: SMP-...) hoặc mã phiếu (TRE-...) để xem tiến độ 6 bước realtime',
        ),
        const SizedBox(height: 12),
        BmsSoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _codeCtrl,
                onSubmitted: (_) => _lookup(),
                decoration: const InputDecoration(
                  labelText: 'Mã đơn / Mã Barcode mẫu',
                  hintText: 'VD: SMP-20261128-0001 hoặc TRE-...',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _lookup,
                  icon: const Icon(Icons.search_rounded),
                  label: Text(_loading ? 'Đang tra cứu...' : 'Tra cứu tiến trình'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_error != null)
          BmsErrorState(message: _error!)
        else if (_tracking != null)
          BmsSoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (_tracking!['orderNumber'] ??
                                _tracking!['orderId'] ??
                                _tracking!['barcode'] ??
                                _codeCtrl.text.trim())
                            .toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    BmsStatusPill(
                      status:
                          (_tracking!['overallStatus'] ??
                                  _tracking!['status'] ??
                                  'InProgress')
                              .toString(),
                    ),
                  ],
                ),
                const Divider(height: 22),
                ...stages.whereType<Map>().map((raw) {
                  final stage = Map<String, dynamic>.from(raw);
                  final status = (stage['status'] ?? '').toString().toLowerCase();
                  final done =
                      status == 'completed' ||
                      status == 'done' ||
                      stage['isCompleted'] == true;
                  final active = status == 'inprogress' || status == 'active';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          done
                              ? Icons.check_circle_rounded
                              : active
                              ? Icons.timelapse_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: done
                              ? AppColors.success
                              : active
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (stage['stageName'] ??
                                        stage['title'] ??
                                        stage['name'] ??
                                        'Giai đoạn')
                                    .toString(),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: done || active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              if ((stage['completedAt'] ?? stage['timestamp']) !=
                                  null)
                                Text(
                                  BmsFormatters.dateTime(
                                    stage['completedAt'] ?? stage['timestamp'],
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }
}
