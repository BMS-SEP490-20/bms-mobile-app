import 'package:flutter/material.dart';
import '../../data/payment_repository.dart';
import '../../models/payment_checkout_model.dart';

/// Screen representing UC55 – Process Payment on Flutter mobile app.
/// Matches specifications in docs-output/screens/08-mobile-patient.html#m-uc55.
/// Conforms to: Production Standards & AGENTS.md.
class ProcessPaymentScreen extends StatefulWidget {
  final String? invoiceId;
  final PaymentRepository? repository;

  const ProcessPaymentScreen({
    super.key,
    this.invoiceId,
    this.repository,
  });

  @override
  State<ProcessPaymentScreen> createState() => _ProcessPaymentScreenState();
}

class _ProcessPaymentScreenState extends State<ProcessPaymentScreen> {
  late final PaymentRepository _repo;

  PaymentCheckoutModel? _checkoutData;
  String _paymentMethod = 'VNPay'; // VNPay | MoMo | Reception
  final TextEditingController _discountController = TextEditingController(text: 'SPRING10');
  double _appliedDiscountAmount = 0.0;
  String? _appliedDiscountCode;

  bool _isLoading = true;
  bool _isSubmitting = false;
  PaymentCheckoutModel? _successResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? PaymentRepository();
    _loadCheckout();
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckout() async {
    final targetId = widget.invoiceId ?? 'INV-261006-0342';
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _repo.getCheckoutSummary(targetId);
      if (mounted) {
        setState(() {
          _checkoutData = res;
          _appliedDiscountAmount = res?.discountAmount ?? 0.0;
          _appliedDiscountCode = res?.discountCode;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load invoice from database.';
        });
      }
    }
  }

  Future<void> _handleApplyDiscount() async {
    final code = _discountController.text.trim();
    if (code.isEmpty) return;

    final targetId = _checkoutData?.invoiceId ?? widget.invoiceId ?? '';
    try {
      final res = await _repo.applyDiscount(targetId, code);
      if (res != null && res['success'] == true && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _appliedDiscountAmount = (data['discountAmount'] as num?)?.toDouble() ?? 0.0;
          _appliedDiscountCode = data['discountCode']?.toString();
          _errorMessage = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message']?.toString() ?? 'Discount applied.'),
              backgroundColor: const Color(0xFF198754),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid or expired discount code.';
        });
      }
    } catch (_) {
      setState(() {
        _errorMessage = 'Failed to validate discount code.';
      });
    }
  }

  Future<void> _handlePayNow() async {
    final targetId = _checkoutData?.invoiceId ?? widget.invoiceId ?? '';
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final payload = {
        'invoiceId': targetId,
        'paymentMethod': _paymentMethod,
        'discountCode': _appliedDiscountCode ?? _discountController.text.trim(),
      };

      final result = await _repo.processPayment(payload);
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _successResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Payment processing failed. Please try again.';
        });
      }
    }
  }

  double get _currentSubTotal => _checkoutData?.subTotal ?? 250000.0;
  double get _currentTotalDue {
    final due = _currentSubTotal - _appliedDiscountAmount;
    return due > 0 ? due : 0.0;
  }

  String _formatVnd(double val) {
    return val.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Payment',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _successResult != null
              ? _buildSuccessView()
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDE8E8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF8B4B4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFE02424), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Color(0xFFE02424), fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Card 1: Order Summary
                      _buildSummaryCard(),

                      const SizedBox(height: 12),

                      // Card 2: Discount Voucher
                      _buildDiscountCard(),

                      const SizedBox(height: 12),

                      // Card 3: Payment Method
                      _buildPaymentMethodCard(),

                      const SizedBox(height: 24),

                      // Pay Now Button
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _handlePayNow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0353E9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.shield_outlined, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pay now · ${_formatVnd(_currentTotalDue)} ₫',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ],
                              ),
                      ),

                      const SizedBox(height: 10),

                      // Security Disclaimer
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline, size: 12, color: Color(0xFF6B7280)),
                          SizedBox(width: 4),
                          Text(
                            'Secured by VNPay · PCI DSS compliant',
                            style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _checkoutData?.packageName ?? 'Lipid Profile',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                _formatVnd(_currentSubTotal),
                style: const TextStyle(fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (_appliedDiscountAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_appliedDiscountCode ?? "PROMO"} (-10%)',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0E9F6E), fontWeight: FontWeight.w500),
                ),
                Text(
                  '-${_formatVnd(_appliedDiscountAmount)}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0E9F6E), fontFamily: 'monospace'),
                ),
              ],
            ),
          ],
          const Divider(height: 24, thickness: 1, color: Color(0xFFF3F4F6)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_formatVnd(_currentTotalDue)} ₫',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0353E9),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_outlined, color: Color(0xFF6B7280), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _discountController,
              decoration: const InputDecoration(
                hintText: 'Voucher code (e.g. SPRING10)',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _handleApplyDiscount,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              backgroundColor: const Color(0xFFF3F4F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Apply', style: TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment method',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildMethodOption(
            id: 'VNPay',
            title: 'VNPay',
            subtitle: 'Card, ATM, QR',
            icon: Icons.credit_card_outlined,
          ),
          _buildMethodOption(
            id: 'MoMo',
            title: 'MoMo',
            subtitle: 'E-wallet',
            icon: Icons.account_balance_wallet_outlined,
          ),
          _buildMethodOption(
            id: 'Reception',
            title: 'Pay at reception',
            subtitle: 'Cash or card on arrival',
            icon: Icons.storefront_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildMethodOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _paymentMethod == id;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF0353E9) : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: id,
              groupValue: _paymentMethod,
              activeColor: const Color(0xFF0353E9),
              onChanged: (val) {
                if (val != null) setState(() => _paymentMethod = val);
              },
            ),
            Icon(icon, size: 20, color: isSelected ? const Color(0xFF0353E9) : const Color(0xFF6B7280)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFDEF7EC),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 54, color: Color(0xFF0E9F6E)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Successful',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              _successResult?.message ?? 'Your payment has been recorded.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Invoice Code:', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      Text(_successResult?.invoiceCode ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Paid:', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      Text(
                        '${_formatVnd(_successResult?.totalAmount ?? _currentTotalDue)} ₫',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0E9F6E)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0353E9),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
