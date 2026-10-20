import 'package:flutter/material.dart';
import '../../data/queue_repository.dart';
import '../../domain/queue_model.dart';

/// Screen representing UC27 – Live Queue Board & Ticket Issuance on Mobile.
class QueueTicketScreen extends StatefulWidget {
  final QueueRepository? repository;

  const QueueTicketScreen({super.key, this.repository});

  @override
  State<QueueTicketScreen> createState() => _QueueTicketScreenState();
}

class _QueueTicketScreenState extends State<QueueTicketScreen> {
  late final QueueRepository _repo;
  QueueBoardModel? _board;
  bool _isLoading = true;
  bool _isIssuing = false;
  String? _myTicketNumber;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? QueueRepository();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    setState(() => _isLoading = true);
    try {
      final res = await _repo.fetchLiveQueue();
      if (mounted) {
        setState(() {
          _board = QueueBoardModel.fromJson(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _board = null;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load queue data from database. Pull down to retry.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleIssueTicket() async {
    setState(() => _isIssuing = true);
    try {
      final res = await _repo.issueTicket();
      final newTicket = QueueTicketModel.fromJson(res);
      if (mounted) {
        setState(() {
          _myTicketNumber = newTicket.ticketNumber;
          _isIssuing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Issued ticket ${_myTicketNumber!} successfully in database!')),
        );
        _loadQueue();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isIssuing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to issue ticket to database. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Queue Management',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_board == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Queue Management',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadQueue,
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Cannot connect to Queue Database',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please ensure the backend server and MongoDB are running.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadQueue,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Connection'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final board = _board!;
    final QueueTicketModel? activeTicket = board.currentQueue
        .where((t) => t.status == 'Called' || t.status == 'Collecting')
        .firstOrNull;
    final String nowServingTitle = activeTicket != null
        ? '${activeTicket.ticketNumber}${activeTicket.counterName != null && activeTicket.counterName!.isNotEmpty ? ' · ${activeTicket.counterName}' : ''}'
        : (board.currentQueue.isNotEmpty ? '${board.currentQueue.first.ticketNumber} · Chờ gọi' : 'Chưa có số phục vụ');
    final String nowServingSubtitle = activeTicket != null
        ? '${activeTicket.patientName.isNotEmpty ? activeTicket.patientName : ''} · ${activeTicket.priority}'
        : (board.currentQueue.isNotEmpty ? '${board.currentQueue.length} tickets in queue' : 'Queue is currently empty');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Queue Management',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQueue,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadQueue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active Serving Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x201E40AF),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'NOW SERVING',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  nowServingTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  nowServingSubtitle,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // User's Ticket or Issue Ticket Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          if (_myTicketNumber != null) ...[
                            const Text(
                              'YOUR ACTIVE TICKET',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _myTicketNumber!,
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                            const Text(
                              'Please wait in reception lobby until your number is called.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Next in line:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                    Text(
                                      board.nextNumber,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        color: Color(0xFF1E40AF),
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: _isIssuing ? null : _handleIssueTicket,
                                  icon: const Icon(Icons.print_rounded, size: 18),
                                  label: Text(_isIssuing ? 'Issuing...' : 'Get Ticket'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E40AF),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Stats Summary
                    Row(
                      children: [
                        _buildStatChip(
                          label: 'Waiting',
                          value: '${board.stats.inQueueNow}',
                          color: const Color(0xFF1E40AF),
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          label: 'Avg wait',
                          value: '${board.stats.avgWaitMinutes}m',
                          color: const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          label: 'Counters',
                          value: board.stats.countersActive,
                          color: const Color(0xFF059669),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Queue List
                    const Text(
                      'Live Waiting List',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: board.currentQueue.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final t = board.currentQueue[index];
                        final isCalled = t.status == 'Called';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCalled ? const Color(0xFFD1FAE5) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCalled ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                t.ticketNumber,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: isCalled ? const Color(0xFF065F46) : const Color(0xFF1E40AF),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.patientName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    Text(
                                      '${t.packageName} · Check-in ${t.checkedInTime}',
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildPriorityPill(t.priority),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${t.waitTimeMinutes} min',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
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

  Widget _buildStatChip({required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityPill(String priority) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);

    if (priority == 'STAT') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    } else if (priority == 'Urgent') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
