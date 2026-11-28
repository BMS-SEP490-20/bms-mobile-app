import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../../data/catalog_repository.dart';
import '../../models/test_package_model.dart';
import '../../../appointment/presentation/book_appointment_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';

/// 1-to-1 Service Catalog & Price List Screen matching Web `ServiceCatalogPage.jsx`:
/// - Works in both Guest mode (`isGuest: true`) and Authenticated Patient mode
/// - Search, Category chips, Sort (`Tên A-Z`, `Giá tăng`, `Giá giảm`), Price-List toggle
/// - Real star ratings from `GET /TestOrder/feedback/package-ratings`
/// - Detail bottom sheet with full biomarker table (`referenceRange`), fasting notes & public verified reviews
/// - Direct Booking CTA wired to `BookAppointmentScreen` (or Login prompt for Guest)
class ServiceCatalogScreen extends StatefulWidget {
  final bool embedded;
  final bool isGuest;
  final String? initialSearch;

  const ServiceCatalogScreen({
    super.key,
    this.embedded = false,
    this.isGuest = false,
    this.initialSearch,
  });

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen> {
  final CatalogRepository _repo = const CatalogRepository();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<TestPackageModel> _packages = [];
  List<String> _categories = [];
  Map<String, PackageRatingSummary> _ratingsMap = {};

  String _selectedCategory = '';
  String _sortKey = 'name_asc'; // name_asc | price_asc | price_desc
  bool _priceListMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _searchCtrl.text = widget.initialSearch!;
    }
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sortBy = _sortKey.startsWith('price') ? 'price' : 'name';
      final sortDir = _sortKey.endsWith('desc') ? 'desc' : 'asc';
      final results = await Future.wait([
        _repo.searchTestPackages(
          keyword: _searchCtrl.text.trim(),
          category: _selectedCategory.isEmpty ? null : _selectedCategory,
          sortBy: sortBy,
          sortDir: sortDir,
          page: 1,
          pageSize: 60,
        ),
        _repo.getPackageRatingsMap(),
      ]);

      if (!mounted) return;
      final res = results[0] as TestPackageSearchResponse;
      final ratings = results[1] as Map<String, PackageRatingSummary>;

      final cats = res.categories.isNotEmpty
          ? res.categories
          : res.items.map((e) => e.category).toSet().toList();

      setState(() {
        _packages = res.items;
        if (_categories.isEmpty && cats.isNotEmpty) {
          _categories = cats;
        }
        _ratingsMap = ratings;
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

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _loadData);
  }

  void _handleBook(TestPackageModel pkg) {
    if (widget.isGuest || !BmsAuth.isLoggedIn) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Đăng nhập để đặt lịch'),
          content: Text(
            'Vui lòng đăng nhập tài khoản Bệnh nhân để đặt lịch gói "${pkg.packageName}".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('Đăng nhập ngay'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookAppointmentScreen(
          initialPackageId: pkg.packageCode.isNotEmpty ? pkg.packageCode : pkg.id,
        ),
      ),
    );
  }

  void _openPackageDetail(TestPackageModel pkg) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PackageDetailSheet(
        packageItem: pkg,
        rating: CatalogRepository.lookupRating(_ratingsMap, pkg),
        repo: _repo,
        onBook: () {
          Navigator.of(context).pop();
          _handleBook(pkg);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BmsPageHeaderCard(
            icon: Icons.medical_information_outlined,
            badgeText: 'DANH MỤC & BẢNG GIÁ NIÊM YẾT',
            title: 'Gói Xét Nghiệm Y Khoa',
            subtitle:
                '${_packages.length} gói dịch vụ chuẩn ISO 15189 • Minh bạch chi phí & chỉ số sinh học',
            trailing: IconButton.outlined(
              onPressed: () => setState(() => _priceListMode = !_priceListMode),
              tooltip: _priceListMode ? 'Xem dạng thẻ' : 'Xem bảng giá gọn',
              icon: Icon(
                _priceListMode
                    ? Icons.grid_view_rounded
                    : Icons.table_rows_outlined,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 12),
          BmsSearchFilterBar(
            controller: _searchCtrl,
            hintText: 'Tìm theo tên gói, mã gói, chuyên khoa...',
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _loadData(),
            onClear: _loadData,
            filterChips: [
              BmsFilterChipItem(
                key: '',
                label: 'Tất cả',
                selected: _selectedCategory.isEmpty,
                onSelected: () {
                  setState(() => _selectedCategory = '');
                  _loadData();
                },
              ),
              ..._categories.map(
                (cat) => BmsFilterChipItem(
                  key: cat,
                  label: cat,
                  selected: _selectedCategory == cat,
                  onSelected: () {
                    setState(() => _selectedCategory = cat);
                    _loadData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Sắp xếp:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _sortPill('name_asc', 'Tên A → Z'),
                      const SizedBox(width: 6),
                      _sortPill('price_asc', 'Giá thấp → cao'),
                      const SizedBox(width: 6),
                      _sortPill('price_desc', 'Giá cao → thấp'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading)
            const BmsLoadingState(message: 'Đang tải danh mục gói xét nghiệm...')
          else if (_error != null)
            BmsErrorState(message: _error!, onRetry: _loadData)
          else if (_packages.isEmpty)
            BmsEmptyState(
              icon: Icons.science_outlined,
              title: 'Không tìm thấy gói xét nghiệm phù hợp',
              subtitle: 'Thử xóa từ khóa tìm kiếm hoặc chọn danh mục khác.',
              actionLabel: 'Đặt lại bộ lọc',
              onAction: () {
                _searchCtrl.clear();
                setState(() => _selectedCategory = '');
                _loadData();
              },
            )
          else if (_priceListMode)
            _buildPriceTable()
          else
            ..._packages.map(_buildPackageCard),
          const SizedBox(height: 24),
        ],
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Gói xét nghiệm & Bảng giá')),
      body: SafeArea(child: body),
    );
  }

  Widget _sortPill(String key, String label) {
    final active = _sortKey == key;
    return GestureDetector(
      onTap: () {
        setState(() => _sortKey = key);
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPriceTable() {
    return BmsSoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(_packages.length, (index) {
          final pkg = _packages[index];
          return Column(
            children: [
              InkWell(
                onTap: () => _openPackageDetail(pkg),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pkg.packageName,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${pkg.packageCode} • ${pkg.category} • ${pkg.tat}',
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
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const Text(
                            'Chi tiết →',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (index < _packages.length - 1) const Divider(height: 1),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPackageCard(TestPackageModel pkg) {
    final rating = CatalogRepository.lookupRating(_ratingsMap, pkg);
    return BmsSoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      onTap: () => _openPackageDetail(pkg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pkg.category,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                pkg.packageCode,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (rating != null && rating.reviewCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${rating.averageRating.toStringAsFixed(1)} (${rating.reviewCount})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warningText,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pkg.packageName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (pkg.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              pkg.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _metaChip(Icons.schedule_outlined, 'Trả KQ: ${pkg.tat}'),
              _metaChip(Icons.science_outlined, pkg.sampleTube),
              if (pkg.includedCriteriaCount > 0)
                _metaChip(
                  Icons.checklist_rounded,
                  '${pkg.includedCriteriaCount} chỉ số',
                ),
              if (pkg.requiresFasting)
                _metaChip(
                  Icons.no_food_outlined,
                  'Cần nhịn ăn',
                  color: AppColors.warningText,
                ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Giá niêm yết',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      BmsFormatters.currency(pkg.price),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => _openPackageDetail(pkg),
                child: const Text('Chi tiết'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _handleBook(pkg),
                child: const Text('Đặt lịch'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, {Color? color}) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: c,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PackageDetailSheet extends StatefulWidget {
  final TestPackageModel packageItem;
  final PackageRatingSummary? rating;
  final CatalogRepository repo;
  final VoidCallback onBook;

  const _PackageDetailSheet({
    required this.packageItem,
    required this.rating,
    required this.repo,
    required this.onBook,
  });

  @override
  State<_PackageDetailSheet> createState() => _PackageDetailSheetState();
}

class _PackageDetailSheetState extends State<_PackageDetailSheet> {
  late TestPackageModel _pkg;
  List<Map<String, dynamic>> _reviews = [];
  bool _loadingExtra = true;

  @override
  void initState() {
    super.initState();
    _pkg = widget.packageItem;
    _loadExtra();
  }

  Future<void> _loadExtra() async {
    try {
      final results = await Future.wait([
        widget.repo.getById(_pkg.id.isNotEmpty ? _pkg.id : _pkg.packageCode),
        widget.repo.getPackageReviews(
          _pkg.packageCode.isNotEmpty ? _pkg.packageCode : _pkg.id,
        ),
      ]);
      if (!mounted) return;
      final fullPkg = results[0] as TestPackageModel?;
      final reviewPayload = results[1] as Map<String, dynamic>?;
      final rawReviews =
          reviewPayload?['reviews'] ?? reviewPayload?['items'] ?? const [];

      setState(() {
        if (fullPkg != null) _pkg = fullPkg;
        if (rawReviews is List) {
          _reviews = rawReviews
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        _loadingExtra = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingExtra = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(18),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _pkg.category,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _pkg.packageCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _pkg.packageName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  BmsFormatters.currency(_pkg.price),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                if (_pkg.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _pkg.description,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                BmsSoftCard(
                  backgroundColor: _pkg.requiresFasting
                      ? AppColors.warningLight
                      : AppColors.surfaceSoft,
                  borderColor: _pkg.requiresFasting
                      ? AppColors.warningBorder
                      : AppColors.cardBorder,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hướng dẫn chuẩn bị & Lấy mẫu',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      BmsInfoRow(label: 'Ống mẫu', value: _pkg.sampleTube),
                      BmsInfoRow(
                        label: 'Thể tích mẫu',
                        value: '${_pkg.sampleVolumeMl} ml',
                      ),
                      BmsInfoRow(label: 'Thời gian trả KQ', value: _pkg.tat),
                      const SizedBox(height: 4),
                      Text(
                        _pkg.displayPreparation,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _pkg.requiresFasting
                              ? AppColors.warningText
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Danh mục chỉ số xét nghiệm (${_pkg.criteria.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (_loadingExtra && _pkg.criteria.isEmpty)
                  const BmsLoadingState(message: 'Đang tải danh mục chỉ số...')
                else if (_pkg.criteria.isEmpty)
                  const Text(
                    'Các chỉ số chi tiết sẽ được đối soát theo phác đồ phòng xét nghiệm.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  BmsSoftCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: _pkg.criteria.map((c) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.name.isNotEmpty ? c.name : c.code,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      c.code,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    c.displayReferenceRange,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  if (c.unit.isNotEmpty)
                                    Text(
                                      c.unit,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Đánh giá từ bệnh nhân đã sử dụng',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (widget.rating != null && widget.rating!.reviewCount > 0)
                      Text(
                        '★ ${widget.rating!.averageRating.toStringAsFixed(1)} (${widget.rating!.reviewCount})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warningText,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_reviews.isEmpty)
                  const Text(
                    'Chưa có đánh giá công khai nào cho gói này.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  ..._reviews.take(5).map((r) {
                    final stars = (r['rating'] as num?)?.toInt() ?? 5;
                    return BmsSoftCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      backgroundColor: AppColors.surfaceSoft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                (r['displayAuthor'] ??
                                        r['patientName'] ??
                                        'Bệnh nhân ẩn danh')
                                    .toString(),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '★' * stars,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                          if ((r['title'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              r['title'].toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if ((r['comment'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              r['comment'].toString(),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.cardBorder)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: widget.onBook,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(
                  'Đặt lịch gói này • ${BmsFormatters.currency(_pkg.price)}',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
