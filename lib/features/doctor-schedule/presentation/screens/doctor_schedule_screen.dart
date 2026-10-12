import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/schedule_repository.dart';
import '../../models/doctor_schedule_model.dart';

/// Doctor Schedule screen (UC16 – Mobile).
/// Roles: Doctor, Manager, Administrator, Receptionist.
class DoctorScheduleScreen extends StatefulWidget {
  final ScheduleRepository? repository;

  const DoctorScheduleScreen({super.key, this.repository});

  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  late final ScheduleRepository _repo;
  DateTime _date = DateTime.now();
  DoctorScheduleResponse? _data;
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ScheduleRepository();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    if (widget.repository == null) _repo.dispose();
    super.dispose();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_date);
  String get _displayDate => DateFormat('dd/MM/yyyy').format(_date);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repo.getDaySchedule(
        date: _dateStr,
        search: _search.isEmpty ? null : _search,
      );
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
      });
    } on ScheduleException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _data = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unexpected error: $e';
        _loading = false;
        _data = null;
      });
    }
  }

  void _prevDay() {
    setState(() => _date = _date.subtract(const Duration(days: 1)));
    _load();
  }

  void _nextDay() {
    setState(() => _date = _date.add(const Duration(days: 1)));
    _load();
  }

  String _statusLabel(String status) {
    if (status == 'Approved' || status == 'Đã duyệt') return 'Approved';
    if (status == 'Pending') return 'Pending';
    return status;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Doctor Schedule',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: _prevDay, icon: const Icon(Icons.chevron_left)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _displayDate,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              IconButton(onPressed: _nextDay, icon: const Icon(Icons.chevron_right)),
            ],
          ),
          if (_data?.dateLabel != null && _data!.dateLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _data!.dateLabel,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search doctor or specialty...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onSubmitted: (v) {
                    setState(() => _search = v.trim());
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() => _search = _searchCtrl.text.trim());
                  _load();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Search'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final doctors = _data?.doctors ?? [];
    if (doctors.isEmpty) {
      return const Center(
        child: Text(
          'No doctors scheduled for this date.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: doctors.length + (_data?.note != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == doctors.length) {
            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _data!.note ?? '',
                style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
              ),
            );
          }
          return _buildDoctorCard(doctors[index]);
        },
      ),
    );
  }

  Widget _buildDoctorCard(DoctorColumn doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.fullName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doc.specialty,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _statusLabel(doc.status),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...doc.slots.map((slot) => _buildSlotRow(slot)),
        ],
      ),
    );
  }

  Widget _buildSlotRow(ScheduleSlot slot) {
    Color bg = const Color(0xFFEFF6FF);
    if (slot.isBreak) bg = const Color(0xFFF8FAFC);
    if (slot.isAvailable) bg = const Color(0xFFF0FDF4);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              '${slot.startTime}-${slot.endTime}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.activity,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: slot.isBreak ? const Color(0xFF94A3B8) : const Color(0xFF1E3A8A),
                  ),
                ),
                if (!slot.isBreak && (slot.roomName.isNotEmpty || slot.detail.isNotEmpty))
                  Text(
                    [slot.roomName, slot.detail].where((s) => s.isNotEmpty).join(' · '),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}