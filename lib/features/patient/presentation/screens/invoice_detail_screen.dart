import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Patient Electronic Receipt & Invoice Detail Screen (UC43 / Iteration 2).
/// Displays itemized medical billing, payment method, QR code verification, and receipt export.
class InvoiceDetailScreen extends StatelessWidget {
  final String invoiceCode;
  final String receiptNumber;
  final String patientName;
  final String date;
  final double totalAmount;
  final String amountInWords;
  final String paymentMethod;
  final bool isPaid;
  final List<Map<String, dynamic>> items;

  const InvoiceDetailScreen({
    super.key,
    this.invoiceCode = 'INV-20261020-8849',
    this.receiptNumber = 'REC-20261020-0092',
    this.patientName = 'Nguyễn Văn An',
    this.date = '20/10/2026 09:30',
    this.totalAmount = 350000,
    this.amountInWords = 'Ba trăm năm mươi nghìn đồng chẵn',
    this.paymentMethod = 'VNPay QR',
    this.isPaid = true,
    this.items = const [
      {
        'name': 'Khám Nội Tổng Quát Bác Sĩ Chuyên Khoa',
        'qty': 1,
        'price': 150000.0,
      },
      {
        'name': 'Xét Nghiệm Tổng Phân Tích Tế Bào Máu (CBC)',
        'qty': 1,
        'price': 120000.0,
      },
      {
        'name': 'Xét Nghiệm Đường Huyết Đói (Glucose)',
        'qty': 1,
        'price': 80000.0,
      },
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Biên Lai Điện Tử (K80)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Chia sẻ biên lai',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đang tạo liên kết chia sẻ biên lai điện tử...'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Thermal Receipt Simulation Card
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Clinic Header
                  const Center(
                    child: Column(
                      children: [
                        Text(
                          'HỆ THỐNG PHÒNG KHÁM BMS',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Khu Công nghệ cao, TP. Thủ Đức, TP. HCM',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        Text(
                          'Hotline: 1900 6868 - MST: 0314567890',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'BIÊN LAI THU TIỀN VIỆN PHÍ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          '(HÓA ĐƠN ĐIỆN TỬ HỢP LỆ)',
                          style: TextStyle(fontSize: 10, color: AppColors.textDisabled),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildDashedLine(),
                  const SizedBox(height: 12),

                  // Metadata Info
                  _buildMetaRow('Số biên lai:', receiptNumber, isBold: true),
                  _buildMetaRow('Mã hóa đơn:', invoiceCode),
                  _buildMetaRow('Thời gian:', date),
                  _buildMetaRow('Bệnh nhân:', patientName, isBold: true),
                  _buildMetaRow('Hình thức:', paymentMethod),

                  const SizedBox(height: 12),
                  _buildDashedLine(),
                  const SizedBox(height: 12),

                  // Line Items
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Dịch vụ / Xét nghiệm',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                      Text(
                        'SL',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                      ),
                      SizedBox(width: 24),
                      Text(
                        'Thành tiền',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ...items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item['name'] as String,
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          ),
                        ),
                        Text(
                          '${item['qty']}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 24),
                        Text(
                          '${((item['price'] as double) * (item['qty'] as int)).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  )),

                  const SizedBox(height: 12),
                  _buildDashedLine(),
                  const SizedBox(height: 12),

                  // Totals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TỔNG CỘNG:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} VNĐ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bằng chữ: $amountInWords',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                  ),

                  const SizedBox(height: 20),
                  _buildDashedLine(),
                  const SizedBox(height: 16),

                  // QR Verification
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.qr_code_2_rounded, size: 88, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Mã đối soát: $receiptNumber',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Xuất trình mã QR tại phòng xét nghiệm hoặc quầy thuốc',
                          style: TextStyle(fontSize: 10, color: AppColors.textDisabled),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Download PDF Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đang tải hóa đơn điện tử định dạng PDF về máy...'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Tải Biên Lai Điện Tử (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFCBD5E1)),
              ),
            );
          }),
        );
      },
    );
  }
}
