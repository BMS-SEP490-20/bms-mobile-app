import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../patient_portal/data/patient_portal_api.dart';

/// Specimen Barcode & Chain-of-Custody Tracking Screen backed by real `GET /api/tracking/{identifier}`.
class TraceSampleOriginScreen extends StatefulWidget {
  final String initialBarcode;

  const TraceSampleOriginScreen({super.key, this.initialBarcode = ''});

  @override
  State<TraceSampleOriginScreen> createState() =>
      _TraceSampleOriginScreenState();
}

class _TraceSampleOriginScreenState extends State<TraceSampleOriginScreen> {
  final PatientPortalApi _api = const PatientPortalApi();
  late final TextEditingController _barcodeCtrl = TextEditingController(
    text: widget.initialBarcode,
  );

  Map<String, dynamic>? _trackingData;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode.trim().isNotEmpty) {
      _traceSample(widget.initialBarcode.trim());
    }
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _traceSample(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.lookupTrackingByCode(trimmed);
      if (!mounted) return;
      setState(() {
        _trackingData = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _trackingData = null;
        _error = e.toString().replaceFirst('BmsApiException: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _trackingData?['steps'] is List
        ? (_trackingData!['steps'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Tra cứu hành trình mẫu máu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BmsSearchFilterBar(
            controller: _barcodeCtrl,
            hintText: 'Nhập mã barcode ống nghiệm hoặc mã đơn ORD-...',
            onSubmitted: _traceSample,
            trailing: FilledButton(
              onPressed: () => _traceSample(_barcodeCtrl.text),
              child: const Text('Tra cứu'),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const BmsLoadingState(message: 'Đang truy xuất chuỗi hành trình mẫu...')
          else if (_error != null)
            BmsErrorState(
              message: _error!,
              onRetry: () => _traceSample(_barcodeCtrl.text),
            )
          else if (_trackingData == null)
            const BmsEmptyState(
              icon: Icons.qr_code_2_rounded,
              title: 'Nhập mã vạch mẫu để tra cứu',
              subtitle:
                  'Theo dõi trực tiếp 6 công đoạn xử lý mẫu từ lúc lấy máu đến khi duyệt kết quả.',
            )
          else ...[
            BmsSoftCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (_trackingData!['barcode'] ??
                                  _trackingData!['orderCode'] ??
                                  'Mẫu xét nghiệm')
                              .toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      BmsStatusPill(
                        status: (_trackingData!['currentStatus'] ?? 'InProgress')
                            .toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_trackingData!['patientName'] != null)
                    BmsInfoRow(
                      label: 'Bệnh nhân',
                      value: _trackingData!['patientName'].toString(),
                      isBold: true,
                    ),
                  if (_trackingData!['packageName'] != null)
                    BmsInfoRow(
                      label: 'Gói xét nghiệm',
                      value: _trackingData!['packageName'].toString(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...steps.map((s) {
              final done = s['isCompleted'] == true || s['completed'] == true;
              final title =
                  (s['title'] ?? s['stageName'] ?? 'Công đoạn xử lý').toString();
              final handler = (s['handlerName'] ?? s['performedBy'] ?? '')
                  .toString();
              final ts = BmsFormatters.dateTime(s['timestamp'] ?? s['completedAt']);

              return BmsSoftCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Icon(
                      done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: done ? AppColors.success : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: done
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          if (done)
                            Text(
                              '${handler.isNotEmpty ? '$handler · ' : ''}$ts',
                              style: const TextStyle(
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
            }),
          ],
        ],
      ),
    );
  }
}
