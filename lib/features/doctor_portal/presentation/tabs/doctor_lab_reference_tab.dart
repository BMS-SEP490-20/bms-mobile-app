import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../data/doctor_portal_api.dart';

/// Tab 4 — Biochemical Results Lookup & Clinical Reference Interval Evaluator.
class DoctorLabReferenceTab extends StatefulWidget {
  const DoctorLabReferenceTab({super.key});

  @override
  State<DoctorLabReferenceTab> createState() => _DoctorLabReferenceTabState();
}

class _DoctorLabReferenceTabState extends State<DoctorLabReferenceTab> {
  final DoctorPortalApi _api = const DoctorPortalApi();
  final TextEditingController _resultSearchCtrl = TextEditingController();
  final TextEditingController _criteriaSearchCtrl = TextEditingController();

  int _subTab = 0;

  List<Map<String, dynamic>> _results = [];
  bool _loadingResults = true;
  String? _resultsError;

  List<Map<String, dynamic>> _criteria = [];
  String _selectedCategory = '';
  bool _loadingCriteria = false;
  String? _criteriaError;

  static const List<({String key, String label})> _categories = [
    (key: '', label: 'Tất cả'),
    (key: 'Biochemistry', label: 'Sinh hóa'),
    (key: 'Hematology', label: 'Huyết học'),
    (key: 'Immunology', label: 'Miễn dịch'),
    (key: 'Coagulation', label: 'Đông máu'),
  ];

  @override
  void initState() {
    super.initState();
    _loadResults('');
    _loadCriteria();
  }

  @override
  void dispose() {
    _resultSearchCtrl.dispose();
    _criteriaSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadResults(String search) async {
    setState(() {
      _loadingResults = true;
      _resultsError = null;
    });
    try {
      final list = await _api.searchBiochemicalResults(search: search);
      if (!mounted) return;
      setState(() {
        _results = list;
        _loadingResults = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resultsError = e.toString().replaceFirst('BmsApiException: ', '');
        _loadingResults = false;
      });
    }
  }

  Future<void> _loadCriteria() async {
    setState(() {
      _loadingCriteria = true;
      _criteriaError = null;
    });
    try {
      final list = await _api.getLabCriteria(
        search: _criteriaSearchCtrl.text,
        category: _selectedCategory.isEmpty ? null : _selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        _criteria = list;
        _loadingCriteria = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _criteriaError = e.toString().replaceFirst('BmsApiException: ', '');
        _loadingCriteria = false;
      });
    }
  }

  Future<void> _openResultDetail(Map<String, dynamic> summary) async {
    final id = (summary['id'] ?? summary['resultId'] ?? '').toString();
    Map<String, dynamic> detail = summary;
    if (id.isNotEmpty) {
      try {
        detail = await _api.getBiochemicalResultDetail(id);
      } catch (_) {
        detail = summary;
      }
    }
    if (!mounted) return;

    final rawParams =
        detail['parameters'] ?? detail['items'] ?? detail['results'];
    final params = rawParams is List
        ? rawParams
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    final barcode = (detail['sampleBarcode'] ??
            detail['barcode'] ??
            detail['sampleId'] ??
            id)
        .toString();
    final patientName = (detail['patientName'] ?? 'Bệnh nhân').toString();
    final conclusion = (detail['conclusion'] ??
            detail['doctorConclusion'] ??
            detail['notes'] ??
            '')
        .toString();
    final status = (detail['status'] ?? 'Approved').toString();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        maxChildSize: 0.94,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(18),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    patientName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                BmsStatusPill(status: status),
              ],
            ),
            const SizedBox(height: 6),
            BmsInfoRow(label: 'Mã mẫu / Barcode', value: barcode, isMono: true),
            BmsInfoRow(
              label: 'Thời gian trả KQ',
              value: BmsFormatters.dateTime(
                detail['approvedAt'] ?? detail['updatedAt'] ?? detail['createdAt'],
              ),
            ),
            if (conclusion.isNotEmpty) ...[
              const SizedBox(height: 10),
              BmsSoftCard(
                backgroundColor: AppColors.primaryLight,
                borderColor: AppColors.primary.withValues(alpha: 0.25),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kết luận chuyên môn',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conclusion,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Bảng thông số xét nghiệm (${params.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            if (params.isEmpty)
              const BmsEmptyState(
                icon: Icons.science_outlined,
                title: 'Chưa có chi tiết thông số con',
                subtitle: 'Kết quả tổng quát đã ghi nhận trên hệ thống.',
              )
            else
              ...params.map((p) {
                final name = (p['parameterName'] ??
                        p['criterionName'] ??
                        p['testName'] ??
                        p['code'] ??
                        'Chỉ số')
                    .toString();
                final val = (p['value'] ?? p['numericValue'] ?? '—').toString();
                final unit = (p['unit'] ?? '').toString();
                final ref = (p['referenceRange'] ??
                        (p['minLimit'] != null && p['maxLimit'] != null
                            ? '${p['minLimit']} - ${p['maxLimit']}'
                            : '—'))
                    .toString();
                final flag = (p['flag'] ?? p['abnormalFlag'] ?? 'Normal')
                    .toString();

                return BmsSoftCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Tham chiếu: $ref $unit',
                              style: const TextStyle(
                                fontSize: 11.5,
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
                            '$val $unit'.trim(),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 4),
                          BmsStatusPill(status: flag),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _openCriterionIntervals(Map<String, dynamic> criterion) async {
    final code = (criterion['code'] ?? criterion['criterionCode'] ?? '')
        .toString();
    final name = (criterion['name'] ?? code).toString();
    final unit = (criterion['unit'] ?? '').toString();
    if (code.isEmpty) return;

    final intervals = await _api.getCriterionIntervals(code);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$name ($code)',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openQuickEvaluateModal(initialCode: code, unit: unit);
                  },
                  icon: const Icon(Icons.calculate_outlined, size: 17),
                  label: const Text('Đánh giá nhanh'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (intervals.isEmpty)
              const BmsEmptyState(
                icon: Icons.rule_folder_outlined,
                title: 'Chưa cấu hình dải tham chiếu riêng',
                subtitle:
                    'Bạn vẫn có thể dùng công cụ Đánh giá nhanh chỉ số lâm sàng.',
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: intervals.length,
                  itemBuilder: (_, idx) {
                    final iv = intervals[idx];
                    final gender = BmsFormatters.genderVi(
                      (iv['gender'] ?? iv['patientGender'])?.toString(),
                    );
                    final minAge = iv['minAge'] ?? 0;
                    final maxAge = iv['maxAge'] ?? 120;
                    final low = iv['lowerLimit'] ?? iv['normalMin'] ?? '—';
                    final high = iv['upperLimit'] ?? iv['normalMax'] ?? '—';
                    final critLow = iv['criticalLow'];
                    final critHigh = iv['criticalHigh'];

                    return BmsSoftCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Giới tính: $gender · Độ tuổi: $minAge - $maxAge',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          BmsInfoRow(
                            label: 'Giới hạn bình thường',
                            value: '$low - $high $unit'.trim(),
                            isBold: true,
                          ),
                          if (critLow != null || critHigh != null)
                            BmsInfoRow(
                              label: 'Ngưỡng báo động đỏ',
                              value:
                                  '${critLow ?? '—'} / ${critHigh ?? '—'} $unit'
                                      .trim(),
                              valueColor: AppColors.dangerText,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openQuickEvaluateModal({
    String initialCode = 'GLU',
    String unit = '',
  }) async {
    final codeCtrl = TextEditingController(text: initialCode);
    final valCtrl = TextEditingController();
    final ageCtrl = TextEditingController(text: '35');
    String gender = 'Male';
    Map<String, dynamic>? evalResult;
    String? evalError;
    bool evaluating = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Đánh giá nhanh chỉ số sinh hóa - huyết học',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Mã chỉ số *',
                            hintText: 'GLU, HBA1C, WBC...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: valCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Giá trị đo *',
                            suffixText: unit.isNotEmpty ? unit : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ageCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Tuổi bệnh nhân',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: gender,
                          decoration: const InputDecoration(
                            labelText: 'Giới tính',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Male', child: Text('Nam')),
                            DropdownMenuItem(
                              value: 'Female',
                              child: Text('Nữ'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setSheetState(() => gender = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: evaluating
                        ? null
                        : () async {
                            final numVal = double.tryParse(valCtrl.text.trim());
                            final age =
                                double.tryParse(ageCtrl.text.trim()) ?? 35;
                            final code = codeCtrl.text.trim();
                            if (code.isEmpty || numVal == null) {
                              setSheetState(() {
                                evalError =
                                    'Vui lòng nhập mã chỉ số và giá trị số hợp lệ.';
                              });
                              return;
                            }
                            setSheetState(() {
                              evaluating = true;
                              evalError = null;
                            });
                            try {
                              final res = await _api.evaluateCriterionValue(
                                criterionCode: code,
                                numericValue: numVal,
                                patientAge: age,
                                patientGender: gender,
                              );
                              setSheetState(() {
                                evalResult = res;
                                evaluating = false;
                              });
                            } catch (e) {
                              setSheetState(() {
                                evalError = e
                                    .toString()
                                    .replaceFirst('BmsApiException: ', '');
                                evaluating = false;
                              });
                            }
                          },
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: Text(
                      evaluating
                          ? 'Đang đối chiếu...'
                          : 'Đối chiếu dải tham chiếu',
                    ),
                  ),
                  if (evalError != null) ...[
                    const SizedBox(height: 12),
                    BmsErrorState(message: evalError!),
                  ],
                  if (evalResult != null) ...[
                    const SizedBox(height: 14),
                    BmsSoftCard(
                      backgroundColor: AppColors.surfaceMuted,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Kết quả phân loại lâm sàng',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              BmsStatusPill(
                                status: (evalResult!['flag'] ??
                                        evalResult!['classification'] ??
                                        'Normal')
                                    .toString(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          BmsInfoRow(
                            label: 'Dải bình thường',
                            value: (evalResult!['referenceRange'] ??
                                    '${evalResult!['lowerLimit'] ?? '—'} - ${evalResult!['upperLimit'] ?? '—'}')
                                .toString(),
                          ),
                          if (evalResult!['interpretation'] != null ||
                              evalResult!['message'] != null)
                            BmsInfoRow(
                              label: 'Nhận định',
                              value: (evalResult!['interpretation'] ??
                                      evalResult!['message'])
                                  .toString(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        BmsPageHeaderCard(
          icon: Icons.science_rounded,
          badgeText: 'Hỗ trợ quyết định lâm sàng',
          title: 'Tra cứu XN & Tham chiếu',
          subtitle:
              'Tra cứu kết quả sinh hóa theo mã vạch mẫu và đối chiếu ngưỡng sinh học',
          trailing: IconButton(
            tooltip: 'Đánh giá nhanh chỉ số',
            onPressed: () => _openQuickEvaluateModal(),
            icon: const Icon(Icons.calculate_outlined, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 14),
        BmsSegmentedTabs(
          tabs: const ['Kết quả sinh hóa', 'Chỉ số & Dải tham chiếu'],
          selectedIndex: _subTab,
          onChanged: (idx) => setState(() => _subTab = idx),
        ),
        const SizedBox(height: 14),
        if (_subTab == 0) _buildBiochemResultsTab() else _buildCriteriaTab(),
      ],
    );
  }

  Widget _buildBiochemResultsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BmsSearchFilterBar(
          controller: _resultSearchCtrl,
          hintText: 'Nhập mã barcode mẫu, mã phiếu hoặc tên bệnh nhân...',
          onSubmitted: _loadResults,
          onClear: () => _loadResults(''),
          trailing: FilledButton(
            onPressed: () => _loadResults(_resultSearchCtrl.text),
            child: const Text('Tra cứu'),
          ),
        ),
        const SizedBox(height: 14),
        if (_loadingResults)
          const BmsLoadingState(message: 'Đang truy xuất kết quả xét nghiệm...')
        else if (_resultsError != null)
          BmsErrorState(
            message: _resultsError!,
            onRetry: () => _loadResults(_resultSearchCtrl.text),
          )
        else if (_results.isEmpty)
          const BmsEmptyState(
            icon: Icons.biotech_outlined,
            title: 'Không có kết quả phù hợp',
            subtitle: 'Kiểm tra lại mã vạch ống nghiệm hoặc họ tên bệnh nhân.',
          )
        else
          ..._results.map((r) {
            final patientName = (r['patientName'] ?? 'Bệnh nhân').toString();
            final barcode = (r['sampleBarcode'] ??
                    r['barcode'] ??
                    r['orderNumber'] ??
                    r['id'] ??
                    '—')
                .toString();
            final pkg = (r['packageName'] ?? r['testName'] ?? 'Xét nghiệm lâm sàng')
                .toString();
            final status = (r['status'] ?? 'Approved').toString();
            final hasAbnormal =
                r['hasAbnormal'] == true || r['hasCritical'] == true;

            return BmsSoftCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              onTap: () => _openResultDetail(r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          patientName,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (hasAbnormal) ...[
                        const BmsStatusPill(
                          status: 'High',
                          customLabel: 'Có bất thường',
                        ),
                        const SizedBox(width: 6),
                      ],
                      BmsStatusPill(status: status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pkg,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mã mẫu: $barcode · ${BmsFormatters.dateTime(r['approvedAt'] ?? r['createdAt'])}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCriteriaTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BmsSearchFilterBar(
          controller: _criteriaSearchCtrl,
          hintText: 'Tìm mã chỉ số (GLU, CREA, WBC, PLT...)',
          onSubmitted: (_) => _loadCriteria(),
          onClear: _loadCriteria,
          trailing: FilledButton.tonalIcon(
            onPressed: () => _openQuickEvaluateModal(),
            icon: const Icon(Icons.calculate_outlined, size: 17),
            label: const Text('Đánh giá'),
          ),
          filterChips: _categories.map((cat) {
            return BmsFilterChipItem(
              key: cat.key,
              label: cat.label,
              selected: _selectedCategory == cat.key,
              onSelected: () {
                setState(() => _selectedCategory = cat.key);
                _loadCriteria();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        if (_loadingCriteria)
          const BmsLoadingState(message: 'Đang tải danh mục chỉ số xét nghiệm...')
        else if (_criteriaError != null)
          BmsErrorState(message: _criteriaError!, onRetry: _loadCriteria)
        else if (_criteria.isEmpty)
          const BmsEmptyState(
            icon: Icons.rule_outlined,
            title: 'Không tìm thấy chỉ số xét nghiệm',
            subtitle: 'Thử chọn nhóm chuyên khoa khác hoặc nhấn Đánh giá nhanh.',
          )
        else
          ..._criteria.map((c) {
            final code = (c['code'] ?? c['criterionCode'] ?? '').toString();
            final name = (c['name'] ?? code).toString();
            final unit = (c['unit'] ?? '').toString();
            final cat = (c['category'] ?? 'Laboratory').toString();

            return BmsSoftCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              onTap: () => _openCriterionIntervals(c),
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
                      code,
                      style: const TextStyle(
                        fontSize: 12.5,
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
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          unit.isNotEmpty
                              ? 'Nhóm: $cat · Đơn vị: $unit'
                              : 'Nhóm: $cat',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
