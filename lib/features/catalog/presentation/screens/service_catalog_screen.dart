import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/bms_auth.dart';
import '../../../patient/presentation/screens/create_guest_profile_screen.dart';
import '../../data/catalog_repository.dart';
import '../../models/test_package_model.dart';

/// UC20: Search Test Packages (Mobile) Screen.
///
/// Connects to `GET /api/v1/test-packages/search` and `GET /api/v1/test-packages/{id}`:
/// - Keyword search across package name, code, description, and biomarker criteria
/// - Category filter chips, Sample Tube filter, Price range filter, and Sorting
/// - Pagination controls & Pull-to-refresh
/// - Package Detail Bottom Sheet Popup with clinical biomarker criteria table,
///   specimen tube badge, turnaround time (TAT), preparation notes, and quick Walk-In Guest registration
class ServiceCatalogScreen extends StatefulWidget {
  const ServiceCatalogScreen({super.key});

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen> {
  final CatalogRepository _repo = CatalogRepository();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<TestPackageModel> _packages = [];
  List<String> _categories = [
    'Tất cả',
    'Hematology',
    'Biochemistry',
    'Endocrinology',
    'Immunology',
    'General',
  ];
  List<String> _sampleTubes = [
    'Tất cả',
    'EDTA (Tím)',
    'Heparin (Xanh lá)',
    'Serum / Gel (Đỏ/Vàng)',
  ];

  String _selectedCategory = 'Tất cả';
  String _selectedSampleTube = 'Tất cả';
  double? _minPrice;
  double? _maxPrice;
  String _sortBy = 'name';
  String _sortDir = 'asc';

  int _page = 1;
  final int _pageSize = 10;
  int _totalCount = 0;
  int _totalPages = 1;

  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _executeSearch(resetPage: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onKeywordChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _executeSearch(resetPage: true);
    });
  }

  Future<void> _executeSearch({bool resetPage = false}) async {
    if (resetPage) {
      _page = 1;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await _repo.searchTestPackages(
        keyword: _searchCtrl.text.trim(),
        category: _selectedCategory == 'Tất cả' ? null : _selectedCategory,
        sampleTube:
            _selectedSampleTube == 'Tất cả' ? null : _selectedSampleTube,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        isActive: true,
        sortBy: _sortBy,
        sortDir: _sortDir,
        page: _page,
        pageSize: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        _packages = result.items;
        _totalCount = result.totalCount;
        _totalPages = result.totalPages > 0 ? result.totalPages : 1;
        if (result.categories.isNotEmpty) {
          _categories = ['Tất cả', ...result.categories];
        }
        if (result.sampleTubes.isNotEmpty) {
          _sampleTubes = ['Tất cả', ...result.sampleTubes];
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _resetAllFilters() {
    _searchCtrl.clear();
    setState(() {
      _selectedCategory = 'Tất cả';
      _selectedSampleTube = 'Tất cả';
      _minPrice = null;
      _maxPrice = null;
      _sortBy = 'name';
      _sortDir = 'asc';
    });
    _executeSearch(resetPage: true);
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategory != 'Tất cả') count++;
    if (_selectedSampleTube != 'Tất cả') count++;
    if (_minPrice != null || _maxPrice != null) count++;
    if (_sortBy != 'name' || _sortDir != 'asc') count++;
    return count;
  }

  String _formatVnd(double amount) {
    final s = amount.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '${s.replaceAllMapped(reg, (Match m) => '${m[1]}.')} ₫';
  }

  Color _getTubeColor(String tube) {
    final lower = tube.toLowerCase();
    if (lower.contains('edta') || lower.contains('tím')) {
      return const Color(0xFF7C3AED);
    }
    if (lower.contains('heparin') || lower.contains('xanh lá')) {
      return const Color(0xFF059669);
    }
    if (lower.contains('serum') ||
        lower.contains('đỏ') ||
        lower.contains('vàng')) {
      return const Color(0xFFD97706);
    }
    if (lower.contains('citrate') || lower.contains('xanh dương')) {
      return const Color(0xFF0284C7);
    }
    return AppColors.primary;
  }

  Future<void> _openFilterSheet() async {
    String tempTube = _selectedSampleTube;
    String tempSort = '$_sortBy:$_sortDir';
    final minCtrl = TextEditingController(
      text: _minPrice != null ? _minPrice!.toStringAsFixed(0) : '',
    );
    final maxCtrl = TextEditingController(
      text: _maxPrice != null ? _maxPrice!.toStringAsFixed(0) : '',
    );

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bộ lọc nâng cao & Sắp xếp',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempTube = 'Tất cả';
                              tempSort = 'name:asc';
                              minCtrl.clear();
                              maxCtrl.clear();
                            });
                          },
                          child: const Text('Đặt lại'),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Loại ống mẫu bệnh phẩm (Sample Tube)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _sampleTubes.map((tube) {
                        final selected = tempTube == tube;
                        return ChoiceChip(
                          label: Text(tube),
                          selected: selected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                            color:
                                selected ? Colors.white : AppColors.textPrimary,
                          ),
                          onSelected: (_) {
                            setModalState(() => tempTube = tube);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Khoảng giá dịch vụ (VNĐ)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Giá tối thiểu',
                              hintText: 'VD: 100000',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('—'),
                        ),
                        Expanded(
                          child: TextField(
                            controller: maxCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Giá tối đa',
                              hintText: 'VD: 500000',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          label: const Text(
                            '< 200.000₫',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            setModalState(() {
                              minCtrl.text = '0';
                              maxCtrl.text = '200000';
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text(
                            '200k – 400k',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            setModalState(() {
                              minCtrl.text = '200000';
                              maxCtrl.text = '400000';
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text(
                            '> 400.000₫',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            setModalState(() {
                              minCtrl.text = '400000';
                              maxCtrl.clear();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sắp xếp kết quả',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: tempSort,
                      decoration: InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'name:asc',
                          child: Text('Tên gói xét nghiệm (A → Z)'),
                        ),
                        DropdownMenuItem(
                          value: 'name:desc',
                          child: Text('Tên gói xét nghiệm (Z → A)'),
                        ),
                        DropdownMenuItem(
                          value: 'price:asc',
                          child: Text('Giá dịch vụ (Thấp → Cao)'),
                        ),
                        DropdownMenuItem(
                          value: 'price:desc',
                          child: Text('Giá dịch vụ (Cao → Thấp)'),
                        ),
                        DropdownMenuItem(
                          value: 'category:asc',
                          child: Text('Chuyên khoa (A → Z)'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => tempSort = v);
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text(
                          'Áp dụng bộ lọc',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (applied == true) {
      final parts = tempSort.split(':');
      setState(() {
        _selectedSampleTube = tempTube;
        _sortBy = parts[0];
        _sortDir = parts.length > 1 ? parts[1] : 'asc';
        _minPrice = double.tryParse(minCtrl.text.trim());
        _maxPrice = double.tryParse(maxCtrl.text.trim());
      });
      _executeSearch(resetPage: true);
    }
  }

  Future<void> _openPackageDetailSheet(TestPackageModel pkg) async {
    TestPackageModel detailedPkg = pkg;
    try {
      final fresh = await _repo.getById(pkg.id);
      if (fresh != null) {
        detailedPkg = fresh;
      }
    } catch (_) {}

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final tubeColor = _getTubeColor(detailedPkg.sampleTube);
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.55,
          maxChildSize: 0.94,
          expand: false,
          builder: (ctx, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                detailedPkg.code,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                detailedPkg.category,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          detailedPkg.name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatVnd(detailedPkg.price),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          detailedPkg.description,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Specimen & Turnaround Metadata Cards
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: tubeColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: tubeColor.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.science_outlined,
                                          size: 16,
                                          color: tubeColor,
                                        ),
                                        const SizedBox(width: 5),
                                        const Text(
                                          'Ống mẫu bệnh phẩm',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      detailedPkg.sampleTube,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: tubeColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFBBF7D0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.schedule_outlined,
                                          size: 16,
                                          color: Color(0xFF15803D),
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'Thời gian trả KQ (TAT)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      detailedPkg.tat,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Preparation Notes Alert
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Color(0xFFB45309),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Hướng dẫn chuẩn bị trước lấy mẫu: ${detailedPkg.preparationNotes}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF92400E),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Danh mục chỉ số xét nghiệm (Biomarkers)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${detailedPkg.criteria.isNotEmpty ? detailedPkg.criteria.length : detailedPkg.includedCriteriaCount} chỉ số',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (detailedPkg.criteria.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Gói bao gồm ${detailedPkg.includedCriteriaCount} chỉ số lâm sàng tiêu chuẩn theo phác đồ xét nghiệm.',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: detailedPkg.criteria
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final idx = entry.key;
                                final c = entry.value;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: idx.isEven
                                        ? Colors.white
                                        : const Color(0xFFF8FAFC),
                                    border: idx <
                                            detailedPkg.criteria.length - 1
                                        ? const Border(
                                            bottom: BorderSide(
                                              color: AppColors.border,
                                            ),
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0F2FE),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          c.code,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0369A1),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c.name,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              'Tham chiếu: ${c.displayReferenceRange}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (c.unit.isNotEmpty)
                                        Text(
                                          c.unit,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Bottom CTA bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        if (BmsAuth.isReceptionist) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CreateGuestProfileScreen(
                                      openCreatePopupOnInit: true,
                                      preselectedPackageName: detailedPkg.name,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.person_add_alt_1_outlined,
                                size: 18,
                              ),
                              label: const Text(
                                'Tạo HS Vãng lai',
                                style: TextStyle(fontSize: 12.5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Đã chọn gói "${detailedPkg.name}" (${_formatVnd(detailedPkg.price)})',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Chọn gói XN',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Tra Cứu Gói Xét Nghiệm (UC20)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (BmsAuth.isReceptionist)
            IconButton(
              tooltip: 'Tạo hồ sơ khách vãng lai (Chỉ Lễ Tân)',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateGuestProfileScreen(),
                  ),
                );
              },
            ),
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () => _executeSearch(resetPage: false),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar & Filter Button Header
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onKeywordChanged,
                    onSubmitted: (_) => _executeSearch(resetPage: true),
                    decoration: InputDecoration(
                      hintText:
                          'Tìm tên gói, mã gói (CBC, HBA1C), chỉ số...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon:
                          const Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _executeSearch(resetPage: true);
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Badge(
                  isLabelVisible: _activeFilterCount > 0,
                  label: Text('$_activeFilterCount'),
                  backgroundColor: AppColors.warning,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _openFilterSheet,
                      child: const Padding(
                        padding: EdgeInsets.all(11),
                        child: Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Category Horizontal Filter Bar
          Container(
            color: Colors.white,
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12.5,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedCategory = cat);
                      _executeSearch(resetPage: true);
                    },
                  ),
                );
              },
            ),
          ),

          // Active Filter Summary Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  'Tìm thấy $_totalCount gói xét nghiệm',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (_activeFilterCount > 0 || _searchCtrl.text.isNotEmpty)
                  InkWell(
                    onTap: _resetAllFilters,
                    child: const Text(
                      'Xóa bộ lọc',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Main Results List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: AppColors.danger,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: () =>
                                    _executeSearch(resetPage: false),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _packages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.search_off_rounded,
                                    size: 54,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Không tìm thấy gói xét nghiệm phù hợp.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Hãy thử từ khóa khác hoặc đặt lại bộ lọc.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  OutlinedButton.icon(
                                    onPressed: _resetAllFilters,
                                    icon: const Icon(Icons.restart_alt),
                                    label: const Text('Đặt lại bộ lọc'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _executeSearch(resetPage: false),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(14),
                              itemCount: _packages.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (ctx, i) {
                                final pkg = _packages[i];
                                final tubeColor = _getTubeColor(pkg.sampleTube);
                                return Card(
                                  elevation: 0,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => _openPackageDetailSheet(pkg),
                                    child: Padding(
                                      padding: const EdgeInsets.all(15),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary
                                                          .withValues(
                                                        alpha: 0.1,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        6,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      pkg.code,
                                                      style: const TextStyle(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 11.5,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFF1F5F9,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        6,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      pkg.category,
                                                      style: const TextStyle(
                                                        color: AppColors
                                                            .textSecondary,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                _formatVnd(pkg.price),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            pkg.name,
                                            style: const TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            pkg.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12.5,
                                              height: 1.35,
                                            ),
                                          ),
                                          if (pkg.criteria.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: pkg.criteria
                                                  .take(4)
                                                  .map(
                                                    (c) => Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFF8FAFC,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                        border: Border.all(
                                                          color:
                                                              AppColors.border,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        c.code,
                                                        style: const TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: AppColors
                                                              .textSecondary,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ],
                                          const Divider(height: 18),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.science_outlined,
                                                size: 15,
                                                color: tubeColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                pkg.sampleTube,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: tubeColor,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              const Icon(
                                                Icons.schedule_outlined,
                                                size: 14,
                                                color: AppColors.textSecondary,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                pkg.tat,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                              const Spacer(),
                                              const Text(
                                                'Chi tiết →',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),

          // Pagination Bar
          if (_totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _page > 1
                        ? () {
                            setState(() => _page--);
                            _executeSearch(resetPage: false);
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('Trước'),
                  ),
                  Text(
                    'Trang $_page / $_totalPages',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _page < _totalPages
                        ? () {
                            setState(() => _page++);
                            _executeSearch(resetPage: false);
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right, size: 18),
                    label: const Text('Sau'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}