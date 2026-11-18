import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../../../shell/presentation/web_only_role_notice_screen.dart';
import '../../data/test_result_verification_repository.dart';
import '../../models/test_result_verification_model.dart';

/// Laboratory Specimen Result Verification Screen.
/// Routes Web-only Lab/Admin/Manager accounts to [WebOnlyRoleNoticeScreen] and uses 100% real API data.
class VerifyTestResultsScreen extends StatefulWidget {
  final String specimenId;

  const VerifyTestResultsScreen({super.key, this.specimenId = ''});

  @override
  State<VerifyTestResultsScreen> createState() =>
      _VerifyTestResultsScreenState();
}

class _VerifyTestResultsScreenState extends State<VerifyTestResultsScreen> {
  final TestResultVerificationRepository _repository =
      TestResultVerificationRepository();
  final TextEditingController _commentController = TextEditingController();

  TestResultVerificationDetailModel? _detail;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.specimenId.trim().isNotEmpty) {
      _loadData();
    } else {
      _isLoading = false;
    }
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
      final res = await _repository.fetchVerificationDetails(
        widget.specimenId.trim(),
      );
      if (!mounted) return;
      setState(() {
        _detail = res;
        if (res != null && res.verifierComment.isNotEmpty) {
          _commentController.text = res.verifierComment;
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải dữ liệu kiểm duyệt mẫu xét nghiệm.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleVerify() async {
    final comment = _commentController.text.trim();
    if (comment.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhận xét kiểm duyệt cần tối thiểu 10 ký tự.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final ok = await _repository.verifyTestResult(
      widget.specimenId.trim(),
      comment,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xác nhận kiểm duyệt và chuyển bác sĩ phê duyệt.'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xác nhận kết quả mẫu.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (BmsAuth.isLoggedIn && !BmsAuth.isMobileSupportedRole) {
      return const WebOnlyRoleNoticeScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Kiểm duyệt kết quả xét nghiệm')),
      body: _isLoading
          ? const BmsLoadingState(message: 'Đang tải thông tin mẫu bệnh phẩm...')
          : _errorMessage != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: BmsErrorState(
                    message: _errorMessage!,
                    onRetry: _loadData,
                  ),
                )
              : _detail == null
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: BmsEmptyState(
                        icon: Icons.desktop_windows_rounded,
                        title: 'Nghiệp vụ kiểm duyệt máy phân tích thuộc hệ thống Web',
                        subtitle:
                            'Vui lòng đăng nhập Trạm làm việc BMS Web để đối soát Levey-Jennings và duyệt kỹ thuật.',
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
                              BmsInfoRow(
                                label: 'Mã mẫu bệnh phẩm',
                                value: _detail!.specimenId,
                                isMono: true,
                              ),
                              BmsInfoRow(
                                label: 'Bệnh nhân',
                                value: _detail!.patientName,
                                isBold: true,
                              ),
                              BmsInfoRow(
                                label: 'Mã bệnh nhân',
                                value: _detail!.patientId,
                                isMono: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        BmsSoftCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _commentController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Nhận xét kiểm duyệt kỹ thuật *',
                                  hintText:
                                      'Nhập ghi chú đối soát chất lượng mẫu (tối thiểu 10 ký tự)...',
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton(
                                onPressed: _isSubmitting ? null : _handleVerify,
                                child: Text(
                                  _isSubmitting
                                      ? 'Đang xác nhận...'
                                      : 'Xác nhận chuyển bác sĩ phê duyệt',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
}
