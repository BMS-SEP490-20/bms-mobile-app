import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../../../patient/presentation/screens/export_test_result_screen.dart';
import '../../data/patient_portal_api.dart';

/// Clean Flat 2-Segment Patient Results & Sample Tracking Hub (ZERO nested AppBars!):
/// - Segment 0: Tiến trình 6 bước mẫu máu (`GET /api/tracking/patient/{pid}` + quick barcode lookup)
/// - Segment 1: Lịch sử & Phiếu KQ PDF A4 (`GET /api/v1/test-history` + `/api/test-results/patient/{pid}`)
class PatientResultsHubTab extends StatefulWidget {
  final int initialSegment;

  const PatientResultsHubTab({super.key, this.initialSegment = 0});

  @override
  State<PatientResultsHubTab> createState() => _PatientResultsHubTabState();
}

class _PatientResultsHubTabState extends State<PatientResultsHubTab> {
  final PatientPortalApi _api = const PatientPortalApi();
  final TextEditingController _codeCtrl = TextEditingController();

  late int _segment = widget.initialSegment;
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _trackings = [];
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PatientResultsHubTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSegment != oldWidget.initialSegment) {
      setState(() => _segment = widget.initialSegment);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _api.getMedicalProfile().catchError((_) => null);
      final pid =
          (profile?['patientCode'] ?? profile?['id'] ?? BmsAuth.currentUserId)
              .toString();
      final results = await Future.wait([
        _api.getPatientTrackings(pid),
        _api.getTestHistory(patientId: pid, pageSize: 30),
        _api.getReleasedResults(pid),
      ]);
      if (!mounted) return;

      final hist = results[1];
      final released = results[2];

      // Merge history + released results cleanly without duplicates
      final seen = <String>{};
      final mergedHistory = <Map<String, dynamic>>[];
      for (final item in [...hist, ...released]) {
        final key =
            (item['resultCode'] ??
                    item['orderId'] ??
                    item['OrderId'] ??
                    item['id'] ??
                    '')
                .toString()
                .trim();
        if (key.isEmpty || seen.add(key.toLowerCase())) {
          mergedHistory.add(item);
        }
      }

      setState(() {
        _trackings = results[0];
        _history = mergedHistory;
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

  Future<void> _lookupManualBarcode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    try {
      final data = await _api.lookupTrackingByCode(code);
      if (!mounted) return;
      _showTrackingDetailModal(data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
      );
    }
  }

  void _showTrackingDetailModal(Map<String, dynamic> tr) {
    final stages = (tr['stages'] ?? tr['timeline'] ?? const []) as List<dynamic>;
    final orderId = (tr['orderId'] ?? tr['orderNumber'] ?? tr['id'] ?? '').toString();
    final overall = (tr['overallStatus'] ?? tr['status'] ?? '').toString();
    final completed = overall.toLowerCase() == 'completed' ||
        overall.toLowerCase() == 'released';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      orderId,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  BmsStatusPill(status: overall),
                ],
              ),
              const Divider(height: 22),
              ...stages.whereType<Map>().map((raw) {
                final s = Map<String, dynamic>.from(raw);
                final st = (s['status'] ?? '').toString().toLowerCase();
                final done = st == 'completed' || st == 'done' || s['isCompleted'] == true;
                final active = st == 'inprogress' || st == 'active';
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
                        size: 20,
                        color: done
                            ? AppColors.success
                            : active
                            ? AppColors.primary
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (s['stageName'] ?? s['title'] ?? s['name'] ?? 'Giai đoạn')
                                  .toString(),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight:
                                    done || active ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            if ((s['completedAt'] ?? s['timestamp']) != null)
                              Text(
                                BmsFormatters.dateTime(
                                  s['completedAt'] ?? s['timestamp'],
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
              if (completed && orderId.isNotEmpty) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExportTestResultScreen(orderId: orderId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Mở Phiếu Kết Quả & Xuất PDF A4'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const BmsPageHeaderCard(
            icon: Icons.biotech_rounded,
            badgeText: 'KẾT QUẢ & TIẾN TRÌNH MẪU',
            title: 'Theo dõi & Phiếu Kết Quả',
            subtitle:
                'Xem tiến trình xử lý mẫu 6 bước và xuất phiếu kết quả PDF khổ A4 chuẩn y khoa',
          ),
          const SizedBox(height: 12),
          BmsSegmentedTabs(
            tabs: [
              'Tiến trình mẫu (${_trackings.length})',
              'Lịch sử & PDF (${_history.length})',
            ],
            selectedIndex: _segment,
            onChanged: (idx) => setState(() => _segment = idx),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const BmsLoadingState(message: 'Đang tải dữ liệu xét nghiệm...')
          else if (_error != null)
            BmsErrorState(message: _error!, onRetry: _load)
          else if (_segment == 0)
            _buildTrackingList()
          else
            _buildHistoryList(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTrackingList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BmsSoftCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  onSubmitted: (_) => _lookupManualBarcode(),
                  decoration: const InputDecoration(
                    hintText: 'Tra nhanh mã Barcode / Mã đơn...',
                    prefixIcon: Icon(Icons.qr_code_rounded, size: 19),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _lookupManualBarcode,
                child: const Text('Tra'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_trackings.isEmpty)
          const BmsEmptyState(
            icon: Icons.track_changes_rounded,
            title: 'Chưa có mẫu đang theo dõi',
            subtitle:
                'Khi lễ tân check-in và dán barcode mẫu máu, tiến trình 6 bước sẽ hiện trực tiếp tại đây.',
          )
        else
          ..._trackings.map((tr) {
            final code =
                (tr['orderNumber'] ?? tr['orderId'] ?? tr['barcode'] ?? 'Mẫu XN')
                    .toString();
            final pkg = (tr['packageName'] ?? tr['testName'] ?? 'Xét nghiệm')
                .toString();
            final overall = (tr['overallStatus'] ?? tr['status'] ?? 'InProgress')
                .toString();
            return BmsSoftCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              onTap: () => _showTrackingDetailModal(tr),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          code,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      BmsStatusPill(status: overall),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pkg,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Chạm để xem chi tiết tiến trình 6 giai đoạn →',
                    style: TextStyle(
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

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return const BmsEmptyState(
        icon: Icons.description_outlined,
        title: 'Chưa có lịch sử kết quả xét nghiệm',
        subtitle:
            'Các phiếu kết quả sau khi Bác sĩ ký duyệt điện tử sẽ hiển thị đầy đủ tại đây.',
      );
    }

    return Column(
      children: _history.map((item) {
        final orderId =
            (item['resultCode'] ??
                    item['orderId'] ??
                    item['OrderId'] ??
                    item['id'] ??
                    '')
                .toString();
        final pkgName =
            (item['packageName'] ??
                    item['PackageName'] ??
                    item['testName'] ??
                    'Phiếu Kết Quả Xét Nghiệm')
                .toString();
        final status =
            (item['overallStatus'] ??
                    item['OverallStatus'] ??
                    item['status'] ??
                    'Completed')
                .toString();
        final dateRaw =
            item['releasedDate'] ??
            item['ReleasedDate'] ??
            item['orderDate'] ??
            item['createdAt'];

        return BmsSoftCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      orderId,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  BmsStatusPill(status: status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                pkgName,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              BmsInfoRow(
                label: 'Ngày phát hành',
                value: BmsFormatters.dateTime(dateRaw),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: orderId.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ExportTestResultScreen(orderId: orderId),
                          ),
                        ),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('Xem Phiếu Kết Quả & Xuất PDF A4'),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
