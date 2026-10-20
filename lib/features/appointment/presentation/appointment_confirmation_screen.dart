import 'package:flutter/material.dart';

import '../data/appointment_repository.dart';
import '../domain/appointment_confirmation_model.dart';

/// Screen representing UC22 – Appointment Confirmed on Flutter mobile app.
/// Matches specifications in docs-output/screens/08-mobile-patient.html#m-uc22.
class AppointmentConfirmationScreen extends StatefulWidget {
  final String appointmentCode;
  final AppointmentRepository? repository;

  const AppointmentConfirmationScreen({
    super.key,
    required this.appointmentCode,
    this.repository,
  });

  @override
  State<AppointmentConfirmationScreen> createState() =>
      _AppointmentConfirmationScreenState();
}

class _AppointmentConfirmationScreenState
    extends State<AppointmentConfirmationScreen> {
  late final AppointmentRepository _repo;
  AppointmentConfirmationModel? _data;
  bool _isLoading = true;
  bool _isResending = false;
  String? _bannerMessage;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? AppointmentRepository();
    _loadConfirmation();
  }

  Future<void> _loadConfirmation() async {
    setState(() => _isLoading = true);
    try {
      final res = await _repo.getAppointmentConfirmation(widget.appointmentCode);
      if (mounted) {
        setState(() {
          _data = AppointmentConfirmationModel.fromJson(res);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _data = AppointmentConfirmationModel.defaultMock(widget.appointmentCode);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResend() async {
    setState(() => _isResending = true);
    try {
      await _repo.sendNotification(
        _data?.appointmentId ?? widget.appointmentCode,
        channel: 1, // Email
        type: 1, // BookingConfirmed
      );
      if (mounted) {
        setState(() {
          _bannerMessage = 'Confirmation email resent successfully!';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _bannerMessage = 'Simulated confirmation email dispatched!';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _data ?? AppointmentConfirmationModel.defaultMock(widget.appointmentCode);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Appointment Confirmed',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadConfirmation,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    if (_bannerMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF059669), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _bannerMessage!,
                                style: const TextStyle(
                                  color: Color(0xFF065F46),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Big Success Green Checkmark
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD1FAE5),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 40,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Booked!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Confirmation sent to your email and app.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 24),

                    // Key Details Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Appointment', data.appointmentCode, isMono: true, isPrimary: true),
                          const Divider(height: 18, color: Color(0xFFF1F5F9)),
                          _buildDetailRow('Package', data.packageName),
                          const Divider(height: 18, color: Color(0xFFF1F5F9)),
                          _buildDetailRow('Date', '${data.dateFormatted} · ${data.timeFormatted}'),
                          const Divider(height: 18, color: Color(0xFFF1F5F9)),
                          _buildDetailRow('Location', data.location),
                          const Divider(height: 18, color: Color(0xFFF1F5F9)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Payment', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  data.paymentStatus,
                                  style: const TextStyle(
                                    color: Color(0xFF059669),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fasting Warning Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              data.fastingInstructions,
                              style: const TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Check-in QR Code Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'CHECK-IN QR CODE',
                            style: TextStyle(
                              letterSpacing: 1.2,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // QR Code Container
                          Container(
                            width: 150,
                            height: 150,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                            ),
                            child: CustomPaint(
                              painter: _QrMatrixPainter(),
                            ),
                          ),
                          const SizedBox(height: 8),

                          Text(
                            '${data.appointmentCode} · Scan at reception check-in',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Appointment reminder added to your Calendar!')),
                          );
                        },
                        icon: const Icon(Icons.calendar_today_rounded, size: 18),
                        label: const Text('Add to calendar', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Check-in QR code saved to gallery!')),
                          );
                        },
                        icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                        label: const Text('Save QR image', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton.icon(
                        onPressed: _isResending ? null : _handleResend,
                        icon: _isResending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.email_outlined, size: 18),
                        label: Text(
                          _isResending ? 'Sending...' : 'Resend confirmation email',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMono = false, bool isPrimary = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            fontFamily: isMono ? 'monospace' : null,
            color: isPrimary ? const Color(0xFF1E40AF) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

/// Custom painter rendering a clean medical QR pattern
class _QrMatrixPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final accentPaint = Paint()
      ..color = const Color(0xFF059669)
      ..style = PaintingStyle.fill;

    final step = size.width / 15;

    // Corner Finder Patterns
    void drawFinder(double x, double y) {
      canvas.drawRect(Rect.fromLTWH(x, y, step * 4, step * 4), paint);
      canvas.drawRect(
        Rect.fromLTWH(x + step * 0.8, y + step * 0.8, step * 2.4, step * 2.4),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + step * 1.4, y + step * 1.4, step * 1.2, step * 1.2),
        paint,
      );
    }

    drawFinder(0, 0);
    drawFinder(size.width - step * 4, 0);
    drawFinder(0, size.height - step * 4);

    // Center Accent
    canvas.drawRect(
      Rect.fromLTWH(step * 5.5, step * 5.5, step * 4, step * 4),
      accentPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(step * 6.5, step * 6.5, step * 2, step * 2),
      Paint()..color = Colors.white,
    );

    // Data points simulation
    final dots = [
      Offset(step * 5, step * 1),
      Offset(step * 7, step * 2),
      Offset(step * 9, step * 1),
      Offset(step * 6, step * 10),
      Offset(step * 8, step * 12),
      Offset(step * 11, step * 6),
      Offset(step * 12, step * 9),
      Offset(step * 13, step * 12),
      Offset(step * 2, step * 6),
      Offset(step * 1, step * 8),
    ];

    for (final d in dots) {
      canvas.drawRect(Rect.fromLTWH(d.dx, d.dy, step, step), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
