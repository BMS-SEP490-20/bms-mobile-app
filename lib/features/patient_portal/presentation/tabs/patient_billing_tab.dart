import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../data/patient_portal_api.dart';

/// Tab 4 of PatientShellScreen — Patient Invoices, BHYT Breakdown & SePay Checkout.
class PatientBillingTab extends StatefulWidget {
  const PatientBillingTab({super.key});

  @override
  State<PatientBillingTab> createState() => _PatientBillingTabState();
}

class _PatientBillingTabState extends State<PatientBillingTab> {
  final PatientPortalApi _api = const PatientPortalApi();

  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getInvoices(page: 1, pageSize: 30);
      if (!mounted) return;
      setState(() {
        _invoices = list;
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

  List<Map<String, dynamic>> get _filtered {
    return _invoices.where((inv) {
      final st = (inv['status'] ?? '').toString().toLowerCase();
      if (_filter == 'unpaid') return st == 'unpaid';
      if (_filter == 'paid') return st == 'paid';
      return true;
    }).toList();
  }

  Future<void> _openInvoiceDetail(Map<String, dynamic> inv) async {
    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PatientInvoiceDetailSheet(api: _api, invoice: inv),
    );
    if (paid == true) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filtered;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              children: [
                BmsPageHeaderCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Viện phí & Hóa đơn',
                  subtitle:
                      'Tra cứu chi tiết dịch vụ, khấu trừ BHYT và thanh toán chuyển khoản SePay',
                  trailing: IconButton(
                    onPressed: _load,
                    tooltip: 'Làm mới',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                BmsSearchFilterBar(
                  filterChips: [
                    BmsFilterChipItem(
                      key: 'all',
                      label: 'Tất cả (${_invoices.length})',
                      selected: _filter == 'all',
                      onSelected: () => setState(() => _filter = 'all'),
                    ),
                    BmsFilterChipItem(
                      key: 'unpaid',
                      label: 'Chờ thanh toán',
                      selected: _filter == 'unpaid',
                      onSelected: () => setState(() => _filter = 'unpaid'),
                    ),
                    BmsFilterChipItem(
                      key: 'paid',
                      label: 'Đã thanh toán',
                      selected: _filter == 'paid',
                      onSelected: () => setState(() => _filter = 'paid'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const BmsLoadingState(message: 'Đang tải sổ viện phí...')
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: BmsErrorState(message: _error!, onRetry: _load),
                    ),
                  )
                : visible.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: BmsEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Chưa có hóa đơn viện phí',
                        subtitle:
                            'Hóa đơn chỉ định xét nghiệm sẽ tự động cập nhật sau khi tiếp nhận khám.',
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final inv = visible[idx];
                        final code =
                            (inv['invoiceCode'] ?? inv['id'] ?? '').toString();
                        final status = (inv['status'] ?? 'Unpaid').toString();
                        final total = (inv['totalAmount'] as num?) ?? 0;
                        final created = BmsFormatters.dateTime(
                          inv['createdAt'] ?? inv['paidAt'],
                        );
                        final isUnpaid = status.toLowerCase() == 'unpaid';

                        return BmsSoftCard(
                          onTap: () => _openInvoiceDetail(inv),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    code,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  BmsStatusPill(status: status),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    created,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    BmsFormatters.currency(total),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (isUnpaid) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () => _openInvoiceDetail(inv),
                                    icon: const Icon(
                                      Icons.qr_code_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Thanh toán trực tuyến'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PatientInvoiceDetailSheet extends StatefulWidget {
  final PatientPortalApi api;
  final Map<String, dynamic> invoice;

  const _PatientInvoiceDetailSheet({
    required this.api,
    required this.invoice,
  });

  @override
  State<_PatientInvoiceDetailSheet> createState() =>
      _PatientInvoiceDetailSheetState();
}

class _PatientInvoiceDetailSheetState
    extends State<_PatientInvoiceDetailSheet> {
  Map<String, dynamic>? _checkout;
  Map<String, dynamic>? _sePayCheckout;
  String? _sePayNotice;
  bool _loading = true;
  bool _paying = false;

  String get _invoiceId =>
      (widget.invoice['id'] ?? widget.invoice['invoiceId'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final apptId = (widget.invoice['appointmentId'] ?? '').toString();
    try {
      final summary = await widget.api.getCheckoutSummary(_invoiceId);
      Map<String, dynamic>? sePayData;
      String? sePayMsg;
      if (apptId.isNotEmpty) {
        final sePayRes = await widget.api.getSePayCheckout(apptId);
        sePayData = sePayRes.checkout;
        sePayMsg = sePayRes.unavailableReason;
      }
      if (!mounted) return;
      setState(() {
        _checkout = summary;
        _sePayCheckout = sePayData;
        _sePayNotice = sePayMsg;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmSePayPayment() async {
    setState(() => _paying = true);
    try {
      await widget.api.processSePayPayment(_invoiceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã ghi nhận thanh toán hóa đơn thành công.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = _checkout ?? widget.invoice;
    final code = (inv['invoiceCode'] ?? _invoiceId).toString();
    final status = (inv['status'] ?? widget.invoice['status'] ?? 'Unpaid')
        .toString();
    final isUnpaid = status.toLowerCase() == 'unpaid';
    final subTotal = (inv['subTotal'] as num?) ?? 0;
    final bhytDeduction =
        (widget.invoice['insuranceDeduction'] as num?) ??
        (inv['insuranceDeduction'] as num?) ??
        0;
    final discount = (inv['discountAmount'] as num?) ?? 0;
    final total = (inv['totalAmount'] as num?) ?? 0;
    final txRef =
        (inv['transactionReference'] ??
                widget.invoice['transactionReference'] ??
                '')
            .toString();
    final rawItems = inv['items'] is List
        ? (inv['items'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    final qrPayload =
        (_sePayCheckout?['qrUrl'] ??
                _sePayCheckout?['qrData'] ??
                inv['qrCodePayload'] ??
                '')
            .toString();

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollCtrl) {
        return ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chi tiết hóa đơn viện phí',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                BmsStatusPill(status: status),
              ],
            ),
            const SizedBox(height: 14),
            if (_loading)
              const BmsLoadingState(message: 'Đang tải bảng kê dịch vụ...')
            else ...[
              BmsSoftCard(
                backgroundColor: AppColors.surfaceSoft,
                child: Column(
                  children: [
                    BmsInfoRow(
                      label: 'Mã hóa đơn',
                      value: code,
                      isMono: true,
                      isBold: true,
                    ),
                    BmsInfoRow(
                      label: 'Hình thức thu',
                      value: BmsFormatters.paymentMethodVi(
                        inv['paymentMethod']?.toString(),
                      ),
                    ),
                    if (txRef.isNotEmpty)
                      BmsInfoRow(
                        label: 'Mã biên nhận / GD',
                        value: txRef,
                        isMono: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const BmsSectionHeader(title: 'Danh mục xét nghiệm'),
              const SizedBox(height: 8),
              BmsSoftCard(
                child: rawItems.isEmpty
                    ? const Text(
                        'Gói xét nghiệm lâm sàng theo phiếu chỉ định.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : Column(
                        children: rawItems.map((it) {
                          final name =
                              (it['itemName'] ??
                                      it['packageName'] ??
                                      it['itemCode'] ??
                                      'Dịch vụ xét nghiệm')
                                  .toString();
                          final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                          final price =
                              (it['totalPrice'] ?? it['unitPrice'] ?? 0)
                                  as num;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$name (x$qty)',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  BmsFormatters.currency(price),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 12),
              BmsSoftCard(
                child: Column(
                  children: [
                    BmsInfoRow(
                      label: 'Tạm tính dịch vụ',
                      value: BmsFormatters.currency(subTotal),
                    ),
                    if (bhytDeduction > 0)
                      BmsInfoRow(
                        label: 'Quỹ BHYT chi trả',
                        value: '-${BmsFormatters.currency(bhytDeduction)}',
                        valueColor: AppColors.successText,
                      ),
                    if (discount > 0)
                      BmsInfoRow(
                        label: 'Ưu đãi / Giảm trừ',
                        value: '-${BmsFormatters.currency(discount)}',
                        valueColor: AppColors.successText,
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(),
                    ),
                    BmsInfoRow(
                      label: 'Thực thu bệnh nhân',
                      value: BmsFormatters.currency(total),
                      isBold: true,
                      valueColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
              if (isUnpaid) ...[
                const SizedBox(height: 16),
                if (qrPayload.isNotEmpty && !qrPayload.startsWith('http'))
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: QrImageView(
                        data: qrPayload,
                        size: 165,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (_sePayNotice != null) ...[
                  const SizedBox(height: 10),
                  BmsSoftCard(
                    backgroundColor: AppColors.warningLight,
                    borderColor: AppColors.warningBorder,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.warningText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _sePayNotice!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.warningText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _paying ? null : _confirmSePayPayment,
                  icon: _paying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.verified_outlined, size: 19),
                  label: Text(
                    _paying
                        ? 'Đang xác thực thanh toán...'
                        : 'Xác nhận thanh toán SePay (${BmsFormatters.currency(total)})',
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}
