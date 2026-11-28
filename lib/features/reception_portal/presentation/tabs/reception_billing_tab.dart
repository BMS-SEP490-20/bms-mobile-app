import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../data/reception_portal_api.dart';

/// Tab 4 — Invoices, Cashier Collection, K80 Receipt Preview & BHYT Fee Calculator.
class ReceptionBillingTab extends StatefulWidget {
  const ReceptionBillingTab({super.key});

  @override
  State<ReceptionBillingTab> createState() => _ReceptionBillingTabState();
}

class _ReceptionBillingTabState extends State<ReceptionBillingTab> {
  static const List<({String label, String card})> _bhytPresets = [
    (label: 'TE (Mức hưởng 100%)', card: 'TE1797938500001'),
    (label: 'CN (Mức hưởng 95%)', card: 'CN3797938500002'),
    (label: 'DN (Mức hưởng 80%)', card: 'DN4797938500003'),
  ];

  final ReceptionPortalApi _api = const ReceptionPortalApi();

  int _subTab = 0;

  List<Map<String, dynamic>> _invoices = [];
  String _invoiceStatus = '';
  bool _loadingInvoices = true;
  String? _invoiceError;

  List<Map<String, dynamic>> _packages = [];
  final Set<String> _selectedPackageIds = {};
  final TextEditingController _bhytCtrl = TextEditingController();
  final TextEditingController _voucherCtrl = TextEditingController();
  String _serviceType = 'Clinic';
  bool _isPriorityPatient = false;
  String? _voucherMessage;
  Map<String, dynamic>? _calcResult;
  bool _calculating = false;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
    _loadPackages();
  }

  @override
  void dispose() {
    _bhytCtrl.dispose();
    _voucherCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.textPrimary,
      ),
    );
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _loadingInvoices = true;
      _invoiceError = null;
    });
    try {
      final list = await _api.getInvoices(
        status: _invoiceStatus.isEmpty ? null : _invoiceStatus,
      );
      if (!mounted) return;
      setState(() {
        _invoices = list;
        _loadingInvoices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _invoiceError = e.toString().replaceFirst('BmsApiException: ', '');
        _loadingInvoices = false;
      });
    }
  }

  Future<void> _loadPackages() async {
    try {
      final pkgs = await _api.searchTestPackages();
      if (!mounted) return;
      setState(() {
        _packages = pkgs;
        if (_selectedPackageIds.isEmpty && pkgs.isNotEmpty) {
          final firstId = (pkgs.first['id'] ?? '').toString();
          if (firstId.isNotEmpty) _selectedPackageIds.add(firstId);
        }
      });
    } catch (_) {}
  }

  Future<void> _openCreateInvoiceModal() async {
    if (_packages.isEmpty) await _loadPackages();
    final patients = await _api.searchPatients(pageSize: 30);
    if (!mounted) return;

    Map<String, dynamic>? chosenPatient = patients.isNotEmpty
        ? patients.first
        : null;
    final selectedCodes = <String>{};
    bool creating = false;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tạo hóa đơn viện phí mới',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (patients.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: (chosenPatient?['id'] ?? '').toString(),
                    decoration: const InputDecoration(
                      labelText: 'Chọn bệnh nhân thanh toán',
                    ),
                    items: patients.map((p) {
                      final id = (p['id'] ?? '').toString();
                      final name = (p['fullName'] ?? id).toString();
                      final code = (p['patientCode'] ?? '').toString();
                      return DropdownMenuItem(
                        value: id,
                        child: Text(
                          code.isNotEmpty ? '$name ($code)' : name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final match = patients.where(
                        (p) => (p['id'] ?? '').toString() == val,
                      );
                      if (match.isNotEmpty) {
                        setSheetState(() => chosenPatient = match.first);
                      }
                    },
                  ),
                const SizedBox(height: 12),
                Text(
                  'Chọn dịch vụ xét nghiệm (${selectedCodes.length} mục)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _packages.length,
                    itemBuilder: (_, idx) {
                      final pkg = _packages[idx];
                      final code = (pkg['code'] ?? pkg['id'] ?? '').toString();
                      final name = (pkg['name'] ?? code).toString();
                      final price = num.tryParse(
                        (pkg['price'] ?? '0').toString(),
                      );
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primary,
                        value: selectedCodes.contains(code),
                        title: Text(name, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(BmsFormatters.currency(price)),
                        onChanged: (v) {
                          setSheetState(() {
                            if (v == true) {
                              selectedCodes.add(code);
                            } else {
                              selectedCodes.remove(code);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: creating
                      ? null
                      : () async {
                          if (chosenPatient == null || selectedCodes.isEmpty) {
                            _showSnack(
                              'Vui lòng chọn bệnh nhân và ít nhất 1 gói xét nghiệm.',
                              isError: true,
                            );
                            return;
                          }
                          setSheetState(() => creating = true);
                          final items = _packages
                              .where(
                                (p) => selectedCodes.contains(
                                  (p['code'] ?? p['id'] ?? '').toString(),
                                ),
                              )
                              .map(
                                (p) => {
                                  'itemCode':
                                      (p['code'] ?? p['id'] ?? '').toString(),
                                  'itemName': (p['name'] ?? '').toString(),
                                  'quantity': 1,
                                  'unitPrice':
                                      num.tryParse(
                                        (p['price'] ?? '0').toString(),
                                      ) ??
                                      0,
                                },
                              )
                              .toList();

                          try {
                            await _api.createInvoice(
                              patientId:
                                  (chosenPatient!['id'] ?? '').toString(),
                              patientName: (chosenPatient!['fullName'] ??
                                      'Bệnh nhân')
                                  .toString(),
                              patientPhone: (chosenPatient!['phoneNumber'] ??
                                      chosenPatient!['phone'] ??
                                      '')
                                  .toString(),
                              items: items,
                            );
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            setSheetState(() => creating = false);
                            _showSnack(
                              e.toString().replaceFirst(
                                'BmsApiException: ',
                                '',
                              ),
                              isError: true,
                            );
                          }
                        },
                  child: Text(creating ? 'Đang lập hóa đơn...' : 'Lập hóa đơn'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (created == true) {
      _showSnack('Đã lập hóa đơn viện phí thành công.');
      await _loadInvoices();
    }
  }

  Future<void> _openPayInvoiceModal(Map<String, dynamic> invoice) async {
    final id = (invoice['id'] ?? '').toString();
    final code = (invoice['invoiceCode'] ?? id).toString();
    final total = num.tryParse((invoice['totalAmount'] ?? '0').toString()) ?? 0;

    String method = 'Cash';
    final refCtrl = TextEditingController();
    bool paying = false;

    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Thu viện phí hóa đơn $code',
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              BmsInfoRow(
                label: 'Tổng tiền cần thu',
                value: BmsFormatters.currency(total),
                isBold: true,
                valueColor: AppColors.primary,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(
                  labelText: 'Phương thức thanh toán',
                ),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Tiền mặt tại quầy')),
                  DropdownMenuItem(
                    value: 'BankingQR',
                    child: Text('Chuyển khoản QR ngân hàng'),
                  ),
                  DropdownMenuItem(
                    value: 'CreditCard',
                    child: Text('Thẻ POS / Tín dụng'),
                  ),
                  DropdownMenuItem(value: 'VNPay', child: Text('Ví / Cổng VNPay')),
                ],
                onChanged: (v) {
                  if (v != null) setSheetState(() => method = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mã tham chiếu giao dịch (tùy chọn)',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
                onPressed: paying
                    ? null
                    : () async {
                        setSheetState(() => paying = true);
                        try {
                          await _api.payInvoice(
                            id,
                            paymentMethod: method,
                            transactionReference: refCtrl.text,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          setSheetState(() => paying = false);
                          _showSnack(
                            e.toString().replaceFirst('BmsApiException: ', ''),
                            isError: true,
                          );
                        }
                      },
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: Text(paying ? 'Đang xử lý...' : 'Xác nhận đã thu tiền'),
              ),
            ],
          ),
        ),
      ),
    );

    if (paid == true) {
      _showSnack('Đã thu phí thành công hóa đơn $code.');
      await _loadInvoices();
    }
  }

  Future<void> _openThermalReceiptK80(String invoiceId) async {
    try {
      final data = await _api.getReceiptPrintData(invoiceId);
      if (!mounted) return;

      final items = data['items'] is List
          ? (data['items'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      final qrPayload = (data['verificationQrPayload'] ??
              data['verificationUrl'] ??
              data['receiptNumber'] ??
              invoiceId)
          .toString();

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.84,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(20),
            children: [
              BmsSoftCard(
                backgroundColor: AppColors.surfaceMuted,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      (data['clinicName'] ??
                              'HỆ THỐNG PHÒNG KHÁM XÉT NGHIỆM BMS')
                          .toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      (data['clinicAddress'] ?? '').toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Divider(height: 22),
                    const Text(
                      'BIÊN LAI THU VIỆN PHÍ (KHỔ K80)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (data['reprintWarning'] != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        data['reprintWarning'].toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warningText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    BmsInfoRow(
                      label: 'Số biên lai',
                      value: (data['receiptNumber'] ?? '—').toString(),
                      isMono: true,
                    ),
                    BmsInfoRow(
                      label: 'Mã hóa đơn',
                      value: (data['invoiceCode'] ?? invoiceId).toString(),
                      isMono: true,
                    ),
                    BmsInfoRow(
                      label: 'Bệnh nhân',
                      value: (data['patientName'] ?? '—').toString(),
                      isBold: true,
                    ),
                    BmsInfoRow(
                      label: 'Thu ngân',
                      value: (data['cashierName'] ?? 'Lễ tân').toString(),
                    ),
                    BmsInfoRow(
                      label: 'Thời gian in',
                      value: BmsFormatters.dateTime(data['printedAt']),
                    ),
                    const Divider(height: 20),
                    ...items.map((it) {
                      final name = (it['itemName'] ?? it['itemCode'] ?? '')
                          .toString();
                      final qty = it['quantity'] ?? 1;
                      final total = num.tryParse(
                        (it['totalPrice'] ?? it['unitPrice'] ?? '0').toString(),
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$name (x$qty)',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                            Text(
                              BmsFormatters.currency(total),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 20),
                    BmsInfoRow(
                      label: 'Tạm tính',
                      value: BmsFormatters.currency(
                        num.tryParse((data['subTotal'] ?? '0').toString()),
                      ),
                    ),
                    BmsInfoRow(
                      label: 'Giảm trừ / Khuyến mãi',
                      value: BmsFormatters.currency(
                        num.tryParse(
                          (data['discountAmount'] ?? '0').toString(),
                        ),
                      ),
                    ),
                    BmsInfoRow(
                      label: 'TỔNG THANH TOÁN',
                      value: BmsFormatters.currency(
                        num.tryParse((data['totalAmount'] ?? '0').toString()),
                      ),
                      isBold: true,
                      valueColor: AppColors.primary,
                    ),
                    if ((data['totalAmountInWords'] ?? '')
                        .toString()
                        .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Bằng chữ: ${data['totalAmountInWords']}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: QrImageView(data: qrPayload, size: 130),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Mã QR đối soát xác thực biên lai điện tử',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng xem trước biên lai'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('BmsApiException: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _validateVoucherOnly() async {
    final code = _voucherCtrl.text.trim();
    if (code.isEmpty) {
      _showSnack('Nhập mã ưu đãi trước khi kiểm tra.', isError: true);
      return;
    }
    final subTotal = _packages
        .where((p) => _selectedPackageIds.contains((p['id'] ?? '').toString()))
        .fold<double>(
          0,
          (sum, p) => sum + (double.tryParse((p['price'] ?? '0').toString()) ?? 0),
        );

    try {
      final res = await _api.validateVoucher(
        voucherCode: code,
        currentSubTotal: subTotal,
        serviceType: _serviceType,
      );
      if (!mounted) return;
      setState(() {
        _voucherMessage = (res['message'] ?? res['description'] ?? 'Mã hợp lệ')
            .toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _voucherMessage = e.toString().replaceFirst('BmsApiException: ', '');
      });
    }
  }

  Future<void> _runCalculateFee() async {
    if (_selectedPackageIds.isEmpty) {
      _showSnack('Chọn ít nhất 1 gói xét nghiệm để tính dự toán.', isError: true);
      return;
    }
    setState(() => _calculating = true);
    try {
      final res = await _api.calculateFee(
        packageIds: _selectedPackageIds.toList(),
        serviceType: _serviceType,
        insuranceCardNumber: _bhytCtrl.text,
        voucherCode: _voucherCtrl.text,
        isPriorityPatient: _isPriorityPatient,
      );
      if (!mounted) return;
      setState(() {
        _calcResult = res;
        _calculating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _calculating = false);
      _showSnack(
        e.toString().replaceFirst('BmsApiException: ', ''),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        BmsPageHeaderCard(
          icon: Icons.receipt_long_rounded,
          badgeText: 'Tài chính & Bảo hiểm y tế',
          title: 'Viện phí & Dự toán BHYT',
          subtitle: 'Thu ngân hóa đơn, in biên lai nhiệt K80 và tính đồng chi trả BHYT',
          trailing: _subTab == 0
              ? IconButton(
                  tooltip: 'Tạo hóa đơn mới',
                  onPressed: _openCreateInvoiceModal,
                  icon: const Icon(
                    Icons.add_card_rounded,
                    color: AppColors.primary,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 14),
        BmsSegmentedTabs(
          tabs: const ['Sổ hóa đơn & Thu phí', 'Dự toán BHYT'],
          selectedIndex: _subTab,
          onChanged: (idx) => setState(() => _subTab = idx),
        ),
        const SizedBox(height: 14),
        if (_subTab == 0) _buildInvoicesSection() else _buildBhytCalculator(),
      ],
    );
  }

  Widget _buildInvoicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: BmsSearchFilterBar(
                filterChips: [
                  BmsFilterChipItem(
                    key: '',
                    label: 'Tất cả',
                    selected: _invoiceStatus == '',
                    onSelected: () {
                      setState(() => _invoiceStatus = '');
                      _loadInvoices();
                    },
                  ),
                  BmsFilterChipItem(
                    key: 'Unpaid',
                    label: 'Chờ thu phí',
                    selected: _invoiceStatus == 'Unpaid',
                    onSelected: () {
                      setState(() => _invoiceStatus = 'Unpaid');
                      _loadInvoices();
                    },
                  ),
                  BmsFilterChipItem(
                    key: 'Paid',
                    label: 'Đã thanh toán',
                    selected: _invoiceStatus == 'Paid',
                    onSelected: () {
                      setState(() => _invoiceStatus = 'Paid');
                      _loadInvoices();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _openCreateInvoiceModal,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tạo HĐ'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_loadingInvoices)
          const BmsLoadingState(message: 'Đang tải sổ hóa đơn viện phí...')
        else if (_invoiceError != null)
          BmsErrorState(message: _invoiceError!, onRetry: _loadInvoices)
        else if (_invoices.isEmpty)
          const BmsEmptyState(
            icon: Icons.receipt_outlined,
            title: 'Chưa có hóa đơn phù hợp',
            subtitle: 'Nhấn "Tạo HĐ" để lập hóa đơn mới cho bệnh nhân.',
          )
        else
          ..._invoices.map((inv) {
            final id = (inv['id'] ?? '').toString();
            final code = (inv['invoiceCode'] ?? id).toString();
            final patName = (inv['patientName'] ?? 'Bệnh nhân').toString();
            final total = num.tryParse((inv['totalAmount'] ?? '0').toString());
            final status = (inv['status'] ?? 'Unpaid').toString();
            final isPaid = status.toLowerCase() == 'paid';

            return BmsSoftCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          patName,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      BmsStatusPill(status: status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  BmsInfoRow(label: 'Mã hóa đơn', value: code, isMono: true),
                  BmsInfoRow(
                    label: 'Tổng thanh toán',
                    value: BmsFormatters.currency(total),
                    isBold: true,
                    valueColor: AppColors.primaryDark,
                  ),
                  BmsInfoRow(
                    label: 'Ngày lập',
                    value: BmsFormatters.dateTime(inv['createdAt']),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isPaid)
                        FilledButton.icon(
                          onPressed: () => _openPayInvoiceModal(inv),
                          icon: const Icon(Icons.payments_outlined, size: 17),
                          label: const Text('Thu phí'),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () => _openThermalReceiptK80(id),
                          icon: const Icon(Icons.print_outlined, size: 17),
                          label: const Text('Xem biên lai nhiệt K80'),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBhytCalculator() {
    final items = _calcResult?['items'] is List
        ? (_calcResult!['items'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BmsSoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '1. Chọn gói xét nghiệm dự toán',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _packages.length,
                  itemBuilder: (_, idx) {
                    final pkg = _packages[idx];
                    final id = (pkg['id'] ?? '').toString();
                    final name = (pkg['name'] ?? '').toString();
                    final price = num.tryParse(
                      (pkg['price'] ?? '0').toString(),
                    );
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      value: _selectedPackageIds.contains(id),
                      title: Text(name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(BmsFormatters.currency(price)),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedPackageIds.add(id);
                          } else {
                            _selectedPackageIds.remove(id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 22),
              const Text(
                '2. Mã thẻ BHYT (15 ký tự) & Chế độ khám',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _bhytPresets.map((p) {
                  return ActionChip(
                    label: Text(p.label, style: const TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => _bhytCtrl.text = p.card),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bhytCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Số thẻ BHYT (15 ký tự)',
                  hintText: 'DN4797938500003',
                  prefixIcon: Icon(Icons.health_and_safety_outlined, size: 19),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _serviceType,
                decoration: const InputDecoration(
                  labelText: 'Hình thức lấy mẫu',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Clinic',
                    child: Text('Lấy mẫu tại phòng khám (Miễn phụ phí)'),
                  ),
                  DropdownMenuItem(
                    value: 'HomeCollection',
                    child: Text('Lấy mẫu tận nơi (+150.000 đ)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _serviceType = v);
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _voucherCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Mã ưu đãi (BMS10, BMS20...)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _validateVoucherOnly,
                    child: const Text('Kiểm tra mã'),
                  ),
                ],
              ),
              if (_voucherMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  _voucherMessage!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppColors.primary,
                value: _isPriorityPatient,
                title: const Text('Đối tượng ưu tiên (Cao tuổi / Trẻ nhỏ)'),
                onChanged: (v) =>
                    setState(() => _isPriorityPatient = v ?? false),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _calculating ? null : _runCalculateFee,
                icon: const Icon(Icons.calculate_rounded, size: 19),
                label: Text(
                  _calculating ? 'Đang tính toán...' : 'Tính dự toán chi phí',
                ),
              ),
            ],
          ),
        ),
        if (_calcResult != null) ...[
          const SizedBox(height: 14),
          BmsSoftCard(
            borderColor: AppColors.primary.withValues(alpha: 0.35),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Bảng chiết tính viện phí & BHYT',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                ...items.map((it) {
                  final name = (it['itemName'] ?? '').toString();
                  final bhyt = num.tryParse(
                    (it['bhytCoveredAmount'] ?? '0').toString(),
                  );
                  final pay = num.tryParse(
                    (it['patientPayAmount'] ?? '0').toString(),
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Quỹ BHYT chi trả: ${BmsFormatters.currency(bhyt)} · BN đồng chi trả: ${BmsFormatters.currency(pay)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 20),
                BmsInfoRow(
                  label: 'Tổng phí xét nghiệm',
                  value: BmsFormatters.currency(
                    num.tryParse(
                      (_calcResult!['testSubTotal'] ?? '0').toString(),
                    ),
                  ),
                ),
                BmsInfoRow(
                  label: 'Phụ phí lấy mẫu tận nơi',
                  value: BmsFormatters.currency(
                    num.tryParse(
                      (_calcResult!['homeCollectionSurcharge'] ?? '0')
                          .toString(),
                    ),
                  ),
                ),
                BmsInfoRow(
                  label:
                      'Quỹ BHYT thanh toán (${_calcResult!['insuranceCoveragePercent'] ?? 0}%)',
                  value:
                      '- ${BmsFormatters.currency(num.tryParse((_calcResult!['insuranceDeduction'] ?? '0').toString()))}',
                  valueColor: AppColors.successText,
                ),
                BmsInfoRow(
                  label: 'Khuyến mãi / Ưu tiên',
                  value:
                      '- ${BmsFormatters.currency(num.tryParse((_calcResult!['totalDiscount'] ?? '0').toString()))}',
                ),
                BmsInfoRow(
                  label: 'BỆNH NHÂN THỰC ĐÓNG',
                  value: BmsFormatters.currency(
                    num.tryParse(
                      (_calcResult!['netTotalPayable'] ?? '0').toString(),
                    ),
                  ),
                  isBold: true,
                  valueColor: AppColors.primary,
                ),
                if ((_calcResult!['totalInWords'] ?? '')
                    .toString()
                    .isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Bằng chữ: ${_calcResult!['totalInWords']}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
