import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/test_result_verification_repository.dart';
import '../../models/test_result_verification_model.dart';

/// UC72 — Verify Test Results (Mobile)
/// Laboratory technical supervisor screen for verifying specimen results before doctor approval.
class VerifyTestResultsScreen extends StatefulWidget {
  final String specimenId;

  const VerifyTestResultsScreen({
    super.key,
    this.specimenId = 'SPC-261006-A1-0089',
  });

  @override
  State<VerifyTestResultsScreen> createState() => _VerifyTestResultsScreenState();
}

class _VerifyTestResultsScreenState extends State<VerifyTestResultsScreen> {
  final TestResultVerificationRepository _repository = TestResultVerificationRepository();
  TestResultVerificationDetailModel? _detail;
  late TextEditingController _commentController;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(
      text: "Results verified. LDL confirmed on repeat at 3.95. QC flag QCF-1142 under investigation but does not affect this specimen's validity — Levey-Jennings within control for HDL/TC/TG. Ready for doctor approval.",
    );
    _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _repository.fetchVerificationDetails(widget.specimenId);
      if (mounted) {
        setState(() {
          _detail = res;
          if (res?.verifierComment != null && res!.verifierComment.isNotEmpty) {
            _commentController.text = res.verifierComment;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load verification checklist.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleVerify() async {
    final comment = _commentController.text.trim();
    if (comment.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verifier comment must be at least 10 characters long.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final success = await _repository.verifyTestResult(widget.specimenId, comment);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test results verified and forwarded to doctor approval!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to verify test results. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReturnDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment_return, color: Colors.orange),
            SizedBox(width: 8),
            Text('Return for Correction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specify corrective action required for specimen ${widget.specimenId}:',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'e.g., Delta check variance exceeds tolerance; please repeat assay...',
                border: OutlineInputBorder(),
                helperText: 'Minimum 10 characters',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.length < 10) return;
              Navigator.of(ctx).pop();

              setState(() => _isSubmitting = true);
              final success = await _repository.returnTestResult(widget.specimenId, reason);
              if (mounted) {
                setState(() => _isSubmitting = false);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Specimen returned to lab technician for correction.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  _loadData();
                }
              }
            },
            child: const Text('Confirm Return', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, String statusType) {
    Color bg;
    Color fg;

    switch (status.toLowerCase()) {
      case 'flag':
        bg = Colors.amber.shade100;
        fg = Colors.orange.shade900;
        break;
      case 'ok':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'confirmed':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.black87;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final specimenId = widget.specimenId;
    final isVerified = _detail?.status == 'Verified';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify test results', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(_errorMessage!),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Specimen Summary Card
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    specimenId,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isVerified ? Colors.green.shade100 : Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _detail?.status ?? 'Pending',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isVerified ? Colors.green.shade900 : Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_detail?.packageName ?? "Lipid Profile"} · Order: ${_detail?.orderId ?? "ORD-261006-0187"}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Patient: ${_detail?.patientName ?? "Nguyễn Văn An"} (${_detail?.patientId ?? "PT-2026-004523"})',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Verification Checklist Card
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Verification Checklist',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  if ((_detail?.flagCount ?? 0) > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${_detail!.flagCount} flags',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const Divider(height: 24),
                              ...((_detail?.checklist ?? []).map((item) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.checkName,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.details,
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatusBadge(item.status, item.statusType),
                                    ],
                                  ),
                                );
                              })),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Verifier Comment
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Verifier Comment',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _commentController,
                                maxLines: 4,
                                enabled: !isVerified && !_isSubmitting,
                                decoration: const InputDecoration(
                                  hintText: 'Enter clinical verification comments...',
                                  border: OutlineInputBorder(),
                                  helperText: 'Audit-logged in ISO 15189 compliance trail',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isVerified || _isSubmitting ? null : _handleVerify,
                        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                        label: Text(
                          isVerified ? 'Verified & Sent to Doctor' : 'Verify and send to doctor',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade800,
                          side: BorderSide(color: Colors.orange.shade800),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isVerified || _isSubmitting ? null : _showReturnDialog,
                        icon: const Icon(Icons.undo),
                        label: const Text(
                          'Return to lab tech for correction',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}
