import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/catalog_repository.dart';
import '../../models/test_package_model.dart';

/// Service Catalog screen (UC01 – Mobile).
///
/// Role: All. Patients and guests can browse laboratory packages,
/// filter by category, search, and tap the Book button (placeholder for UC21).
class ServiceCatalogScreen extends StatefulWidget {
  /// Repository (injectable for testing).
  final CatalogRepository? repository;

  /// Creates the catalog screen.
  const ServiceCatalogScreen({super.key, this.repository});

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen> {
  late final CatalogRepository _repo;
  List<TestPackageModel> _packages = [];
  List<String> _categories = [];
  String _selectedCategory = '';
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String? _error;

  final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? CatalogRepository();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (widget.repository == null) {
      _repo.dispose();
    }
    super.dispose();
  }

  /// Calls the API to load the catalog.
  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _repo.getServiceCatalog(
        category: _selectedCategory.isEmpty ? null : _selectedCategory,
        search: _search.isEmpty ? null : _search,
      );
      if (!mounted) return;
      setState(() {
        _packages = result.packages;
        _categories = result.categories;
        _loading = false;
      });
    } on CatalogException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _packages = [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unexpected error: $e';
        _loading = false;
        _packages = [];
      });
    }
  }

  void _onCategorySelected(String category) {
    setState(() => _selectedCategory = category);
    _loadCatalog();
  }

  void _onSearch() {
    setState(() => _search = _searchController.text.trim());
    _loadCatalog();
  }

  void _onBook(TestPackageModel pkg) {
    // Placeholder – UC21 Book Appointment will be implemented later.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Book: ${pkg.packageName}\n(Book Appointment feature – UC21)',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  /// Header with title and stats.
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('🩸', style: TextStyle(fontSize: 28)),
              SizedBox(width: 8),
              Text(
                'Laboratory Services',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Accurate & fast blood testing',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statItem('99.9%', 'Accuracy'),
                const SizedBox(width: 28),
                _statItem('2-4h', 'Turnaround'),
                const SizedBox(width: 28),
                _statItem('24/7', 'Support'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2563EB),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  /// Filter chips and search bar.
  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip('All', _selectedCategory.isEmpty, () => _onCategorySelected('')),
                ..._categories.map(
                  (c) => _chip(c, _selectedCategory == c, () => _onCategorySelected(c)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search packages...',
                    hintStyle: const TextStyle(fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onSubmitted: (_) => _onSearch(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _onSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Search'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2563EB) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: active ? null : Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  /// Body: loading / error / list.
  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loadCatalog,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_packages.isEmpty) {
      return const Center(
        child: Text(
          'No matching service packages found.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCatalog,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _packages.length,
        itemBuilder: (context, index) => _buildPackageCard(_packages[index]),
      ),
    );
  }

  /// Card for a single package.
  Widget _buildPackageCard(TestPackageModel pkg) {
    final accent = _categoryColor(pkg.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient header
          Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              gradient: LinearGradient(
                colors: [accent.withOpacity(0.15), accent.withOpacity(0.35)],
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: Text('🔬', style: TextStyle(fontSize: 22))),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      pkg.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pkg.packageName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  pkg.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Tube: ${pkg.sampleTube}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    const Spacer(),
                    if (pkg.sampleVolumeMl > 0)
                      Text(
                        '${pkg.sampleVolumeMl} ml',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      _currencyFormat.format(pkg.price),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _onBook(pkg),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: const Text('Book', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Huyết học':
        return const Color(0xFFE11D48);
      case 'Sinh hóa':
        return const Color(0xFF2563EB);
      case 'Miễn dịch':
        return const Color(0xFF7C3AED);
      case 'Đông máu':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF0EA5E9);
    }
  }
}