import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/track_progress_repository.dart';
import '../../models/track_progress_model.dart';

/// Screen displaying the 6-stage clinical specimen progress lifecycle for UC48 (Track Test Progress Mobile).
/// Conforms to: ISO 15189, HIPAA Patient Privacy & AGENTS-DESIGN.md.
class TrackTestProgressScreen extends StatefulWidget {
  final String? initialCode;
  final TrackProgressRepository? repository;

  const TrackTestProgressScreen({
    super.key,
    this.initialCode,
    this.repository,
  });

  @override
  State<TrackTestProgressScreen> createState() => _TrackTestProgressScreenState();
}

class _TrackTestProgressScreenState extends State<TrackTestProgressScreen> {
  late final TrackProgressRepository _repo = widget.repository ?? TrackProgressRepository();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = false;
  String? _errorMessage;
  TrackProgressModel? _trackingData;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.trim().isNotEmpty) {
      _searchController.text = widget.initialCode!.trim();
      _performLookup(widget.initialCode!.trim());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performLookup(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập mã đơn hoặc mã vạch barcode.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await _repo.getTracking(cleanCode);
      if (!mounted) return;
      if (res == null) {
        setState(() {
          _errorMessage = 'Không tìm thấy tiến trình xét nghiệm cho mã "$cleanCode".';
          _trackingData = null;
          _loading = false;
        });
      } else {
        setState(() {
          _trackingData = res;
          _errorMessage = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Lỗi kết nối khi tra cứu tiến trình. Vui lòng thử lại.';
        _loading = false;
      });
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '---';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt.toUtc().add(const Duration(hours: 7)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Lộ Trình Mẫu Máu Live',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () {
              if (_searchController.text.isNotEmpty) {
                _performLookup(_searchController.text);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Search Bar Card
            _buildSearchCard(),
            const SizedBox(height: 16),

            // 2. Error Message if any
            if (_errorMessage != null) _buildErrorCard(),

            // 3. Loading Indicator
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(),
                ),
              ),

            // 4. Tracking Detail Content
            if (!_loading && _trackingData != null) ...[
              _buildSpecimenSummaryCard(_trackingData!),
              const SizedBox(height: 20),
              _buildStepperSection(_trackingData!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tra Cứu Tiến Trình Xét Nghiệm',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Nhập mã đơn ORD hoặc quét Barcode dán trên ống mẫu',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: ORD-2026-0001...',
                      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textDisabled),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                    ),
                    onSubmitted: (val) => _performLookup(val),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _performLookup(_searchController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tra Cứu', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecimenSummaryCard(TrackProgressModel data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, AppColors.primaryLight.withOpacity(0.3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MÃ ĐƠN XÉT NGHIỆM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                    Text(
                      data.orderNumber,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: data.isStat ? AppColors.danger : AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data.isStat ? '⚡ CẤP CỨU STAT' : 'ROUTINE',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bệnh nhân:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      Text(data.patientName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dự kiến trả kết quả:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      Text(
                        _formatDateTime(data.estimatedCompletionTime),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined, color: AppColors.teal, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.testPackageNames.join(', '),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            if (data.isRejected) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mẫu bị từ chối: ${data.rejectionReason ?? "Không đạt chuẩn"}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepperSection(TrackProgressModel data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tiến Trình 6 Chặng Khép Kín',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            Text(
              'Chặng ${data.currentStepNumber}/6',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.steps.length,
          itemBuilder: (context, index) {
            final step = data.steps[index];
            final isLast = index == data.steps.length - 1;
            return _buildStepItem(step, isLast);
          },
        ),
      ],
    );
  }

  Widget _buildStepItem(TrackingStepModel step, bool isLast) {
    Color iconColor;
    Color circleColor;
    IconData iconData;

    if (step.isCompleted) {
      iconColor = Colors.white;
      circleColor = AppColors.success;
      iconData = Icons.check;
    } else if (step.isInProgress) {
      iconColor = Colors.white;
      circleColor = AppColors.primary;
      iconData = Icons.autorenew;
    } else if (step.isRejected) {
      iconColor = Colors.white;
      circleColor = AppColors.danger;
      iconData = Icons.close;
    } else if (step.isWarning) {
      iconColor = Colors.white;
      circleColor = AppColors.warning;
      iconData = Icons.warning_amber_rounded;
    } else {
      iconColor = AppColors.textDisabled;
      circleColor = AppColors.border;
      iconData = Icons.circle_outlined;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Node with Connecting Line
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: circleColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Icon(iconData, color: iconColor, size: 16),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.5,
                    color: step.isCompleted ? AppColors.success : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Step Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: step.isInProgress ? AppColors.primaryLight : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: step.isInProgress ? AppColors.primary : AppColors.border,
                    width: step.isInProgress ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: step.isInProgress ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: circleColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            step.statusText,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: circleColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step.description,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(step.timestamp),
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                        ),
                        if (step.handlerName != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              step.handlerName!,
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
