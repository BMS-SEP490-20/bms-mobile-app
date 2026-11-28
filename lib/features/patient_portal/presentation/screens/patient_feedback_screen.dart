import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../../data/patient_portal_api.dart';

/// 1-to-1 Patient Feedback & Service Rating Hub matching Web `FeedbackHubPage.jsx`:
/// - Calls `/TestOrder/feedback/patient/{userId}`, `/my-eligible-packages`, `/eligibility`
/// - Strictly locks new feedback to used/completed packages (`unreviewedEligiblePackages`)
/// - Supports Create, Edit, Delete own feedback + Admin delete-consent approval/rejection
class PatientFeedbackScreen extends StatefulWidget {
  final String? preselectedAppointmentId;
  final String? preselectedPackageCode;

  const PatientFeedbackScreen({
    super.key,
    this.preselectedAppointmentId,
    this.preselectedPackageCode,
  });

  @override
  State<PatientFeedbackScreen> createState() => _PatientFeedbackScreenState();
}

class _PatientFeedbackScreenState extends State<PatientFeedbackScreen> {
  final PatientPortalApi _api = const PatientPortalApi();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _myFeedbacks = [];
  List<Map<String, dynamic>> _eligiblePackages = [];
  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> get _unreviewedEligible => _eligiblePackages
      .where((e) => e['alreadyReviewed'] != true)
      .toList();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getMyFeedbacks(BmsAuth.currentUserId),
        _api.getMyEligiblePackages(),
      ]);
      if (!mounted) return;
      setState(() {
        _myFeedbacks = results[0];
        _eligiblePackages = results[1];
        _loading = false;
      });

      if (!_autoOpened &&
          (widget.preselectedAppointmentId != null ||
              widget.preselectedPackageCode != null)) {
        _autoOpened = true;
        final match = _unreviewedEligible.where((e) {
          final aId = (widget.preselectedAppointmentId ?? '').toLowerCase();
          final pCode = (widget.preselectedPackageCode ?? '').toLowerCase();
          return (aId.isNotEmpty &&
                  ((e['appointmentId'] ?? '').toString().toLowerCase() == aId ||
                      (e['appointmentCode'] ?? '').toString().toLowerCase() ==
                          aId)) ||
              (pCode.isNotEmpty &&
                  (e['servicePackageCode'] ?? '').toString().toLowerCase() ==
                      pCode);
        }).toList();
        if (match.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openCreateSheet(preselected: match.first);
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openCreateSheet({Map<String, dynamic>? preselected}) async {
    final unreviewed = _unreviewedEligible;
    if (unreviewed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bạn chỉ có thể đánh giá các gói xét nghiệm đã đặt lịch và hoàn tất thanh toán/thực hiện.',
          ),
        ),
      );
      return;
    }

    var selectedPkg = preselected ?? unreviewed.first;
    var rating = 5;
    var isAnonymous = false;
    final titleCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    var submitting = false;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(ctx).viewInsets.bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Gửi đánh giá gói dịch vụ đã sử dụng',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (unreviewed.length == 1)
                  BmsSoftCard(
                    backgroundColor: AppColors.primaryLight,
                    borderColor: AppColors.primaryBorder,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GÓI DỊCH VỤ ĐƯỢC KHÓA THEO LỊCH ĐÃ SỬ DỤNG',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (selectedPkg['servicePackageName'] ??
                                  selectedPkg['packageName'] ??
                                  'Gói xét nghiệm')
                              .toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Mã lịch hẹn: ${selectedPkg['appointmentCode'] ?? selectedPkg['appointmentId'] ?? '—'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<int>(
                    initialValue: unreviewed.indexOf(selectedPkg),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Chọn gói đã sử dụng *',
                    ),
                    items: List.generate(
                      unreviewed.length,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(
                          '${unreviewed[i]['servicePackageName'] ?? unreviewed[i]['packageName']} (${unreviewed[i]['appointmentCode'] ?? ''})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    onChanged: (idx) {
                      if (idx != null) {
                        setModalState(() => selectedPkg = unreviewed[idx]);
                      }
                    },
                  ),
                const SizedBox(height: 14),
                const Text(
                  'Mức độ hài lòng *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return IconButton(
                      onPressed: () => setModalState(() => rating = star),
                      icon: Icon(
                        star <= rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: AppColors.warning,
                        size: 36,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề đánh giá *',
                    hintText: 'VD: Lấy máu nhẹ nhàng, trả kết quả nhanh',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Nhận xét chi tiết *',
                    hintText: 'Chia sẻ trải nghiệm thực tế của bạn...',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Hiển thị ẩn danh trên bảng gói dịch vụ',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: isAnonymous,
                  onChanged: (v) => setModalState(() => isAnonymous = v),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            if (titleCtrl.text.trim().isEmpty ||
                                commentCtrl.text.trim().isEmpty) {
                              return;
                            }
                            setModalState(() => submitting = true);
                            try {
                              await _api.createFeedback({
                                'rating': rating,
                                'serviceCategory': 'Đánh giá gói xét nghiệm',
                                'title': titleCtrl.text.trim(),
                                'comment': commentCtrl.text.trim(),
                                'appointmentId':
                                    selectedPkg['appointmentId'] ?? '',
                                'servicePackageId':
                                    selectedPkg['servicePackageId'] ?? '',
                                'servicePackageCode':
                                    selectedPkg['servicePackageCode'] ?? '',
                                'servicePackageName':
                                    selectedPkg['servicePackageName'] ??
                                    selectedPkg['packageName'] ??
                                    '',
                                'doctorName': selectedPkg['doctorName'] ?? '',
                                'isAnonymous': isAnonymous,
                              });
                              if (ctx.mounted) Navigator.of(ctx).pop(true);
                            } catch (e) {
                              setModalState(() => submitting = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString()),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              }
                            }
                          },
                    child: Text(
                      submitting ? 'Đang gửi...' : 'Gửi đánh giá dịch vụ',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cảm ơn bạn đã gửi đánh giá!'),
          backgroundColor: AppColors.success,
        ),
      );
      _load();
    }
  }

  Future<void> _openEditSheet(Map<String, dynamic> fb) async {
    var rating = (fb['rating'] as num?)?.toInt() ?? 5;
    var isAnonymous = fb['isAnonymous'] == true;
    final titleCtrl = TextEditingController(text: (fb['title'] ?? '').toString());
    final commentCtrl = TextEditingController(
      text: (fb['comment'] ?? '').toString(),
    );
    var saving = false;

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(ctx).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Chỉnh sửa đánh giá',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return IconButton(
                    onPressed: () => setModalState(() => rating = star),
                    icon: Icon(
                      star <= rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: AppColors.warning,
                      size: 34,
                    ),
                  );
                }),
              ),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Tiêu đề *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Nhận xét *'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ẩn danh'),
                value: isAnonymous,
                onChanged: (v) => setModalState(() => isAnonymous = v),
              ),
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setModalState(() => saving = true);
                          try {
                            final id = (fb['feedbackId'] ?? fb['id'] ?? '')
                                .toString();
                            await _api.updateFeedback(id, {
                              'rating': rating,
                              'serviceCategory':
                                  fb['serviceCategory'] ??
                                  'Đánh giá gói xét nghiệm',
                              'title': titleCtrl.text.trim(),
                              'comment': commentCtrl.text.trim(),
                              'isAnonymous': isAnonymous,
                            });
                            if (ctx.mounted) Navigator.of(ctx).pop(true);
                          } catch (e) {
                            setModalState(() => saving = false);
                          }
                        },
                  child: Text(saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (updated == true) _load();
  }

  Future<void> _deleteFeedback(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa đánh giá này?'),
        content: const Text('Đánh giá sau khi xóa sẽ không thể khôi phục.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteFeedback(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _respondConsent(String id, bool approved) async {
    try {
      await _api.respondDeleteConsent(id, approved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approved
                  ? 'Đã đồng ý ẩn đánh giá theo yêu cầu quản trị.'
                  : 'Đã giữ lại đánh giá của bạn.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreviewedCount = _unreviewedEligible.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Đánh giá & Góp ý Y tế')),
      floatingActionButton: unreviewedCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => _openCreateSheet(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.rate_review_outlined),
              label: Text('Đánh giá ($unreviewedCount)'),
            )
          : null,
      body: SafeArea(
        child: _loading
            ? const BmsLoadingState(message: 'Đang tải đánh giá của bạn...')
            : _error != null
            ? Padding(
                padding: const EdgeInsets.all(18),
                child: BmsErrorState(message: _error!, onRetry: _load),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    BmsPageHeaderCard(
                      icon: Icons.star_outline_rounded,
                      badgeText: 'CHỈ ĐÁNH GIÁ GÓI ĐÃ SỬ DỤNG',
                      title: 'Đánh giá dịch vụ của tôi',
                      subtitle: unreviewedCount > 0
                          ? 'Bạn có $unreviewedCount gói xét nghiệm đã sử dụng sẵn sàng để đánh giá'
                          : 'Các đánh giá của bạn giúp BMS nâng cao chất lượng xét nghiệm chuẩn ISO 15189',
                    ),
                    const SizedBox(height: 14),
                    if (_myFeedbacks.isEmpty)
                      BmsEmptyState(
                        icon: Icons.reviews_outlined,
                        title: 'Bạn chưa có đánh giá nào',
                        subtitle: unreviewedCount > 0
                            ? 'Bấm nút "Đánh giá" bên dưới để chia sẻ cảm nhận về gói bạn vừa thực hiện.'
                            : 'Sau khi hoàn tất đặt lịch & xét nghiệm, bạn có thể gửi đánh giá cho gói đã sử dụng tại đây.',
                        actionLabel:
                            unreviewedCount > 0 ? 'Gửi đánh giá ngay' : null,
                        onAction:
                            unreviewedCount > 0 ? () => _openCreateSheet() : null,
                      )
                    else
                      ..._myFeedbacks.map(_buildFeedbackCard),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> fb) {
    final id = (fb['feedbackId'] ?? fb['id'] ?? '').toString();
    final stars = (fb['rating'] as num?)?.toInt() ?? 5;
    final pkgName = (fb['servicePackageName'] ?? fb['serviceCategory'] ?? '')
        .toString();
    final reply = (fb['managerResponse'] ?? fb['response'] ?? '').toString().trim();
    final pendingConsent = fb['deleteConsentStatus']?.toString().toLowerCase() ==
            'pending' ||
        fb['pendingDeleteConsent'] == true;

    return BmsSoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pkgName.isNotEmpty ? pkgName : 'Đánh giá dịch vụ',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Text(
                '★' * stars + '☆' * (5 - stars),
                style: const TextStyle(fontSize: 15, color: AppColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            (fb['title'] ?? '').toString(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            (fb['comment'] ?? '').toString(),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (pendingConsent) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quản trị viên gửi yêu cầu ẩn đánh giá này',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.warningText,
                    ),
                  ),
                  if ((fb['adminDeleteReason'] ?? '').toString().isNotEmpty)
                    Text(
                      'Lý do: ${fb['adminDeleteReason']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.warningText,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => _respondConsent(id, false),
                        child: const Text('Giữ lại'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _respondConsent(id, true),
                        child: const Text('Đồng ý ẩn'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (reply.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phản hồi từ Phòng khám BMS:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reply,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 20),
          Row(
            children: [
              Text(
                BmsFormatters.dateTime(fb['createdAt']),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openEditSheet(fb),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Sửa'),
              ),
              TextButton.icon(
                onPressed: () => _deleteFeedback(id),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Xóa'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
