import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../data/doctor_portal_api.dart';

/// Tab 3 — Clinical EMR, ICD-10 Medical Assessments & Laboratory Test Orders.
class DoctorClinicalWorkTab extends StatefulWidget {
  final String? preselectedPatientId;
  final int initialSubTab;

  const DoctorClinicalWorkTab({
    super.key,
    this.preselectedPatientId,
    this.initialSubTab = 0,
  });

  @override
  State<DoctorClinicalWorkTab> createState() => _DoctorClinicalWorkTabState();
}

class _DoctorClinicalWorkTabState extends State<DoctorClinicalWorkTab> {
  static final RegExp _icd10Regex = RegExp(r'^[A-Z][0-9]{2}(\.[0-9]{1,2})?$');
  static const List<({String code, String name})> _commonIcd10 = [
    (code: 'E11.9', name: 'Đái tháo đường típ 2 chưa biến chứng'),
    (code: 'I10', name: 'Tăng huyết áp vô căn nguyên phát'),
    (code: 'D50.9', name: 'Thiếu máu thiếu sắt chưa đặc hiệu'),
    (code: 'E78.5', name: 'Rối loạn chuyển hóa lipoprotein máu'),
    (code: 'K76.0', name: 'Gan nhiễm mỡ không do rượu'),
    (code: 'Z00.0', name: 'Khám sức khỏe tổng quát định kỳ'),
  ];

  final DoctorPortalApi _api = const DoctorPortalApi();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _patientResults = [];
  Map<String, dynamic>? _selectedPatient;
  int _subTab = 0;

  List<Map<String, dynamic>> _emrRecords = [];
  List<Map<String, dynamic>> _assessments = [];
  List<Map<String, dynamic>> _testOrders = [];
  List<Map<String, dynamic>> _catalogPackages = [];

  bool _searchingPatients = false;
  bool _loadingClinical = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subTab = widget.initialSubTab;
    _initData();
  }

  @override
  void didUpdateWidget(covariant DoctorClinicalWorkTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubTab != oldWidget.initialSubTab) {
      _subTab = widget.initialSubTab;
    }
    final nextId = widget.preselectedPatientId;
    if (nextId != null &&
        nextId.isNotEmpty &&
        nextId != oldWidget.preselectedPatientId &&
        nextId != (_selectedPatient?['id'] ?? '').toString()) {
      _selectPatientById(nextId);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _searchPatients('');
    final preId = widget.preselectedPatientId;
    if (preId != null && preId.isNotEmpty) {
      await _selectPatientById(preId);
    }
  }

  Future<void> _searchPatients(String query) async {
    setState(() {
      _searchingPatients = true;
      _error = null;
    });
    try {
      final list = await _api.searchPatients(search: query);
      if (!mounted) return;
      setState(() {
        _patientResults = list;
        _searchingPatients = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('BmsApiException: ', '');
        _searchingPatients = false;
      });
    }
  }

  Future<void> _selectPatientById(String patientId) async {
    setState(() {
      _loadingClinical = true;
      _error = null;
    });
    try {
      final detail = await _api.getPatientDetail(patientId);
      if (!mounted) return;
      if (detail != null && detail.isNotEmpty) {
        _selectedPatient = detail;
      } else {
        final match = _patientResults.where(
          (p) => (p['id'] ?? '').toString() == patientId,
        );
        if (match.isNotEmpty) {
          _selectedPatient = match.first;
        } else {
          _selectedPatient = {'id': patientId, 'fullName': 'Bệnh nhân #$patientId'};
        }
      }
      await _loadClinicalRecords(patientId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('BmsApiException: ', '');
        _loadingClinical = false;
      });
    }
  }

  Future<void> _loadClinicalRecords(String patientId) async {
    setState(() {
      _loadingClinical = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getPatientMedicalRecords(patientId),
        _api.getPatientAssessments(patientId),
        _api.getTestOrders(patientId: patientId),
        if (_catalogPackages.isEmpty)
          _api.searchTestPackages()
        else
          Future.value(_catalogPackages),
      ]);
      if (!mounted) return;
      setState(() {
        _emrRecords = results[0];
        _assessments = results[1];
        _testOrders = results[2];
        _catalogPackages = results[3];
        _loadingClinical = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('BmsApiException: ', '');
        _loadingClinical = false;
      });
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.textPrimary,
      ),
    );
  }

  String _computeAgeLabel(dynamic dobRaw) {
    if (dobRaw == null) return '—';
    final dt = DateTime.tryParse(dobRaw.toString());
    if (dt == null) return '—';
    final age = DateTime.now().year - dt.year;
    return '$age tuổi';
  }

  List<String> _extractAllergies(Map<String, dynamic> patient) {
    final raw = patient['allergies'];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return [raw.trim()];
    }
    return const [];
  }

  Future<void> _openEmrSheet({Map<String, dynamic>? existing}) async {
    final patId = (_selectedPatient?['id'] ?? '').toString();
    if (patId.isEmpty) return;

    final existingVitals = existing?['vitals'] is Map
        ? Map<String, dynamic>.from(existing!['vitals'] as Map)
        : <String, dynamic>{};

    final complaintCtrl = TextEditingController(
      text: (existing?['chiefComplaint'] ?? '').toString(),
    );
    final symptomsCtrl = TextEditingController(
      text: (existing?['clinicalSymptoms'] ?? '').toString(),
    );
    final sysCtrl = TextEditingController(
      text: (existingVitals['systolicBp'] ?? '120').toString(),
    );
    final diaCtrl = TextEditingController(
      text: (existingVitals['diastolicBp'] ?? '75').toString(),
    );
    final hrCtrl = TextEditingController(
      text: (existingVitals['heartRate'] ?? '76').toString(),
    );
    final tempCtrl = TextEditingController(
      text: (existingVitals['temperature'] ?? '36.6').toString(),
    );
    final spo2Ctrl = TextEditingController(
      text: (existingVitals['spo2'] ?? '98').toString(),
    );
    final heightCtrl = TextEditingController(
      text: (existingVitals['heightCm'] ?? '168').toString(),
    );
    final weightCtrl = TextEditingController(
      text: (existingVitals['weightKg'] ?? '62').toString(),
    );
    final icdCodeCtrl = TextEditingController(
      text: (existing?['icd10Code'] ?? '').toString(),
    );
    final icdNameCtrl = TextEditingController(
      text: (existing?['icd10Name'] ?? '').toString(),
    );
    final diagnosisCtrl = TextEditingController(
      text: (existing?['diagnosis'] ?? '').toString(),
    );
    final planCtrl = TextEditingController(
      text: (existing?['treatmentPlan'] ?? '').toString(),
    );
    final rxCtrl = TextEditingController(
      text: (existing?['prescriptionNotes'] ?? '').toString(),
    );

    String? validationError;
    bool saving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    existing == null
                        ? 'Tạo bệnh án điện tử (EMR)'
                        : 'Cập nhật bệnh án EMR (trong 24h)',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (validationError != null) ...[
                    BmsSoftCard(
                      backgroundColor: AppColors.dangerLight,
                      borderColor: AppColors.dangerBorder,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        validationError!,
                        style: const TextStyle(
                          color: AppColors.dangerText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: complaintCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lý do khám (tối thiểu 5 ký tự) *',
                      hintText: 'Khám kiểm tra chỉ số đường huyết & mỡ máu...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: symptomsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Triệu chứng lâm sàng',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Dấu hiệu sinh tồn (Tâm thu > Tâm trương + 15 mmHg)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: sysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'HA Tâm thu *',
                            suffixText: 'mmHg',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: diaCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'HA Tâm trương *',
                            suffixText: 'mmHg',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hrCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Mạch (bpm)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: tempCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Nhiệt độ (°C)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: spo2Ctrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'SpO2 (%)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: heightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Chiều cao (cm)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: weightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cân nặng (kg)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _commonIcd10.map((icd) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(icd.code),
                            onPressed: () {
                              setSheetState(() {
                                icdCodeCtrl.text = icd.code;
                                icdNameCtrl.text = icd.name;
                                if (diagnosisCtrl.text.trim().isEmpty) {
                                  diagnosisCtrl.text = icd.name;
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: icdCodeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Mã ICD-10 *',
                            hintText: 'E11.9',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: icdNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Tên bệnh ICD-10',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: diagnosisCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Chẩn đoán xác định *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: planCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Hướng điều trị & theo dõi',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: rxCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú đơn thuốc / dặn dò',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final complaint = complaintCtrl.text.trim();
                            final sys = int.tryParse(sysCtrl.text.trim()) ?? 0;
                            final dia = int.tryParse(diaCtrl.text.trim()) ?? 0;
                            final icd = icdCodeCtrl.text.trim().toUpperCase();
                            final diag = diagnosisCtrl.text.trim();

                            if (complaint.length < 5) {
                              setSheetState(() {
                                validationError =
                                    'Lý do khám phải có ít nhất 5 ký tự.';
                              });
                              return;
                            }
                            if (sys <= dia + 15) {
                              setSheetState(() {
                                validationError =
                                    'Huyết áp tâm thu phải lớn hơn tâm trương ít nhất 15 mmHg.';
                              });
                              return;
                            }
                            if (!_icd10Regex.hasMatch(icd)) {
                              setSheetState(() {
                                validationError =
                                    'Mã ICD-10 không đúng chuẩn (Ví dụ: E11.9, I10, D50.9).';
                              });
                              return;
                            }
                            if (diag.isEmpty) {
                              setSheetState(() {
                                validationError =
                                    'Vui lòng nhập chẩn đoán xác định.';
                              });
                              return;
                            }

                            setSheetState(() {
                              saving = true;
                              validationError = null;
                            });

                            final payload = {
                              if (existing == null) 'patientId': patId,
                              'chiefComplaint': complaint,
                              'clinicalSymptoms': symptomsCtrl.text.trim(),
                              'vitals': {
                                'systolicBp': sys,
                                'diastolicBp': dia,
                                'heartRate':
                                    int.tryParse(hrCtrl.text.trim()) ?? 75,
                                'temperature':
                                    double.tryParse(tempCtrl.text.trim()) ??
                                    36.6,
                                'spo2':
                                    int.tryParse(spo2Ctrl.text.trim()) ?? 98,
                                'heightCm':
                                    double.tryParse(heightCtrl.text.trim()) ??
                                    168,
                                'weightKg':
                                    double.tryParse(weightCtrl.text.trim()) ??
                                    62,
                              },
                              'icd10Code': icd,
                              'icd10Name': icdNameCtrl.text.trim(),
                              'diagnosis': diag,
                              'treatmentPlan': planCtrl.text.trim(),
                              'prescriptionNotes': rxCtrl.text.trim(),
                            };

                            try {
                              if (existing == null) {
                                await _api.createMedicalRecord(payload);
                              } else {
                                await _api.updateMedicalRecord(
                                  existing['id'].toString(),
                                  payload,
                                );
                              }
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setSheetState(() {
                                saving = false;
                                validationError = e
                                    .toString()
                                    .replaceFirst('BmsApiException: ', '');
                              });
                            }
                          },
                    child: Text(
                      saving
                          ? 'Đang lưu bệnh án...'
                          : (existing == null ? 'Lưu bệnh án EMR' : 'Cập nhật EMR'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (saved == true) {
      _showSnack(
        existing == null
            ? 'Đã tạo bệnh án điện tử EMR thành công.'
            : 'Đã cập nhật bệnh án EMR.',
      );
      await _loadClinicalRecords(patId);
    }
  }

  Future<void> _openAssessmentSheet() async {
    final patId = (_selectedPatient?['id'] ?? '').toString();
    if (patId.isEmpty) return;

    final complaintCtrl = TextEditingController();
    final sysCtrl = TextEditingController(text: '120');
    final diaCtrl = TextEditingController(text: '75');
    final icdCodeCtrl = TextEditingController(text: 'E11.9');
    final icdNameCtrl = TextEditingController(
      text: 'Đái tháo đường típ 2 chưa biến chứng',
    );
    final finalDiagCtrl = TextEditingController();
    final planCtrl = TextEditingController();
    String severity = 'Mild';
    String? validationError;
    bool saving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Thêm đánh giá lâm sàng & ICD-10',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (validationError != null) ...[
                    BmsSoftCard(
                      backgroundColor: AppColors.dangerLight,
                      borderColor: AppColors.dangerBorder,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        validationError!,
                        style: const TextStyle(
                          color: AppColors.dangerText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const Text(
                    'Chọn nhanh mã bệnh ICD-10 phổ biến:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _commonIcd10.map((icd) {
                      final active =
                          icdCodeCtrl.text.trim().toUpperCase() == icd.code;
                      return ChoiceChip(
                        label: Text(icd.code),
                        selected: active,
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: active ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          setSheetState(() {
                            icdCodeCtrl.text = icd.code;
                            icdNameCtrl.text = icd.name;
                            if (finalDiagCtrl.text.trim().isEmpty) {
                              finalDiagCtrl.text = icd.name;
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 115,
                        child: TextField(
                          controller: icdCodeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Mã ICD-10 *',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: icdNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Mô tả mã ICD-10',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: complaintCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lý do khám lâm sàng *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: sysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'HA Tâm thu (mmHg)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: diaCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'HA Tâm trương (mmHg)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: severity,
                    decoration: const InputDecoration(
                      labelText: 'Mức độ lâm sàng',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Mild', child: Text('Nhẹ (Mild)')),
                      DropdownMenuItem(
                        value: 'Moderate',
                        child: Text('Trung bình (Moderate)'),
                      ),
                      DropdownMenuItem(
                        value: 'Severe',
                        child: Text('Nặng (Severe)'),
                      ),
                      DropdownMenuItem(
                        value: 'Critical',
                        child: Text('Nguy kịch (Critical)'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setSheetState(() => severity = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: finalDiagCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Chẩn đoán xác định *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: planCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Phác đồ xử trí & kế hoạch điều trị *',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final complaint = complaintCtrl.text.trim();
                            final icd = icdCodeCtrl.text.trim().toUpperCase();
                            final finalDiag = finalDiagCtrl.text.trim();
                            final sys = int.tryParse(sysCtrl.text.trim()) ?? 0;
                            final dia = int.tryParse(diaCtrl.text.trim()) ?? 0;

                            if (complaint.length < 3) {
                              setSheetState(() {
                                validationError =
                                    'Lý do khám phải có tối thiểu 3 ký tự.';
                              });
                              return;
                            }
                            if (sys <= dia + 15) {
                              setSheetState(() {
                                validationError =
                                    'HA tâm thu phải cao hơn HA tâm trương tối thiểu 15 mmHg.';
                              });
                              return;
                            }
                            if (!_icd10Regex.hasMatch(icd)) {
                              setSheetState(() {
                                validationError =
                                    'Mã ICD-10 không hợp lệ (Ví dụ: E11.9, I10).';
                              });
                              return;
                            }
                            if (finalDiag.isEmpty) {
                              setSheetState(() {
                                validationError =
                                    'Vui lòng nhập kết luận chẩn đoán xác định.';
                              });
                              return;
                            }

                            setSheetState(() {
                              saving = true;
                              validationError = null;
                            });
                            try {
                              await _api.createMedicalAssessment({
                                'patientId': patId,
                                'patientName': _selectedPatient?['fullName'],
                                'patientCode': _selectedPatient?['patientCode'],
                                'chiefComplaint': complaint,
                                'vitals': {
                                  'systolicBp': sys,
                                  'diastolicBp': dia,
                                  'heartRate': 76,
                                  'temperature': 36.6,
                                  'spo2': 98,
                                  'heightCm': 168,
                                  'weightKg': 62,
                                },
                                'icd10Code': icd,
                                'icd10Name': icdNameCtrl.text.trim(),
                                'finalDiagnosis': finalDiag,
                                'severity': severity,
                                'treatmentPlan': planCtrl.text.trim(),
                              });
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setSheetState(() {
                                saving = false;
                                validationError = e
                                    .toString()
                                    .replaceFirst('BmsApiException: ', '');
                              });
                            }
                          },
                    child: Text(saving ? 'Đang lưu...' : 'Lưu đánh giá ICD-10'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (saved == true) {
      _showSnack('Đã lưu đánh giá chẩn đoán ICD-10.');
      await _loadClinicalRecords(patId);
    }
  }

  Future<void> _finalizeAssessment(String assessmentId) async {
    final patId = (_selectedPatient?['id'] ?? '').toString();
    try {
      await _api.finalizeAssessment(assessmentId);
      _showSnack('Đã khóa hồ sơ chẩn đoán lâm sàng.');
      await _loadClinicalRecords(patId);
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('BmsApiException: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _openCreateOrderSheet() async {
    final patId = (_selectedPatient?['id'] ?? '').toString();
    if (patId.isEmpty) return;

    if (_catalogPackages.isEmpty) {
      _catalogPackages = await _api.searchTestPackages();
    }
    if (!mounted) return;

    final selectedCodes = <String>{};
    final icdCtrl = TextEditingController(text: 'Z00.0');
    final indicationCtrl = TextEditingController();
    String priority = 'Routine';
    String? validationError;
    bool submitting = false;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tạo y lệnh xét nghiệm mới',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (validationError != null) ...[
                    BmsSoftCard(
                      backgroundColor: AppColors.dangerLight,
                      borderColor: AppColors.dangerBorder,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        validationError!,
                        style: const TextStyle(
                          color: AppColors.dangerText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: priority,
                          decoration: const InputDecoration(
                            labelText: 'Độ ưu tiên mẫu',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Routine',
                              child: Text('Thường quy'),
                            ),
                            DropdownMenuItem(
                              value: 'Urgent',
                              child: Text('Khẩn (Urgent)'),
                            ),
                            DropdownMenuItem(
                              value: 'STAT',
                              child: Text('Cấp cứu (STAT)'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setSheetState(() => priority = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: icdCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Mã ICD-10 *',
                            hintText: 'E11.9',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: indicationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Chỉ định lâm sàng (tối thiểu 5 ký tự) *',
                      hintText: 'Theo dõi đường huyết lúc đói & chức năng gan thận...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Chọn gói xét nghiệm (${selectedCodes.length} đã chọn)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 230),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _catalogPackages.length,
                      itemBuilder: (_, idx) {
                        final pkg = _catalogPackages[idx];
                        final code = (pkg['code'] ?? pkg['id'] ?? '').toString();
                        final name = (pkg['name'] ?? code).toString();
                        final price = num.tryParse(
                          (pkg['price'] ?? '0').toString(),
                        );
                        final checked = selectedCodes.contains(code);

                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: checked,
                          activeColor: AppColors.primary,
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '$code · ${BmsFormatters.currency(price)}',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          onChanged: (val) {
                            setSheetState(() {
                              if (val == true) {
                                selectedCodes.add(code);
                              } else {
                                selectedCodes.remove(code);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final icd = icdCtrl.text.trim().toUpperCase();
                            final ind = indicationCtrl.text.trim();
                            if (!_icd10Regex.hasMatch(icd)) {
                              setSheetState(() {
                                validationError =
                                    'Mã ICD-10 không đúng định dạng (Ví dụ: E11.9, Z00.0).';
                              });
                              return;
                            }
                            if (ind.length < 5) {
                              setSheetState(() {
                                validationError =
                                    'Chỉ định lâm sàng phải có ít nhất 5 ký tự.';
                              });
                              return;
                            }
                            if (selectedCodes.isEmpty) {
                              setSheetState(() {
                                validationError =
                                    'Vui lòng chọn ít nhất 1 gói xét nghiệm.';
                              });
                              return;
                            }

                            setSheetState(() {
                              submitting = true;
                              validationError = null;
                            });

                            final items = _catalogPackages
                                .where(
                                  (p) => selectedCodes.contains(
                                    (p['code'] ?? p['id'] ?? '').toString(),
                                  ),
                                )
                                .map(
                                  (p) => {
                                    'testCode': (p['code'] ?? p['id'])
                                        .toString(),
                                    'testName': (p['name'] ?? '').toString(),
                                  },
                                )
                                .toList();

                            try {
                              await _api.createTestOrder({
                                'patientId': patId,
                                'patientName': _selectedPatient?['fullName'],
                                'priority': priority,
                                'icd10Code': icd,
                                'icd10Codes': [icd],
                                'clinicalIndication': ind,
                                'items': items,
                              });
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setSheetState(() {
                                submitting = false;
                                validationError = e
                                    .toString()
                                    .replaceFirst('BmsApiException: ', '');
                              });
                            }
                          },
                    child: Text(
                      submitting ? 'Đang gửi y lệnh...' : 'Gửi phiếu chỉ định XN',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (created == true) {
      _showSnack('Đã tạo phiếu chỉ định xét nghiệm thành công.');
      await _loadClinicalRecords(patId);
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final patId = (_selectedPatient?['id'] ?? '').toString();
    try {
      await _api.cancelTestOrder(
        orderId,
        notes: 'Bác sĩ điều chỉnh chỉ định trên ứng dụng di động',
      );
      _showSnack('Đã hủy phiếu chỉ định xét nghiệm.');
      await _loadClinicalRecords(patId);
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('BmsApiException: ', ''),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        BmsPageHeaderCard(
          icon: Icons.folder_shared_rounded,
          badgeText: 'Hồ sơ lâm sàng điện tử',
          title: 'Bệnh án & Y lệnh XN',
          subtitle: 'Tra cứu bệnh nhân, lập bệnh án EMR, mã ICD-10 và chỉ định xét nghiệm',
          trailing: _selectedPatient != null
              ? TextButton.icon(
                  onPressed: () => setState(() => _selectedPatient = null),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Đổi BN'),
                )
              : null,
        ),
        const SizedBox(height: 14),
        if (_selectedPatient == null)
          _buildPatientSelector()
        else
          _buildClinicalWorkspace(_selectedPatient!),
      ],
    );
  }

  Widget _buildPatientSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BmsSearchFilterBar(
          controller: _searchCtrl,
          hintText: 'Tìm theo họ tên, mã BN, SĐT hoặc CCCD...',
          onSubmitted: _searchPatients,
          onClear: () => _searchPatients(''),
          trailing: FilledButton(
            onPressed: () => _searchPatients(_searchCtrl.text),
            child: const Text('Tìm'),
          ),
        ),
        const SizedBox(height: 14),
        if (_searchingPatients)
          const BmsLoadingState(message: 'Đang tra cứu danh sách bệnh nhân...')
        else if (_error != null)
          BmsErrorState(
            message: _error!,
            onRetry: () => _searchPatients(_searchCtrl.text),
          )
        else if (_patientResults.isEmpty)
          const BmsEmptyState(
            icon: Icons.person_search_outlined,
            title: 'Không tìm thấy hồ sơ bệnh nhân',
            subtitle: 'Thử nhập từ khóa khác hoặc kiểm tra mã bệnh nhân.',
          )
        else
          ..._patientResults.map((p) {
            final id = (p['id'] ?? '').toString();
            final name = (p['fullName'] ?? 'Bệnh nhân').toString();
            final code = (p['patientCode'] ?? id).toString();
            final phone = (p['phoneNumber'] ?? p['phone'] ?? '—').toString();
            final blood = (p['bloodType'] ?? '').toString();

            return BmsSoftCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              onTap: () => _selectPatientById(id),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$code · SĐT: $phone',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (blood.isNotEmpty)
                    BmsStatusPill(status: 'Confirmed', customLabel: 'Máu $blood'),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildClinicalWorkspace(Map<String, dynamic> patient) {
    final patId = (patient['id'] ?? '').toString();
    final name = (patient['fullName'] ?? 'Bệnh nhân').toString();
    final code = (patient['patientCode'] ?? patId).toString();
    final gender = BmsFormatters.genderVi(patient['gender']?.toString());
    final age = _computeAgeLabel(patient['dateOfBirth']);
    final blood = (patient['bloodType'] ?? 'Chưa rõ').toString();
    final allergies = _extractAllergies(patient);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BmsSoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  BmsStatusPill(status: 'Confirmed', customLabel: 'Nhóm máu: $blood'),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Mã BN: $code · $gender · $age',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              if (allergies.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.dangerBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cảnh báo dị ứng: ${allergies.join(', ')}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dangerText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        BmsSegmentedTabs(
          tabs: const ['Bệnh án EMR', 'Chẩn đoán ICD-10', 'Y lệnh XN'],
          selectedIndex: _subTab,
          onChanged: (idx) => setState(() => _subTab = idx),
        ),
        const SizedBox(height: 14),
        if (_loadingClinical)
          const BmsLoadingState(message: 'Đang tải hồ sơ lâm sàng bệnh nhân...')
        else if (_error != null)
          BmsErrorState(
            message: _error!,
            onRetry: () => _loadClinicalRecords(patId),
          )
        else if (_subTab == 0)
          _buildEmrSection()
        else if (_subTab == 1)
          _buildAssessmentSection()
        else
          _buildTestOrdersSection(),
      ],
    );
  }

  Widget _buildEmrSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BmsSectionHeader(
          title: 'Lịch sử bệnh án (${_emrRecords.length})',
          trailing: FilledButton.icon(
            onPressed: () => _openEmrSheet(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Tạo bệnh án EMR'),
          ),
        ),
        const SizedBox(height: 10),
        if (_emrRecords.isEmpty)
          const BmsEmptyState(
            icon: Icons.description_outlined,
            title: 'Chưa có bệnh án điện tử',
            subtitle: 'Nhấn "Tạo bệnh án EMR" để ghi nhận sinh hiệu và chẩn đoán.',
          )
        else
          ..._emrRecords.map((rec) {
            final code = (rec['recordCode'] ?? rec['id'] ?? '').toString();
            final icd = (rec['icd10Code'] ?? '').toString();
            final diag = (rec['diagnosis'] ?? '').toString();
            final complaint = (rec['chiefComplaint'] ?? '').toString();
            final plan = (rec['treatmentPlan'] ?? '').toString();
            final canEdit = rec['canEdit'] == true;
            final vitals = rec['vitals'] is Map
                ? Map<String, dynamic>.from(rec['vitals'] as Map)
                : <String, dynamic>{};

            return BmsSoftCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$code · ICD-10: $icd',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      Text(
                        BmsFormatters.dateTime(rec['createdAt']),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  BmsInfoRow(label: 'Lý do khám', value: complaint),
                  BmsInfoRow(label: 'Chẩn đoán', value: diag, isBold: true),
                  if (vitals.isNotEmpty)
                    BmsInfoRow(
                      label: 'Sinh hiệu',
                      value:
                          'HA ${vitals['systolicBp'] ?? '—'}/${vitals['diastolicBp'] ?? '—'} mmHg · Mạch ${vitals['heartRate'] ?? '—'} bpm',
                    ),
                  if (plan.isNotEmpty)
                    BmsInfoRow(label: 'Hướng điều trị', value: plan),
                  if (canEdit) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _openEmrSheet(existing: rec),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Hiệu chỉnh (trong 24h)'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAssessmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BmsSectionHeader(
          title: 'Đánh giá ICD-10 (${_assessments.length})',
          trailing: FilledButton.icon(
            onPressed: _openAssessmentSheet,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Thêm đánh giá'),
          ),
        ),
        const SizedBox(height: 10),
        if (_assessments.isEmpty)
          const BmsEmptyState(
            icon: Icons.assignment_outlined,
            title: 'Chưa có đánh giá lâm sàng ICD-10',
            subtitle: 'Thêm đánh giá chuyên khoa và khóa hồ sơ khi hoàn tất.',
          )
        else
          ..._assessments.map((a) {
            final id = (a['id'] ?? '').toString();
            final code = (a['assessmentCode'] ?? id).toString();
            final icd = (a['icd10Code'] ?? '').toString();
            final finalDiag = (a['finalDiagnosis'] ?? '').toString();
            final severity = (a['severity'] ?? 'Mild').toString();
            final isFinalized =
                a['isFinalized'] == true ||
                (a['status'] ?? '').toString().toLowerCase() == 'finalized';

            return BmsSoftCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$code · $icd',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      BmsStatusPill(
                        status: isFinalized ? 'Finalized' : 'Draft',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  BmsInfoRow(
                    label: 'Chẩn đoán xác định',
                    value: finalDiag,
                    isBold: true,
                  ),
                  BmsInfoRow(
                    label: 'Mức độ bệnh',
                    value: BmsStatusPill.resolve(severity).label,
                  ),
                  BmsInfoRow(
                    label: 'Ngày đánh giá',
                    value: BmsFormatters.dateTime(
                      a['assessmentDate'] ?? a['createdAt'],
                    ),
                  ),
                  if (!isFinalized && id.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _finalizeAssessment(id),
                        icon: const Icon(Icons.lock_outline_rounded, size: 16),
                        label: const Text('Khóa bệnh án'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTestOrdersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BmsSectionHeader(
          title: 'Phiếu chỉ định XN (${_testOrders.length})',
          trailing: FilledButton.icon(
            onPressed: _openCreateOrderSheet,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Tạo y lệnh mới'),
          ),
        ),
        const SizedBox(height: 10),
        if (_testOrders.isEmpty)
          const BmsEmptyState(
            icon: Icons.biotech_outlined,
            title: 'Chưa có y lệnh xét nghiệm',
            subtitle: 'Chọn gói xét nghiệm từ danh mục để gửi chỉ định xuống Lab.',
          )
        else
          ..._testOrders.map((ord) {
            final id = (ord['id'] ?? ord['orderNumber'] ?? '').toString();
            final orderNum = (ord['orderNumber'] ?? id).toString();
            final status = (ord['status'] ?? 'Ordered').toString();
            final priority = (ord['priority'] ?? 'Routine').toString();
            final total = num.tryParse((ord['totalAmount'] ?? '0').toString());
            final indication = (ord['clinicalIndication'] ?? '').toString();
            final items = ord['items'] is List
                ? (ord['items'] as List)
                    .whereType<Map>()
                    .map((e) => (e['testName'] ?? e['testCode'] ?? '').toString())
                    .where((s) => s.isNotEmpty)
                    .toList()
                : <String>[];

            final lowerStatus = status.toLowerCase();
            final canCancel = lowerStatus == 'awaitingpayment' ||
                lowerStatus == 'ordered' ||
                lowerStatus == 'pending' ||
                lowerStatus == 'draft';

            return BmsSoftCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          orderNum,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      BmsStatusPill(status: priority),
                      const SizedBox(width: 6),
                      BmsStatusPill(status: status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (items.isNotEmpty)
                    BmsInfoRow(
                      label: 'Gói chỉ định',
                      value: items.join(', '),
                      isBold: true,
                    ),
                  BmsInfoRow(label: 'Lý do chỉ định', value: indication),
                  BmsInfoRow(
                    label: 'Tổng chi phí',
                    value: BmsFormatters.currency(total),
                  ),
                  if (canCancel && id.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.dangerText,
                          side: const BorderSide(color: AppColors.dangerBorder),
                        ),
                        onPressed: () => _cancelOrder(id),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('Hủy chỉ định'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
}
