import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/sample_origin_trace_repository.dart';
import '../../models/sample_origin_trace_model.dart';

/// UC77 — Trace Sample Origin (Mobile)
/// Mobile screen for viewing complete specimen lineage and chain of custody audit trail.
class TraceSampleOriginScreen extends StatefulWidget {
  final String specimenId;

  const TraceSampleOriginScreen({
    super.key,
    this.specimenId = 'SPC-261006-A1-0089',
  });

  @override
  State<TraceSampleOriginScreen> createState() => _TraceSampleOriginScreenState();
}

class _TraceSampleOriginScreenState extends State<TraceSampleOriginScreen> {
  final SampleOriginTraceRepository _repository = SampleOriginTraceRepository();
  late TextEditingController _searchController;
  SampleOriginTraceModel? _trace;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.specimenId);
    _loadTrace(widget.specimenId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrace(String barcode) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _repository.fetchOriginTrace(barcode);
      if (mounted) {
        setState(() {
          _trace = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load trace for specimen.';
          _isLoading = false;
        });
      }
    }
  }

  Color _getBadgeColor(String badgeType) {
    switch (badgeType) {
      case 'patient':
        return Colors.purple.shade700;
      case 'doctor':
      case 'order':
        return Colors.blue.shade700;
      case 'warn':
        return Colors.orange.shade800;
      case 'err':
        return Colors.red.shade700;
      case 'ok':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Color _getBadgeBg(String badgeType) {
    switch (badgeType) {
      case 'patient':
        return Colors.purple.shade50;
      case 'doctor':
      case 'order':
        return Colors.blue.shade50;
      case 'warn':
        return Colors.orange.shade50;
      case 'err':
        return Colors.red.shade50;
      case 'ok':
        return Colors.green.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trace sample origin', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barcode Search Bar
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: 'Enter specimen barcode...',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) _loadTrace(val.trim());
                        },
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () {
                        final val = _searchController.text.trim();
                        if (val.isNotEmpty) _loadTrace(val);
                      },
                      child: const Text('Trace'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(_errorMessage!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _loadTrace(_searchController.text.trim()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Specimen Header Card
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
                            _trace?.specimenId ?? '',
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
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '● ${_trace?.custody.integrity ?? "Unbroken"}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Patient: ${_trace?.patientName ?? "Nguyễn Văn An"} (${_trace?.patientId ?? "PT-004523"})',
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      Text(
                        'Order: ${_trace?.orderId ?? "ORD-261006-0187"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Visual Lineage Flow
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lineage Trace Graph',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Divider(height: 24),
                      ...((_trace?.nodes ?? []).map((node) {
                        final fg = _getBadgeColor(node.badgeType);
                        final bg = _getBadgeBg(node.badgeType);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 75,
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  node.nodeType,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: fg,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      node.title,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    Text(
                                      node.subtitle,
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                            ],
                          ),
                        );
                      })),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Chain of Custody Metrics
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chain of Custody',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Divider(height: 24),
                      _buildMetricRow('Integrity', _trace?.custody.integrity ?? 'Unbroken'),
                      _buildMetricRow('Barcode Scans', '${_trace?.custody.barcodeScansCount ?? 7} events'),
                      _buildMetricRow('Transport', _trace?.custody.transportDuration ?? '12 min'),
                      _buildMetricRow('Analyzer', _trace?.custody.analyzerModel ?? 'BC-01'),
                      _buildMetricRow('Reagent Lot', _trace?.custody.reagentLot ?? 'LOT-7721'),
                      _buildMetricRow('QC Status', _trace?.custody.qcStatus ?? 'QCF-1142'),
                      _buildMetricRow('Reruns', '${_trace?.custody.rerunCount ?? 1} (confirmed)'),
                      _buildMetricRow('Notes', '${_trace?.custody.notesCount ?? 3} attached'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Export PDF Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Chain of custody certificate exported for ${_trace?.specimenId}!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.download, color: AppColors.primary),
                label: const Text(
                  'Export trace report (PDF)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
