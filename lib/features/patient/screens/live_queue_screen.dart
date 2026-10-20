import 'dart:async';
import 'package:flutter/material.dart';

import '../../appointment/data/appointment_repository.dart';

/// UC28 – Live Queue Patient Mobile Screen (Flutter).
/// Real-time live queue tracking for patients waiting at the clinic,
/// showing active queue position, people ahead, estimated wait time,
/// and instant notification when called to consultation room.
class LiveQueueScreen extends StatefulWidget {
  const LiveQueueScreen({super.key});

  @override
  State<LiveQueueScreen> createState() => _LiveQueueScreenState();
}

class _LiveQueueScreenState extends State<LiveQueueScreen> {
  final AppointmentRepository _repository = AppointmentRepository();

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _queueStatus;
  Map<String, dynamic>? _myActiveTicket;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadQueue();
    // Auto-refresh every 5 seconds while on this screen
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadQueue(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadQueue({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final queueData = await _repository.fetchQueueStatus();
      final myAppointments = await _repository.fetchMyAppointments(pageSize: 10);

      // Look for today's active ticket (InProgress or CheckedIn)
      Map<String, dynamic>? active;
      for (final apt in myAppointments) {
        final s = (apt['status'] ?? '').toString().toLowerCase();
        if (s == 'inprogress' || s == 'in_progress' || s == 'checkedin' || s == 'checked_in') {
          active = apt;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _queueStatus = queueData;
          _myActiveTicket = active;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  int _calculatePeopleAhead() {
    if (_myActiveTicket == null || _queueStatus == null) return 0;
    final myNum = _myActiveTicket!['queueNumber'];
    if (myNum == null) return 0;

    final waiting = _queueStatus!['waitingList'] as List<dynamic>? ?? [];
    int ahead = 0;
    for (final item in waiting) {
      if (item is Map<String, dynamic>) {
        final qNum = item['queueNumber'];
        if (qNum != null && (qNum as num) < (myNum as num)) {
          ahead++;
        }
      }
    }
    return ahead;
  }

  @override
  Widget build(BuildContext context) {
    final currentServing = _queueStatus?['currentServing'] as Map<String, dynamic>?;
    final waitingList = _queueStatus?['waitingList'] as List<dynamic>? ?? [];

    final isMyTurn = _myActiveTicket != null &&
        (_myActiveTicket!['status'] ?? '').toString().toLowerCase().contains('progress');

    final peopleAhead = _calculatePeopleAhead();
    final estimatedWaitMinutes = peopleAhead * 15;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Hàng Đợi Khám Trực Tuyến',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            onPressed: () => _loadQueue(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
          ),
        ],
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
                          onPressed: () => _loadQueue(),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadQueue(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Live Calling Alert Banner (if it's patient's turn)
                        if (isMyTurn) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withAlpha(80),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.volume_up_rounded, color: Colors.white, size: 44),
                                const SizedBox(height: 8),
                                const Text(
                                  'ĐÃ ĐẾN LƯỢT BẠN!',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Vui lòng di chuyển vào: ${_myActiveTicket?['roomId'] ?? 'Phòng Khám 101'}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(50),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    'Số thứ tự: ${_myActiveTicket?['queueNumber'] != null ? "Q-${_myActiveTicket!['queueNumber'].toString().padLeft(3, '0')}" : "N/A"}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ] else if (_myActiveTicket != null) ...[
                          // Patient has checked-in ticket and waiting
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFBAE6FD)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withAlpha(15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Số Thứ Tự Của Bạn',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Đang chờ khám',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _myActiveTicket!['queueNumber'] != null
                                      ? 'Q-${_myActiveTicket!['queueNumber'].toString().padLeft(3, '0')}'
                                      : 'ĐÃ TIẾP NHẬN',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0284C7),
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Divider(height: 1),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        Text(
                                          '$peopleAhead người',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text('Đang chờ phía trước', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                    Container(width: 1, height: 32, color: Colors.grey.shade200),
                                    Column(
                                      children: [
                                        Text(
                                          '~$estimatedWaitMinutes phút',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text('Dự kiến còn lại', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ] else ...[
                          // No active ticket checked in
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 28),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Bạn chưa lấy số hôm nay',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Xuất trình mã lịch hẹn tại Quầy tiếp đón để được cấp số thứ tự vào phòng khám.',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Currently Serving Card at Clinic
                        const Text(
                          'Đang Phục Vụ Tại Phòng Khám',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 10),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: currentServing != null
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentServing['roomId'] ?? 'Phòng 101',
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          currentServing['patientName'] ?? 'Bệnh nhân',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAB308),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        currentServing['queueNumberFormatted'] ??
                                            (currentServing['queueNumber'] != null
                                                ? 'Q-${currentServing['queueNumber'].toString().padLeft(3, '0')}'
                                                : 'Q-000'),
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Center(
                                    child: Text(
                                      'Chưa có bệnh nhân nào đang trong phòng khám',
                                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),

                        // Upcoming Waiting List
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Hàng Đợi Chờ Lượt',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              '${waitingList.length} người chờ',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (waitingList.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            alignment: Alignment.center,
                            child: Text(
                              'Hàng đợi hiện đang rỗng',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: waitingList.length,
                            separatorBuilder: (_, index) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final item = waitingList[i] as Map<String, dynamic>;
                              final qNumStr = item['queueNumberFormatted'] ??
                                  (item['queueNumber'] != null
                                      ? 'Q-${item['queueNumber'].toString().padLeft(3, '0')}'
                                      : 'Q-000');
                              final name = item['patientName'] ?? 'Bệnh nhân';

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${i + 1}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          name,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B)),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      qNumStr,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
