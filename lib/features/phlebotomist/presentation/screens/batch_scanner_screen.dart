import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Specimen Batch Position Model for ISO 15189 Rack Scanner.
class MobileBatchPosition {
  final String coordinate;
  final String? barcode;
  final String? patientName;
  final bool isIqcControl;
  final String? iqcLevel;
  final bool isStat;

  MobileBatchPosition({
    required this.coordinate,
    this.barcode,
    this.patientName,
    this.isIqcControl = false,
    this.iqcLevel,
    this.isStat = false,
  });
}

/// Mobile Test Batch Management & Barcode Rack Scanner Screen (UC38 / Iteration 2).
/// Follows ISO 15189 IQC Controls layout & Safe Rollback workflow.
class BatchScannerScreen extends StatefulWidget {
  const BatchScannerScreen({super.key});

  @override
  State<BatchScannerScreen> createState() => _BatchScannerScreenState();
}

class _BatchScannerScreenState extends State<BatchScannerScreen> {
  final TextEditingController _barcodeInputController = TextEditingController();

  final String _selectedAnalyzer = 'Roche Cobas 6000 (Hóa sinh)';
  final int _trayCapacity = 48; // 6 rows x 8 cols
  String _batchStatus = 'Pending'; // 'Pending' | 'Running' | 'Completed' | 'Cancelled'
  final String _batchCode = 'BATCH-20261020-001';

  final List<MobileBatchPosition> _positions = [
    MobileBatchPosition(
      coordinate: 'A1',
      isIqcControl: true,
      iqcLevel: 'Level 1 (Normal)',
      barcode: 'IQC-NORM-L1',
    ),
    MobileBatchPosition(
      coordinate: 'A2',
      isIqcControl: true,
      iqcLevel: 'Level 2 (High)',
      barcode: 'IQC-PATH-L2',
    ),
    MobileBatchPosition(
      coordinate: 'A3',
      barcode: 'SMP-2026-0089',
      patientName: 'Trần Văn An',
      isStat: true,
    ),
    MobileBatchPosition(
      coordinate: 'A4',
      barcode: 'SMP-2026-0091',
      patientName: 'Lê Thị Bình',
      isStat: false,
    ),
  ];

  @override
  void dispose() {
    _barcodeInputController.dispose();
    super.dispose();
  }

  void _addSampleBarcode(String barcode) {
    if (barcode.trim().isEmpty) return;
    if (_positions.length >= _trayCapacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Khay xét nghiệm đã đầy sức chứa (48 giếng)!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final nextIndex = _positions.length;
    final rowLetter = String.fromCharCode(65 + (nextIndex ~/ 8));
    final colNumber = (nextIndex % 8) + 1;
    final nextCoord = '$rowLetter$colNumber';

    final isStat = barcode.toUpperCase().contains('STAT');

    setState(() {
      _positions.add(MobileBatchPosition(
        coordinate: nextCoord,
        barcode: barcode.trim(),
        patientName: 'BN Mới ($barcode)',
        isStat: isStat,
      ));
      _barcodeInputController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã gán ống mẫu $barcode vào giếng $nextCoord'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _updateStatus(String nextStatus) {
    setState(() {
      _batchStatus = nextStatus;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mẻ xét nghiệm chuyển sang trạng thái: $nextStatus'),
        backgroundColor: nextStatus == 'Completed' ? AppColors.success : AppColors.primary,
      ),
    );
  }

  void _cancelBatchWithRollback() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Xác nhận Hủy Mẻ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Hủy mẻ sẽ tự động hoàn trả tất cả ống mẫu bệnh phẩm về hàng đợi "Đã tiếp nhận" (SampleStatus.Received) theo tiêu chuẩn ISO 15189.\n\nBạn có chắc chắn muốn hủy?',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _batchStatus = 'Cancelled';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã hủy mẻ và hoàn trả ống nghiệm về trạng thái Received.'),
                  backgroundColor: AppColors.danger,
                ),
              );
            },
            child: const Text('Xác nhận Hủy & Rollback'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patientCount = _positions.where((p) => !p.isIqcControl).length;
    final statCount = _positions.where((p) => p.isStat).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_batchCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              _selectedAnalyzer,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _batchStatus == 'Completed'
                  ? AppColors.successLight
                  : _batchStatus == 'Running'
                      ? AppColors.tealLight
                      : _batchStatus == 'Cancelled'
                          ? AppColors.dangerLight
                          : AppColors.warningLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _batchStatus == 'Completed'
                    ? AppColors.success
                    : _batchStatus == 'Running'
                        ? AppColors.teal
                        : _batchStatus == 'Cancelled'
                            ? AppColors.danger
                            : AppColors.warning,
              ),
            ),
            child: Text(
              _batchStatus,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: _batchStatus == 'Completed'
                    ? AppColors.success
                    : _batchStatus == 'Running'
                        ? AppColors.primary
                        : _batchStatus == 'Cancelled'
                            ? AppColors.danger
                            : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ISO 15189 Notice Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_outlined, color: Color(0xFF7C3AED), size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ISO 15189: Giếng A1 & A2 được khóa cho Mẫu nội kiểm IQC (Level 1 & Level 2). Mẫu cấp cứu STAT được nạp ưu tiên.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF5B21B6), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Capacity & Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Đã nạp',
                    value: '${_positions.length} / $_trayCapacity',
                    icon: Icons.science_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Bệnh phẩm',
                    value: '$patientCount mẫu',
                    icon: Icons.person_outline,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'STAT Cấp cứu',
                    value: '$statCount mẫu',
                    icon: Icons.priority_high_rounded,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Barcode Scanner & Input Field
            if (_batchStatus == 'Pending') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quét hoặc Nhập Barcode Ống Mẫu',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _barcodeInputController,
                            decoration: InputDecoration(
                              hintText: 'Nhập barcode (VD: SMP-2026-STAT-09)',
                              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textDisabled),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                            ),
                            onSubmitted: _addSampleBarcode,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _addSampleBarcode(_barcodeInputController.text),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Thêm'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Well Plate Mini-Grid View
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sơ đồ Vị trí Khay Giếng (Well Plate Map)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _positions.length,
                    itemBuilder: (context, index) {
                      final pos = _positions[index];
                      final isIqc = pos.isIqcControl;
                      final isStat = pos.isStat;

                      return Container(
                        decoration: BoxDecoration(
                          color: isIqc
                              ? const Color(0xFFF5F3FF)
                              : isStat
                                  ? AppColors.dangerLight
                                  : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isIqc
                                ? const Color(0xFF8B5CF6)
                                : isStat
                                    ? AppColors.danger
                                    : AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              pos.coordinate,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isIqc
                                    ? const Color(0xFF6D28D9)
                                    : isStat
                                        ? AppColors.danger
                                        : AppColors.primaryDark,
                              ),
                            ),
                            Text(
                              isIqc ? 'IQC' : isStat ? 'STAT' : 'R',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isIqc
                                    ? const Color(0xFF7C3AED)
                                    : isStat
                                        ? AppColors.danger
                                        : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            if (_batchStatus == 'Pending') ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _updateStatus('Running'),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Bắt Đầu Nạp Máy Phân Tích (Start Run)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (_batchStatus == 'Running') ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _updateStatus('Completed'),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Hoàn Tất Ca Xét Nghiệm (Complete)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (_batchStatus != 'Completed' && _batchStatus != 'Cancelled') ...[
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _cancelBatchWithRollback,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Hủy Mẻ & Hoàn Tác Ống Mẫu (Rollback)'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
