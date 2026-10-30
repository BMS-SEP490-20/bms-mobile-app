import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/patient_result_repository.dart';
import '../../models/patient_test_result_model.dart';

/// UC62 — Export Test Results (PDF)
/// Patient mobile test results viewing, PDF export, and physician share screen.
/// Designed strictly adhering to docs-output/screens/08-mobile-patient.html#m-uc62.
class ExportTestResultScreen extends StatefulWidget {
  final String orderId;

  const ExportTestResultScreen({
    super.key,
    this.orderId = 'ORD-260927-0231',
  });

  @override
  State<ExportTestResultScreen> createState() => _ExportTestResultScreenState();
}

class _ExportTestResultScreenState extends State<ExportTestResultScreen> {
  final PatientResultRepository _repository = PatientResultRepository();
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
      final data = await _repository.getPatientResult(widget.orderId);
      if (mounted) {
        setState(() {
          _result = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to load test results. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleExportPdf() async {
    if (_result == null) return;
    setState(() => _isExporting = true);

    try {
      final exportData = await _repository.exportResultPdf(_result!.orderId);
      if (mounted) {
        setState(() => _isExporting = false);
        final fileName = exportData?['fileName'] ?? 'BMS-Result-${_result!.orderCode}.pdf';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Downloaded: $fileName. Saved to device.')),
              ],
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to export PDF. Please check connection.'),
          ),
        );
      }
    }
  }

  Future<void> _handleShare() async {
    if (_result == null) return;
    setState(() => _isSharing = true);

    try {
      final shareData = await _repository.shareResultWithDoctor(_result!.orderId);
      if (mounted) {
        setState(() => _isSharing = false);
        final shareUrl = shareData?['shareUrl'] != null
            ? 'https://bms.health${shareData!['shareUrl']}'
            : 'https://bms.health/results/share?orderId=${_result!.orderId}&token=${_result!.shareToken}';

        _showShareBottomSheet(shareUrl);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSharing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to generate doctor share link.'),
          ),
        );
      }
    }
  }

  void _showShareBottomSheet(String shareUrl) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Share with Doctor',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'This link provides verified, read-only access to this laboratory report for external consulting physicians. Valid for 7 days.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        shareUrl,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF334155)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20, color: Color(0xFF0284C7)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareUrl));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF16A34A),
                            content: Text('Share link copied to clipboard!'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: Color(0xFF166534)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ISO 15189 digitally verified & audit trail logged.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF166534)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          _result?.packageName ?? 'Results',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadResult,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : _result == null
                  ? const Center(child: Text('No results available.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Card 1: Patient Details
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                    children: [
                                      TextSpan(
                                        text: _result!.patientName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                      TextSpan(text: ' · ${_result!.patientId} · ${_result!.dobAgeSex}'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Collected ${_result!.collectionTime} · Approved ${_result!.releasedDate} by ${_result!.approvedByDoctor}',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Card 2: Results Table Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Results',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    if (_result!.abnormalCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '● ${_result!.abnormalCount} abnormal',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ..._result!.parameters.map((p) => _buildResultRow(p)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Card 3: Doctor's Note
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Doctor's note",
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _result!.doctorAssessment,
                                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.45),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '— ${_result!.approvedByDoctor} · ${_result!.doctorSpecialty}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Action Button 1: Export PDF
                          ElevatedButton.icon(
                            onPressed: _isExporting ? null : _handleExportPdf,
                            icon: _isExporting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.download, size: 20),
                            label: Text(_isExporting ? 'Exporting...' : 'Export PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Action Button 2: Share with Doctor
                          OutlinedButton.icon(
                            onPressed: _isSharing ? null : _handleShare,
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: Text(_isSharing ? 'Generating...' : 'Share with doctor'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildResultRow(PatientResultParameter param) {
    final isCrit = param.flag == 'HH' || param.flag == 'LL';
    final isWarn = param.flag == 'H' || param.flag == 'L';

    Color valueColor = const Color(0xFF0F172A);
    if (isCrit) valueColor = const Color(0xFFDC2626);
    if (isWarn) valueColor = const Color(0xFFD97706);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9.0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              param.parameterName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCrit ? FontWeight.bold : FontWeight.w500,
                color: isCrit ? const Color(0xFF991B1B) : const Color(0xFF1E293B),
              ),
            ),
          ),
          Row(
            children: [
              Text(
                param.value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: valueColor,
                ),
              ),
              if (param.flag != 'N') ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isCrit ? const Color(0xFFDC2626) : const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    param.flag,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
