import 'package:flutter/material.dart';
import '../services/appointment_service.dart';

/// A form screen for creating and updating laboratory test appointments on mobile.
/// 
/// Feature Tasks:
/// - Create Appointments (Mobile)
/// - Update Appointments (Mobile)
/// 
/// When [appointmentToEdit] is provided, the screen operates in **Edit Mode** allowing
/// rescheduling, package changes, and status updates. When [appointmentToEdit] is `null`,
/// it operates in **Creation Mode** allowing patients or staff to book a new appointment.
class AppointmentFormScreen extends StatefulWidget {
  /// The existing appointment to edit, or `null` for creating a new appointment.
  final Map<String, dynamic>? appointmentToEdit;

  /// Creates an [AppointmentFormScreen] instance.
  const AppointmentFormScreen({super.key, this.appointmentToEdit});

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  bool get isEditing => widget.appointmentToEdit != null;

  String? _selectedPackageId;
  String _selectedAppointmentType = 'Khám';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  String _selectedStatus = 'pending';

  final _guestNameController = TextEditingController();
  final _guestPhoneController = TextEditingController();
  final _reasonController = TextEditingController();

  List<Map<String, dynamic>> _packages = [];
  bool _isLoadingPackages = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _currentUser;

  final List<String> _appointmentTypes = ['Khám', 'Xét nghiệm máu', 'Tái khám', 'Tư vấn'];
  final List<Map<String, String>> _statusOptions = [
    {'value': 'pending', 'label': 'Chờ xác nhận (Pending)'},
    {'value': 'scheduled', 'label': 'Đã xếp lịch (Scheduled)'},
    {'value': 'confirmed', 'label': 'Đã xác nhận (Confirmed)'},
    {'value': 'checked_in', 'label': 'Đã check-in (Checked In)'},
    {'value': 'completed', 'label': 'Hoàn thành (Completed)'},
    {'value': 'cancelled', 'label': 'Đã hủy (Cancelled)'},
  ];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() async {
    _currentUser = await AppointmentService.getCurrentUser();
    final pkgs = await AppointmentService.getTestPackages();

    if (mounted) {
      setState(() {
        _packages = pkgs;
        _isLoadingPackages = false;
      });
    }

    if (isEditing) {
      final apt = widget.appointmentToEdit!;
      _selectedPackageId = apt['testPackageId']?.toString();
      _selectedAppointmentType = apt['appointmentType'] ?? 'Khám';
      if (!_appointmentTypes.contains(_selectedAppointmentType)) {
        _appointmentTypes.add(_selectedAppointmentType);
      }
      _selectedStatus = apt['status'] ?? 'pending';

      _guestNameController.text = apt['guestName'] ?? '';
      _guestPhoneController.text = apt['guestPhone'] ?? '';
      _reasonController.text = apt['reasonForRescheduling'] ?? '';

      if (apt['appointmentTime'] != null) {
        try {
          final dt = DateTime.parse(apt['appointmentTime'].toString());
          _selectedDate = dt;
          _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
        } catch (_) {}
      }
    } else {
      // Create mode: prefill guest name and phone from current user if available
      if (_currentUser != null) {
        _guestNameController.text = _currentUser!['fullName'] ?? _currentUser!['username'] ?? '';
        _guestPhoneController.text = _currentUser!['phone'] ?? '';
      }
    }
  }

  @override
  void dispose() {
    _guestNameController.dispose();
    _guestPhoneController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final appointmentDateTime = _combineDateTime(_selectedDate, _selectedTime);
    final userPatientId = _currentUser?['id']?.toString() ?? _currentUser?['patientId']?.toString() ?? 'PAT-001';

    if (isEditing) {
      // Task 2: Update Appointments (Mobile)
      final updatePayload = {
        'testPackageId': _selectedPackageId,
        'doctorShiftId': widget.appointmentToEdit!['doctorShiftId'],
        'status': _selectedStatus,
        'labAssignmentId': widget.appointmentToEdit!['labAssignmentId'],
        'appointmentTime': appointmentDateTime.toIso8601String(),
        'appointmentType': _selectedAppointmentType,
        'reasonForRescheduling': _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
        'guestName': _guestNameController.text.trim().isNotEmpty ? _guestNameController.text.trim() : null,
        'guestPhone': _guestPhoneController.text.trim().isNotEmpty ? _guestPhoneController.text.trim() : null,
      };

      final aptId = widget.appointmentToEdit!['appointmentId'] ?? widget.appointmentToEdit!['id'];
      final res = await AppointmentService.updateAppointment(aptId.toString(), updatePayload);

      setState(() => _isSubmitting = false);

      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật cuộc hẹn thành công!'),
              backgroundColor: Color(0xFF198754),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Lỗi cập nhật'),
              backgroundColor: const Color(0xFFDC3545),
            ),
          );
        }
      }
    } else {
      // Task 1: Create Appointments (Mobile)
      final createPayload = {
        'testPackageId': _selectedPackageId,
        'status': 'pending',
        'createdBy': userPatientId,
        'appointmentTime': appointmentDateTime.toIso8601String(),
        'appointmentType': _selectedAppointmentType,
        'guestName': _guestNameController.text.trim().isNotEmpty ? _guestNameController.text.trim() : null,
        'guestPhone': _guestPhoneController.text.trim().isNotEmpty ? _guestPhoneController.text.trim() : null,
      };

      final res = await AppointmentService.createAppointment(createPayload);

      setState(() => _isSubmitting = false);

      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tạo lịch hẹn mới thành công!'),
              backgroundColor: Color(0xFF198754),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Lỗi tạo lịch hẹn'),
              backgroundColor: const Color(0xFFDC3545),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = isEditing ? 'Cập Nhật Lịch Hẹn' : 'Tạo Lịch Hẹn Mới';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF212529),
        elevation: 1,
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoadingPackages
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D6EFD).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0D6EFD).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isEditing ? Icons.edit_calendar : Icons.add_circle_outline,
                            color: const Color(0xFF0D6EFD),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing ? 'Cập nhật thông tin cuộc hẹn' : 'Đăng ký lịch khám & xét nghiệm',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D6EFD)),
                                ),
                                Text(
                                  isEditing ? 'Thay đổi ngày giờ hoặc gói khám xét nghiệm' : 'Điền đầy đủ thông tin để hệ thống sắp xếp lịch',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 1: Test Package & Appointment Type
                    _buildSectionCard(
                      title: 'Thông Tin Xét Nghiệm',
                      icon: Icons.biotech,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPackageId,
                          decoration: InputDecoration(
                            labelText: 'Gói xét nghiệm',
                            hintText: 'Chọn gói xét nghiệm (tùy chọn)',
                            prefixIcon: const Icon(Icons.medical_services_outlined, color: Color(0xFF0D6EFD)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('-- Khám thông thường / Không chọn gói --'),
                            ),
                            ..._packages.map((pkg) {
                              final id = pkg['packageId'] ?? pkg['id'];
                              final name = pkg['packageName'] ?? pkg['name'] ?? id;
                              final price = pkg['price'] != null ? ' - ${pkg['price']} VNĐ' : '';
                              return DropdownMenuItem<String>(
                                value: id.toString(),
                                child: Text('$name$price', overflow: TextOverflow.ellipsis),
                              );
                            }),
                          ],
                          onChanged: (val) => setState(() => _selectedPackageId = val),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedAppointmentType,
                          decoration: InputDecoration(
                            labelText: 'Loại cuộc hẹn *',
                            prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF0D6EFD)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _appointmentTypes.map((type) {
                            return DropdownMenuItem(value: type, child: Text(type));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedAppointmentType = val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Appointment Date & Time
                    _buildSectionCard(
                      title: 'Thời Gian Cuộc Hẹn',
                      icon: Icons.access_time,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _pickDate,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_month, color: Color(0xFF0D6EFD)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Ngày hẹn', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                            Text(
                                              '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: _pickTime,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.schedule, color: Color(0xFF0D6EFD)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Giờ hẹn', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                            Text(
                                              '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Patient Information
                    _buildSectionCard(
                      title: 'Thông Tin Người Khám',
                      icon: Icons.person_outline,
                      children: [
                        TextFormField(
                          controller: _guestNameController,
                          decoration: InputDecoration(
                            labelText: 'Họ và tên người khám',
                            hintText: 'Nhập họ và tên',
                            prefixIcon: const Icon(Icons.person, color: Color(0xFF0D6EFD)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _guestPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Số điện thoại liên hệ',
                            hintText: 'Ví dụ: 0912345678',
                            prefixIcon: const Icon(Icons.phone, color: Color(0xFF0D6EFD)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        if (isEditing) ...[
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedStatus,
                            decoration: InputDecoration(
                              labelText: 'Trạng thái cuộc hẹn',
                              prefixIcon: const Icon(Icons.flag_outlined, color: Color(0xFF0D6EFD)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: _statusOptions.map((opt) {
                              return DropdownMenuItem(value: opt['value'], child: Text(opt['label']!));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedStatus = val);
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _reasonController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Lý do thay đổi / Ghi chú',
                              hintText: 'Nhập lý do dời lịch hoặc ghi chú thêm',
                              prefixIcon: const Icon(Icons.edit_note, color: Color(0xFF0D6EFD)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Submit Button
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D6EFD),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(isEditing ? Icons.save : Icons.check_circle, color: Colors.white),
                      label: Text(
                        _isSubmitting ? 'Đang lưu...' : (isEditing ? 'Cập Nhật Lịch Hẹn' : 'Xác Nhận Tạo Lịch Hẹn'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF0D6EFD)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF212529)),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }
}
