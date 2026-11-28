import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../data/patient_portal_api.dart';
import '../screens/sepay_checkout_screen.dart';

/// 1-to-1 Patient Billing & Invoices History matching Web `PatientPaymentHistoryPage.jsx`:
/// - Strictly ZERO BHYT lines, ZERO VNPay/Reception 403 buttons
/// - Unpaid invoices open `SePayCheckoutScreen` (real VietQR + 3s polling + Sandbox)
/// - Paid invoices display clean K80 Electronic Receipt modal with `BMS-HOADON|...` QR
class PatientBillingTab extends StatefulWidget {
  final bool asStandaloneScreen;

  const PatientBillingTab({super.key, this.asStandaloneScreen = false});

  @override
  State<PatientBillingTab> createState() => _PatientBillingTabState();
}

class _PatientBillingTabState extends State<PatientBillingTab> {
  final PatientPortalApi _api = const PatientPortalApi();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _invoices = [];
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getMyBillingInvoices(page: 1, pageSize: 50);
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

  String _statusOf(Map<String, dynamic> inv) =>
      (inv['status'] ?? inv['paymentStatus'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

  /// Voided / refunded / cancelled invoices are closed: never payable, never "pending".
  bool _isClosed(Map<String, dynamic> inv) {
    final s = _statusOf(inv);
    return s == 'voided' ||
        s == 'refunded' ||
        s == 'partiallyrefunded' ||
        s == 'cancelled' ||
        s == '3' ||
        s == '4';
  }

  bool _isPaid(Map<String, dynamic> inv) {
    if (_isClosed(inv)) return false;
    final s = _statusOf(inv);
    return s == 'paid' || s == '1' || s == 'completed' || inv['paidAt'] != null;
  }

  /// Only genuinely unpaid invoices can open SePay checkout / count as "Chờ thanh toán".
  bool _isPayable(Map<String, dynamic> inv) => !_isPaid(inv) && !_isClosed(inv);

  double _amountOf(Map<String, dynamic> inv) {
    final raw =
        inv['finalAmount'] ??
        inv['totalAmount'] ??
        inv['amount'] ??
        inv['subTotal'] ??
        0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0;
  }

  String _packageNameOf(Map<String, dynamic> inv) {
    final direct = (inv['packageName'] ?? inv['testName'] ?? '')
        .toString()
        .trim();
    if (direct.isNotEmpty) return direct;
    if (inv['items'] is List) {
      for (final raw in inv['items'] as List) {
        if (raw is Map) {
          final name =
              (raw['itemName'] ?? raw['serviceName'] ?? raw['name'] ?? '')
                  .toString()
                  .trim();
          if (name.isNotEmpty) return name;
        }
      }
    }
    return '';
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _invoices.where((inv) {
      if (_statusFilter == 'PAID' && !_isPaid(inv)) return false;
      if (_statusFilter == 'UNPAID' && !_isPayable(inv)) return false;
      if (q.isNotEmpty) {
        final pkgName = _packageNameOf(inv);
        final blob =
            '${inv['invoiceCode'] ?? ''} ${inv['appointmentCode'] ?? ''} $pkgName ${inv['transactionReference'] ?? ''} ${inv['receiptNumber'] ?? ''} ${inv['id'] ?? ''}'
                .toLowerCase();
        if (!blob.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  void _showReceiptSheet(Map<String, dynamic> inv) {
    final code = (inv['invoiceCode'] ?? inv['id'] ?? '').toString();
    final total = _amountOf(inv);
    final apptCode = (inv['appointmentCode'] ?? '').toString().trim();
    final txRef = (inv['transactionReference'] ?? inv['receiptNumber'] ?? '')
        .toString()
        .trim();
    final items = inv['items'] is List
        ? (inv['items'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : const <Map<String, dynamic>>[];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'BIÊN LAI VIỆN PHÍ ĐIỆN TỬ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Text(
                'Trung tâm Xét nghiệm Y khoa BMS MedLab',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const Divider(height: 22),
              BmsInfoRow(
                label: 'Mã hóa đơn',
                value: code,
                isMono: true,
                isBold: true,
              ),
              if (apptCode.isNotEmpty)
                BmsInfoRow(label: 'Mã lịch hẹn', value: apptCode, isMono: true),
              if (txRef.isNotEmpty)
                BmsInfoRow(label: 'Mã giao dịch', value: txRef, isMono: true),
              BmsInfoRow(
                label: 'Ngày thanh toán',
                value: BmsFormatters.dateTime(
                  inv['paidAt'] ?? inv['createdAt'],
                ),
              ),
              BmsInfoRow(
                label: 'Phương thức',
                value: BmsFormatters.paymentMethodVi(
                  (inv['paymentMethod'] ?? 'SePay').toString(),
                ),
              ),
              if (items.isNotEmpty) ...[
                const Divider(height: 18),
                ...items.map((it) {
                  final itemLabel =
                      (it['itemName'] ??
                              it['serviceName'] ??
                              it['name'] ??
                              'Dịch vụ xét nghiệm')
                          .toString();
                  final rawPrice =
                      it['totalPrice'] ?? it['unitPrice'] ?? it['price'] ?? 0;
                  final price = rawPrice is num
                      ? rawPrice
                      : (num.tryParse(rawPrice.toString()) ?? 0);
                  return BmsInfoRow(
                    label: itemLabel,
                    value: BmsFormatters.currency(price),
                  );
                }),
              ],
              const Divider(height: 18),
              BmsInfoRow(
                label: 'Tổng cộng đã thu',
                value: BmsFormatters.currency(total),
                isBold: true,
                valueColor: AppColors.successText,
              ),
              const SizedBox(height: 14),
              QrImageView(
                data: 'BMS-HOADON|$code|${total.round()}',
                size: 140,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 8),
              const Text(
                'Chứng từ điện tử đối soát trực tiếp trên hệ thống BMS',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng biên lai'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPaid = _invoices
        .where(_isPaid)
        .fold<double>(0, (sum, i) => sum + _amountOf(i));
    final totalUnpaid = _invoices
        .where(_isPayable)
        .fold<double>(0, (sum, i) => sum + _amountOf(i));

    final body = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const BmsPageHeaderCard(
            icon: Icons.receipt_long_outlined,
            badgeText: 'VIỆN PHÍ & VIETQR SEPAY',
            title: 'Thanh toán & Hóa đơn',
            subtitle: 'Quản lý lịch sử viện phí và thanh toán VietQR tự động',
          ),
          const SizedBox(height: 12),
          BmsKpiGrid(
            cards: [
              BmsKpiCard(
                label: 'Đã thanh toán',
                value: BmsFormatters.currency(totalPaid),
                icon: Icons.check_circle_outline_rounded,
                accentColor: AppColors.success,
              ),
              BmsKpiCard(
                label: 'Chờ thanh toán',
                value: BmsFormatters.currency(totalUnpaid),
                icon: Icons.pending_actions_rounded,
                accentColor: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          BmsSearchFilterBar(
            controller: _searchCtrl,
            hintText: 'Tìm mã hóa đơn, mã lịch hẹn...',
            onChanged: (_) => setState(() {}),
            filterChips: [
              BmsFilterChipItem(
                key: 'ALL',
                label: 'Tất cả (${_invoices.length})',
                selected: _statusFilter == 'ALL',
                onSelected: () => setState(() => _statusFilter = 'ALL'),
              ),
              BmsFilterChipItem(
                key: 'UNPAID',
                label: 'Chờ thanh toán',
                selected: _statusFilter == 'UNPAID',
                onSelected: () => setState(() => _statusFilter = 'UNPAID'),
              ),
              BmsFilterChipItem(
                key: 'PAID',
                label: 'Đã thanh toán',
                selected: _statusFilter == 'PAID',
                onSelected: () => setState(() => _statusFilter = 'PAID'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading)
            const BmsLoadingState(message: 'Đang tải danh sách hóa đơn...')
          else if (_error != null)
            BmsErrorState(message: _error!, onRetry: _load)
          else if (_filtered.isEmpty)
            const BmsEmptyState(
              icon: Icons.receipt_outlined,
              title: 'Chưa có hóa đơn viện phí',
              subtitle:
                  'Hóa đơn sẽ được tự động khởi tạo khi bạn đặt lịch xét nghiệm.',
            )
          else
            ..._filtered.map(_buildInvoiceCard),
          const SizedBox(height: 24),
        ],
      ),
    );

    if (widget.asStandaloneScreen) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Viện phí & Thanh toán')),
        body: SafeArea(child: body),
      );
    }
    return body;
  }

  Widget _buildInvoiceCard(Map<String, dynamic> inv) {
    final paid = _isPaid(inv);
    final closed = _isClosed(inv);
    final code = (inv['invoiceCode'] ?? inv['id'] ?? '').toString();
    final apptId = (inv['appointmentId'] ?? '').toString();
    final apptCode = (inv['appointmentCode'] ?? '').toString().trim();
    final pkgName = _packageNameOf(inv);
    final amount = _amountOf(inv);

    return BmsSoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    color: AppColors.primary,
                  ),
                ),
              ),
              BmsStatusPill(
                status: paid
                    ? 'Paid'
                    : closed
                    ? (_statusOf(inv).contains('refund')
                          ? 'Refunded'
                          : 'Cancelled')
                    : 'Unpaid',
              ),
            ],
          ),
          if (pkgName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              pkgName,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 6),
          if (apptCode.isNotEmpty)
            BmsInfoRow(label: 'Mã lịch hẹn', value: apptCode, isMono: true),
          BmsInfoRow(
            label: paid ? 'Ngày thanh toán' : 'Ngày tạo',
            value: BmsFormatters.dateTime(
              paid ? (inv['paidAt'] ?? inv['createdAt']) : inv['createdAt'],
            ),
          ),
          if (paid && (inv['paymentMethod'] ?? '').toString().isNotEmpty)
            BmsInfoRow(
              label: 'Phương thức',
              value: BmsFormatters.paymentMethodVi(
                inv['paymentMethod'].toString(),
              ),
            ),
          BmsInfoRow(
            label: 'Tổng thanh toán',
            value: BmsFormatters.currency(amount),
            isBold: true,
            valueColor: paid ? AppColors.successText : AppColors.primary,
          ),
          const SizedBox(height: 10),
          if (!closed)
            SizedBox(
              width: double.infinity,
              child: paid
                  ? OutlinedButton.icon(
                      onPressed: () => _showReceiptSheet(inv),
                      icon: const Icon(Icons.receipt_rounded, size: 18),
                      label: const Text('Xem biên lai điện tử (QR)'),
                    )
                  : FilledButton.icon(
                      onPressed: apptId.isEmpty
                          ? null
                          : () async {
                              final ok = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => SePayCheckoutScreen(
                                    appointmentId: apptId,
                                    appointmentCode: apptCode.isNotEmpty
                                        ? apptCode
                                        : null,
                                    packageName: pkgName.isNotEmpty
                                        ? pkgName
                                        : null,
                                  ),
                                ),
                              );
                              if (ok == true) _load();
                            },
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: const Text('Thanh toán VietQR SePay'),
                    ),
            ),
        ],
      ),
    );
  }
}
