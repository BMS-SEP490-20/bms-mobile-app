import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../../patient_portal/data/patient_portal_api.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment_models.dart';
import 'book_appointment_page.dart';

/// Real-API Appointment Booking Wrapper.
/// Resolves `patientId` from `/api/patients/me` (or `BmsAuth.currentUserId`) and
/// loads live test packages from `GET /api/v1/test-packages/search`.
class BookAppointmentScreen extends StatefulWidget {
  final List<String> initialPackageIds;
  final List<TestPackageOption>? packages;

  const BookAppointmentScreen({
    super.key,
    this.initialPackageIds = const [],
    this.packages,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final PatientPortalApi _patientApi = const PatientPortalApi();

  String? _resolvedPatientId;
  List<TestPackageOption> _packages = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareBookingData();
  }

  Future<void> _prepareBookingData() async {
    if (!BmsAuth.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String patId = AppointmentRepository.currentPatientId() ?? '';
      final med = await _patientApi.getMedicalProfile();
      if (med != null && (med['id'] ?? '').toString().isNotEmpty) {
        patId = med['id'].toString();
      }
      if (patId.isEmpty) {
        patId = BmsAuth.currentUserId;
      }

      List<TestPackageOption> pkgOptions;
      if (widget.packages != null && widget.packages!.isNotEmpty) {
        pkgOptions = widget.packages!;
      } else {
        final rawPackages = await _patientApi.searchTestPackages();
        pkgOptions = rawPackages.map((p) {
          final id = (p['id'] ?? p['code'] ?? '').toString();
          final name = (p['name'] ?? id).toString();
          final price = (num.tryParse((p['price'] ?? '0').toString()) ?? 0)
              .round();
          final desc = p['preparationNotes']?.toString();
          return TestPackageOption(
            packageId: id,
            packageName: name,
            price: price,
            description: (desc != null && desc.trim().isNotEmpty) ? desc : null,
          );
        }).where((e) => e.packageId.isNotEmpty).toList();
      }

      if (!mounted) return;
      setState(() {
        _resolvedPatientId = patId;
        _packages = pkgOptions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('BmsApiException: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!BmsAuth.isLoggedIn) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Đặt lịch xét nghiệm')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: BmsEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Vui lòng đăng nhập để đặt lịch hẹn',
            subtitle: 'Tài khoản giúp lưu mã QR check-in và kết quả xét nghiệm.',
            actionLabel: 'Đăng nhập',
            onAction: () => Navigator.pushNamed(context, '/login'),
          ),
        ),
      );
    }

    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Đặt lịch xét nghiệm')),
        body: const BmsLoadingState(
          message: 'Đang tải danh mục gói khám & bác sĩ...',
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Đặt lịch xét nghiệm')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: BmsErrorState(message: _error!, onRetry: _prepareBookingData),
        ),
      );
    }

    return BookAppointmentPage(
      patientId: _resolvedPatientId ?? BmsAuth.currentUserId,
      repository: AppointmentRepository(),
      packages: _packages,
      initialPackageIds: widget.initialPackageIds,
    );
  }
}
