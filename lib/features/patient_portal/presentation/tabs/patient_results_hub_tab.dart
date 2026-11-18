import 'package:flutter/material.dart';
import '../../../../core/network/bms_http_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../../../patient/data/test_history_repository.dart';
import '../../../patient/presentation/screens/export_test_result_screen.dart';
import '../../../patient/presentation/screens/test_history_screen.dart';
import '../../data/patient_portal_api.dart';

/// Tab 3 of PatientShellScreen — Clinical Test Results & 6-Stage Specimen Tracking Hub.
class PatientResultsHubTab extends StatefulWidget {
  final int initialSegment;

  const PatientResultsHubTab({super.key, this.initialSegment = 0});

  @override
  State<PatientResultsHubTab> createState() => _PatientResultsHubTabState();
}

class _PatientResultsHubTabState extends State<PatientResultsHubTab> {
  final PatientPortalApi _api = const PatientPortalApi();
  final TextEditingController _barcodeSearchCtrl = TextEditingController();

  late int _segment = widget.initialSegment;
  List<Map<String, dynamic>> _releasedReports = [];
  List<Map<String, dynamic>> _trackings = [];
  Map<String, dynamic>? _searchedTracking;
  bool _loadingTracking = true;
  String? _trackingError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant PatientResultsHubTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSegment != widget.initialSegment) {
      setState(() => _segment = widget.initialSegment);
    }
  }

  @override
  void dispose() {
    _barcodeSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingTracking = true;
      _trackingError = null;
    });
    try {
      final med = await _api.getMedicalProfile();
      final patId = (med?['id'] ?? BmsAuth.currentUserId).toString();
      final results = await Future.wait<dynamic>([
        _api.getReleasedResults(patId),
        _api.getPatientTrackings(patId),
      ]);
      if (!mounted) return;
      setState(() {
        _releasedReports = results[0] as List<Map<String, dynamic>>;
        _trackings = results[1] as List<Map<String, dynamic>>;
        _loadingTracking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _trackingError = e.toString();
        _loadingTracking = false;
      });
    }
  }

  Future<void> _lookupSingleTracking() async {
    final code = _barcodeSearchCtrl.text.trim();
    if (code.isEmpty) {
      setState(() {
        _searchedTracking = null;
        _trackingError = null;
      });
      return;
    }
    setState(() {
      _loadingTracking = true;
      _trackingError = null;
    });
    try {
      final found = await _api.lookupTrackingByCode(code);
      if (!mounted) return;
      setState(() {
        _searchedTracking = found;
        _loadingTracking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchedTracking = null;
        _trackingError = e.toString();
        _loadingTracking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              children: [
                BmsSegmentedTabs(
                  tabs: const ['Kết quả xét nghiệm', 'Hành trình mẫu máu'],
                  selectedIndex: _segment,
                  onChanged: (idx) => setState(() => _segment = idx),
                ),
              ],
            ),
          ),
          Expanded(
            child: _segment == 0
                ? _buildResultsSegment()
                : _buildSampleTrackingSegment(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSegment() {
    return Column(
      children: [
        if (_releasedReports.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: BmsSoftCard(
              padding: const EdgeInsets.all(14),
              backgroundColor: AppColors.primaryLight,
              borderColor: AppColors.primaryBorder,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phiếu kết quả xuất PDF & Chia sẻ bác sĩ',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _releasedReports.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final r = _releasedReports[idx];
                        final orderId =
                            (r['orderId'] ?? r['orderCode'] ?? r['id'] ?? '')
                                .toString();
                        final pkg =
                            (r['packageName'] ?? orderId).toString();
                        return ActionChip(
                          avatar: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          label: Text(pkg),
                          onPressed: orderId.isEmpty
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ExportTestResultScreen(
                                        orderId: orderId,
                                      ),
                                    ),
                                  );
                                },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: TestHistoryScreen(
            repository: TestHistoryRepository(
              baseUrl: '${BmsHttpClient.resolvedBaseUrl}/api',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSampleTrackingSegment() {
    final displayList = _searchedTracking != null
        ? [_searchedTracking!]
        : _trackings;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          BmsSearchFilterBar(
            controller: _barcodeSearchCtrl,
            hintText: 'Nhập mã Barcode mẫu (SMP-...) hoặc mã phiếu (ORD-...)',
            onSubmitted: (_) => _lookupSingleTracking(),
            onClear: () {
              setState(() {
                _searchedTracking = null;
                _trackingError = null;
              });
            },
            trailing: FilledButton(
              onPressed: _lookupSingleTracking,
              child: const Text('Tra cứu'),
            ),
          ),
          const SizedBox(height: 14),
          if (_loadingTracking)
            const BmsLoadingState(
              message: 'Đang truy xuất hành trình mẫu bệnh phẩm...',
            )
          else if (_trackingError != null)
            BmsErrorState(
              message: _trackingError!,
              onRetry: _searchedTracking != null
                  ? _lookupSingleTracking
                  : _loadData,
            )
          else if (displayList.isEmpty)
            const BmsEmptyState(
              icon: Icons.science_outlined,
              title: 'Chưa có mẫu bệnh phẩm đang theo dõi',
              subtitle:
                  'Bạn có thể nhập mã Barcode trên biên nhận lấy mẫu để tra cứu trực tiếp tiến độ 6 bước.',
            )
          else
            ...displayList.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _SampleTimelineCard(tracking: item),
              ),
            ),
        ],
      ),
    );
  }
}

class _SampleTimelineCard extends StatelessWidget {
  final Map<String, dynamic> tracking;

  const _SampleTimelineCard({required this.tracking});

  @override
  Widget build(BuildContext context) {
    final orderNumber = (tracking['orderNumber'] ?? '').toString();
    final barcode = (tracking['barcode'] ?? '').toString();
    final priority = (tracking['priority'] ?? 'Routine').toString();
    final currentStep =
        ((tracking['currentStepNumber'] as num?)?.toInt() ?? 1).clamp(1, 6);
    final elapsed = (tracking['elapsedMinutes'] as num?)?.round() ?? 0;
    final eta = BmsFormatters.dateTime(tracking['estimatedCompletionTime']);
    final packages = tracking['testPackageNames'] is List
        ? (tracking['testPackageNames'] as List).join(', ')
        : 'Xét nghiệm lâm sàng';
    final rawSteps = tracking['steps'] is List
        ? (tracking['steps'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    return BmsSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  barcode.isNotEmpty ? 'Mẫu: $barcode' : 'Mã đơn: $orderNumber',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              BmsStatusPill(status: priority),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            packages,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Thời gian xử lý (TAT): $elapsed phút · Dự kiến hoàn tất: $eta',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 12),
          ...rawSteps.asMap().entries.map((entry) {
            final idx = entry.key;
            final step = entry.value;
            final stepNum = (step['stepNumber'] as num?)?.toInt() ?? (idx + 1);
            final title = (step['title'] ?? 'Công đoạn $stepNum').toString();
            final desc = (step['description'] ?? '').toString();
            final statusRaw = (step['status'] ?? '').toString().toLowerCase();
            final handler = (step['handlerName'] ?? '').toString();
            final dept = (step['department'] ?? '').toString();
            final ts = step['timestamp'];

            final isDone =
                statusRaw == 'completed' ||
                statusRaw == '2' ||
                stepNum < currentStep;
            final isCurrent =
                statusRaw == 'inprogress' ||
                statusRaw == '1' ||
                stepNum == currentStep;

            final dotColor = isDone
                ? AppColors.success
                : (isCurrent ? AppColors.primary : AppColors.border);

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: dotColor.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(color: dotColor, width: 1.5),
                        ),
                        child: Icon(
                          isDone
                              ? Icons.check_rounded
                              : (isCurrent
                                    ? Icons.sync_rounded
                                    : Icons.circle_outlined),
                          size: 13,
                          color: dotColor,
                        ),
                      ),
                      if (idx < rawSteps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: isDone
                                ? AppColors.success
                                : AppColors.cardBorder,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '$stepNum. $title',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isCurrent || isDone
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isCurrent || isDone
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (ts != null)
                                Text(
                                  BmsFormatters.time(ts),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (handler.isNotEmpty || dept.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              [handler, dept]
                                  .where((s) => s.isNotEmpty)
                                  .join(' · '),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
