import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'invoice_detail_screen.dart';

/// Patient Medical Billing & Payment History Screen (UC43 / UC23 / Iteration 2).
/// Displays transaction receipts, billing status, and electronic invoice lookup.
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _invoices = [
    {
      'id': 'INV-20261020-8849',
      'receiptNumber': 'REC-20261020-0092',
      'title': 'Khám Nội Tổng Quát + Xét Nghiệm Máu (CBC, Glucose)',
      'date': '20/10/2026 09:30',
      'amount': 350000.0,
      'amountInWords': 'Ba trăm năm mươi nghìn đồng chẵn',
      'status': 'Paid',
      'method': 'VNPay QR',
      'items': [
        {'name': 'Khám Nội Tổng Quát Bác Sĩ Chuyên Khoa', 'qty': 1, 'price': 150000.0},
        {'name': 'Tổng Phân Tích Tế Bào Máu (CBC)', 'qty': 1, 'price': 120000.0},
        {'name': 'Xét Nghiệm Đường Huyết Đói (Glucose)', 'qty': 1, 'price': 80000.0},
      ],
    },
    {
      'id': 'INV-20261015-7721',
      'receiptNumber': 'REC-20261015-0044',
      'title': 'Gói Tầm Soát Viêm Gan Siêu Vi B & C (HBsAg, Anti-HCV)',
      'date': '15/10/2026 14:15',
      'amount': 520000.0,
      'amountInWords': 'Năm trăm hai mươi nghìn đồng chẵn',
      'status': 'Paid',
      'method': 'Tiền mặt (POS Cashier)',
      'items': [
        {'name': 'Định lượng HBsAg Miễn Dịch', 'qty': 1, 'price': 280000.0},
        {'name': 'Kháng thể Anti-HCV', 'qty': 1, 'price': 240000.0},
      ],
    },
    {
      'id': 'INV-20261022-9901',
      'receiptNumber': '',
      'title': 'Xét Nghiệm Chức Năng Gan Mật (AST, ALT, GGT)',
      'date': 'Hôm nay 08:00',
      'amount': 180000.0,
      'amountInWords': 'Một trăm tám mươi nghìn đồng chẵn',
      'status': 'Unpaid',
      'method': 'Chưa thanh toán',
      'items': [
        {'name': 'Men gan AST/SGOT', 'qty': 1, 'price': 60000.0},
        {'name': 'Men gan ALT/SGPT', 'qty': 1, 'price': 60000.0},
        {'name': 'Men gan GGT huyết thanh', 'qty': 1, 'price': 60000.0},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterInvoices(int tabIndex) {
    if (tabIndex == 1) {
      return _invoices.where((i) => i['status'] == 'Paid').toList();
    } else if (tabIndex == 2) {
      return _invoices.where((i) => i['status'] == 'Unpaid').toList();
    }
    return _invoices;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch Sử Viện Phí & Biên Lai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Tất cả'),
            Tab(text: 'Đã thanh toán'),
            Tab(text: 'Chờ thanh toán'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInvoiceList(0),
          _buildInvoiceList(1),
          _buildInvoiceList(2),
        ],
      ),
    );
  }

  Widget _buildInvoiceList(int tabIndex) {
    final list = _filterInvoices(tabIndex);

    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.textDisabled),
              SizedBox(height: 12),
              Text(
                'Không có hóa đơn nào',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final inv = list[index];
        final isPaid = inv['status'] == 'Paid';
        final amount = inv['amount'] as double;

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (isPaid) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoiceDetailScreen(
                    invoiceCode: inv['id'] as String,
                    receiptNumber: inv['receiptNumber'] as String,
                    date: inv['date'] as String,
                    totalAmount: amount,
                    amountInWords: inv['amountInWords'] as String,
                    paymentMethod: inv['method'] as String,
                    isPaid: true,
                    items: List<Map<String, dynamic>>.from(inv['items'] as List),
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vui lòng đến quầy thu ngân phòng khám hoặc thanh toán qua ứng dụng để nhận biên lai.'),
                  backgroundColor: AppColors.warning,
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      inv['id'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPaid ? AppColors.successLight : AppColors.warningLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isPaid ? AppColors.success : AppColors.warning),
                      ),
                      child: Text(
                        isPaid ? '✓ Đã thanh toán' : 'Chờ thanh toán',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isPaid ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  inv['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      inv['date'] as String,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (isPaid) ...[
                  const Divider(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Xem Biên Lai & Mã QR >',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
