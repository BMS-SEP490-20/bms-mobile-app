import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../appointment/data/appointment_repository.dart';

/// UC23 – View Appointments Mobile Screen (Flutter).
/// Provides patients with real-time tracking of their clinical appointments,
/// filtering by status, pull-to-refresh, appointment detail inspection,
/// and instant Check-in barcode modal.
class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppointmentRepository _repository = AppointmentRepository();

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _appointments = [];

  final List<String> _tabs = [
    'Tất cả',
    'Sắp tới',
    'Đã khám',
    'Đã hủy',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _repository.fetchMyAppointments(pageSize: 50);
      if (mounted) {
        setState(() {
          _appointments = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredList(int tabIndex) {
    if (_appointments.isEmpty) return [];

    switch (tabIndex) {
      case 1: // Sắp tới: Pending, Confirmed, CheckedIn, InProgress
        return _appointments.where((a) {
          final s = (a['status'] ?? '').toString().toLowerCase();
          return s == 'pending' ||
              s == 'confirmed' ||
              s == 'checkedin' ||
              s == 'checked_in' ||
              s == 'inprogress' ||
              s == 'in_progress';
        }).toList();
      case 2: // Đã khám: Completed
        return _appointments.where((a) {
          final s = (a['status'] ?? '').toString().toLowerCase();
          return s == 'completed';
        }).toList();
      case 3: // Đã hủy / NoShow: Cancelled, NoShow
        return _appointments.where((a) {
          final s = (a['status'] ?? '').toString().toLowerCase();
          return s == 'cancelled' || s == 'noshow' || s == 'no_show';
        }).toList();
      default: // Tất cả
        return _appointments;
    }
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('confirm')) return const Color(0xFF0284C7); // Sky Blue
    if (s.contains('pend')) return const Color(0xFFD97706); // Amber
    if (s.contains('checked') || s.contains('progress')) return const Color(0xFF6366F1); // Indigo
    if (s.contains('complet')) return const Color(0xFF16A34A); // Emerald Green
    if (s.contains('cancel') || s.contains('noshow')) return const Color(0xFFDC2626); // Crimson
    return Colors.grey.shade600;
  }

  String _getStatusLabel(String status) {
    final s = status.toLowerCase();
    if (s.contains('confirm')) return 'Đã xác nhận';
    if (s.contains('pend')) return 'Chờ tiếp nhận';
    if (s.contains('checked')) return 'Đã tiếp nhận';
    if (s.contains('progress')) return 'Đang thực hiện';
    if (s.contains('complet')) return 'Hoàn thành';
    if (s.contains('cancel')) return 'Đã hủy';
    if (s.contains('noshow')) return 'Vắng mặt';
    return status;
  }

  void _showCheckInCodeModal(Map<String, dynamic> appointment) {
    final code = appointment['appointmentCode'] ?? appointment['appointmentId'] ?? 'N/A';
    final dateStr = appointment['appointmentDate'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(appointment['appointmentDate']))
        : 'N/A';
    final timeStr = appointment['slotTime'] ?? '30 phút';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.qr_code_scanner_rounded, size: 48, color: Color(0xFF0284C7)),
              const SizedBox(height: 12),
              const Text(
                'Mã Tiếp Nhận Tại Viện',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                'Xuất trình mã này cho Tiếp tân hoặc Quét tại Kiosk lấy số',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              // Barcode display simulation card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Text(
                      code.toString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Simulated barcode stripes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(32, (index) {
                        final isThick = index % 3 == 0 || index % 7 == 0;
                        return Container(
                          width: isThick ? 4 : 2,
                          height: 48,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          color: index % 5 == 0 ? Colors.transparent : Colors.black87,
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text('Ngày: $dateStr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('Giờ: $timeStr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> item) {
    final code = item['appointmentCode'] ?? item['appointmentId'] ?? 'N/A';
    final rawStatus = (item['status'] ?? 'Pending').toString();
    final statusColor = _getStatusColor(rawStatus);
    final statusLabel = _getStatusLabel(rawStatus);

    final rawDate = item['appointmentDate'];
    String dateStr = 'N/A';
    if (rawDate != null) {
      try {
        dateStr = DateFormat('dd/MM/yyyy').format(DateTime.parse(rawDate.toString()));
      } catch (_) {
        dateStr = rawDate.toString();
      }
    }

    final slotTime = item['slotTime'] ?? '30 phút';
    final doctorName = item['doctorName'] ?? 'Bác sĩ chuyên khoa';
    final specialty = item['specialty'] ?? '';
    final isHome = (item['appointmentType'] ?? '').toString().toLowerCase().contains('home');
    final address = item['collectionAddress'];
    final packageName = item['testPackageName'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Code & Status
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      code.toString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Body Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.event_available_rounded, size: 20, color: Color(0xFF0284C7)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Khung giờ: $slotTime',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Doctor Info
                Row(
                  children: [
                    const Icon(Icons.person_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        specialty.isNotEmpty ? '$doctorName ($specialty)' : doctorName,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Location / Visit Type
                Row(
                  children: [
                    Icon(
                      isHome ? Icons.home_rounded : Icons.local_hospital_rounded,
                      size: 16,
                      color: isHome ? const Color(0xFFD97706) : const Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isHome
                            ? (address != null && address.toString().isNotEmpty
                                ? 'Tại nhà: $address'
                                : 'Lấy mẫu tại nhà')
                            : 'Phòng khám Đa khoa Quốc tế BMS',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                if (packageName != null && packageName.toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'Gói: $packageName',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Footer Action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showCheckInCodeModal(item),
                  icon: const Icon(Icons.qr_code_rounded, size: 16),
                  label: const Text('Mã Check-in', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    side: const BorderSide(color: Color(0xFFBAE6FD)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_today_rounded, size: 48, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có lịch hẹn nào',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Text(
              'Các lịch hẹn khám & lấy mẫu của bạn sẽ xuất hiện tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadAppointments,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Tải lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Lịch Hẹn Của Tôi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0284C7),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF0284C7),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _tabs.map((title) => Tab(text: title)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAppointments,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: List.generate(_tabs.length, (index) {
                    final list = _getFilteredList(index);
                    if (list.isEmpty) {
                      return _buildEmptyState();
                    }
                    return RefreshIndicator(
                      onRefresh: _loadAppointments,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: list.length,
                        itemBuilder: (context, i) => _buildAppointmentCard(list[i]),
                      ),
                    );
                  }),
                ),
    );
  }
}
