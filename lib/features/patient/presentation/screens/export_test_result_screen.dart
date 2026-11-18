import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../../../patient_portal/data/patient_portal_api.dart';
import '../../data/patient_result_repository.dart';
import '../../models/patient_test_result_model.dart';

/// Clinical Laboratory Report View, PDF Export & Doctor Share Link Screen.
class ExportTestResultScreen extends StatefulWidget {
  final String orderId;

  const ExportTestResultScreen({super.key, this.orderId = ''});

  @override
  State<ExportTestResultScreen> createState() => _ExportTestResultScreenState();
}

class _ExportTestResultScreenState extends State<ExportTestResultScreen> {
  final PatientResultRepository _repository = PatientResultRepository();
  final PatientPortalApi _patientApi = const PatientPortalApi();

  PatientTestResultModel? _result;
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isSharing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadResult();
  }

  Future<void> _loadResult() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String targetOrderId = widget.orderId.trim();
      if (targetOrderId.isEmpty) {
        final med = await _patientApi.getMedicalProfile();
        final patId = (med?['id'] ?? BmsAuth.currentUserId).toString();
        if (patId.isNotEmpty) {
          final list = await _patientApi.getReleasedResults(patId);
          if (list.isNotEmpty) {
            targetOrderId =
                (list.first['orderId'] ?? list.first['orderCode'] ?? '')
                    .toString();
          }
        }
      }

      if (targetOrderId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _result = null;
          _isLoading = false;
        });
        return;
      }

      final data = await _repository.getPatientResult(targetOrderId);
      if (!mounted) return;
      setState(() {
        _result = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải phiếu kết quả xét nghiệm lúc này.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleExportPdf() async {
    if (_result == null) return;
    setState(() => _isExporting = true);
    try {
      final exportData = await _repository.exportResultPdf(_result!.orderId);
      if (!mounted) return;
      setState(() => _isExporting = false);
      final fileName =
          exportData?['fileName'] ?? 'BMS-KetQua-${_result!.orderCode}.pdf';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Đã xuất tệp PDF kết quả: $fileName'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Không thể xuất PDF kết quả xét nghiệm.'),
        ),
      );
    }
  }

  Future<void> _handleShare() async {
    if (_result == null) return;
    setState(() => _isSharing = true);
    try {
      final shareData = await _repository.shareResultWithDoctor(
        _result!.orderId,
      );
      if (!mounted) return;
      setState(() => _isSharing = false);
      final shareUrl = (shareData?['shareUrl'] ?? _result!.shareUrl).toString();
      final resolvedUrl = shareUrl.startsWith('http')
          ? shareUrl
          : 'https://bms.med.vn$shareUrl';
      _showShareSheet(resolvedUrl);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Không thể tạo liên kết chia sẻ cho bác sĩ.'),
        ),
      );
    }
  }

  void _showShareSheet(String shareUrl) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Chia sẻ kết quả cho bác sĩ tư vấn',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Liên kết chỉ cho phép xem kết quả được xác thực và tự động hết hạn sau 7 ngày.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            BmsSoftCard(
              backgroundColor: AppColors.surfaceMuted,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      shareUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sao chép liên kết',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareUrl));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép liên kết vào bộ nhớ tạm.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 19),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_result?.packageName ?? 'Phiếu kết quả xét nghiệm'),
      ),
      body: _isLoading
          ? const BmsLoadingState(message: 'Đang tải phiếu kết quả lâm sàng...')
          : _errorMessage != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: BmsErrorState(
                    message: _errorMessage!,
                    onRetry: _loadResult,
                  ),
                )
              : _result == null
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: BmsEmptyState(
                        icon: Icons.biotech_outlined,
                        title: 'Chưa có phiếu kết quả được công bố',
                        subtitle:
                            'Kết quả sẽ hiển thị ngay sau khi bác sĩ chuyên khoa phê duyệt.',
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        BmsSoftCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _result!.patientName,
                                      style: const TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  BmsStatusPill(status: _result!.overallStatus),
                                ],
                              ),
                              const SizedBox(height: 8),
                              BmsInfoRow(
                                label: 'Mã phiếu XN',
                                value: _result!.orderCode,
                                isMono: true,
                              ),
                              BmsInfoRow(
                                label: 'Bác sĩ duyệt',
                                value: _result!.approvedByDoctor,
                              ),
                              BmsInfoRow(
                                label: 'Ngày trả KQ',
                                value: _result!.releasedDate.isEmpty
                                    ? 'Đã phát hành'
                                    : _result!.releasedDate,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _isExporting
                                          ? null
                                          : _handleExportPdf,
                                      icon: const Icon(
                                        Icons.picture_as_pdf_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _isExporting
                                            ? 'Đang xuất...'
                                            : 'Tải phiếu PDF',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          _isSharing ? null : _handleShare,
                                      icon: const Icon(
                                        Icons.share_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Chia sẻ BS'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (_result!.doctorAssessment.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          BmsSoftCard(
                            backgroundColor: AppColors.primaryLight,
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nhận định chuyên môn của bác sĩ',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _result!.doctorAssessment,
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
                          'Chỉ số chi tiết (${_result!.parameters.length})',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._result!.parameters.map((p) {
                          return BmsSoftCard(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(13),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.parameterName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tham chiếu: ${p.referenceRange} ${p.unit}',
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
                                      '${p.value} ${p.unit}'.trim(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    BmsStatusPill(status: p.flag),
                                  ],
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
