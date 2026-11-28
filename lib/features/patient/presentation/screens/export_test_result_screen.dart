import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/network/bms_http_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../../../services/bms_auth.dart';
import '../../../patient_portal/data/patient_portal_api.dart';

/// 1-to-1 Patient Test Result Report & Real A4 Vietnamese Medical PDF Export Screen
/// matching Web `ExportTestResultPdfPage.jsx` + Backend `PatientResultExportService.cs`.
class ExportTestResultScreen extends StatefulWidget {
  final String? orderId;

  const ExportTestResultScreen({super.key, this.orderId});

  @override
  State<ExportTestResultScreen> createState() => _ExportTestResultScreenState();
}

class _ExportTestResultScreenState extends State<ExportTestResultScreen> {
  final PatientPortalApi _api = const PatientPortalApi();

  bool _loading = true;
  bool _exportingPdf = false;
  bool _sharing = false;
  String? _error;
  String? _resolvedOrderId;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _pick(Map<String, dynamic> map, List<String> keys, [String fallback = '']) {
    for (final k in keys) {
      final v = map[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return fallback;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var targetId = widget.orderId?.trim() ?? '';
      if (targetId.isEmpty) {
        final profile = await _api.getMedicalProfile().catchError((_) => null);
        final pid =
            (profile?['patientCode'] ??
                    profile?['id'] ??
                    BmsAuth.currentUserId)
                .toString();
        if (pid.isNotEmpty) {
          final list = await _api.getReleasedResults(pid);
          if (list.isNotEmpty) {
            targetId = _pick(list.first, [
              'orderId',
              'OrderId',
              'orderCode',
              'OrderCode',
              'id',
            ]);
          }
          if (targetId.isEmpty) {
            final hist = await _api.getTestHistory(patientId: pid, pageSize: 5);
            if (hist.isNotEmpty) {
              targetId = _pick(hist.first, [
                'resultCode',
                'orderId',
                'id',
                'sampleId',
              ]);
            }
          }
        }
      }

      if (targetId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Bạn chưa có phiếu kết quả xét nghiệm nào được phát hành.';
        });
        return;
      }

      final detail = await _api.getOrderResultDetail(targetId);
      if (!mounted) return;
      setState(() {
        _resolvedOrderId = _pick(detail, ['orderId', 'OrderId', 'orderCode'], targetId);
        _result = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _parameters {
    final raw =
        _result?['parameters'] ??
        _result?['Parameters'] ??
        _result?['results'] ??
        const [];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  String _flagLabelVi(String rawFlag) {
    switch (rawFlag.trim().toUpperCase()) {
      case 'HH':
        return 'HH (Nguy kịch cao)';
      case 'LL':
        return 'LL (Nguy kịch thấp)';
      case 'H':
      case 'HIGH':
        return 'H (Cao)';
      case 'L':
      case 'LOW':
        return 'L (Thấp)';
      case 'N':
      case 'NORMAL':
      case '':
        return 'Bình thường';
      default:
        return rawFlag;
    }
  }

  bool _isAbnormalFlag(String rawFlag) {
    final f = rawFlag.trim().toUpperCase();
    return f.isNotEmpty && f != 'N' && f != 'NORMAL';
  }

  Future<void> _exportRealA4Pdf() async {
    final r = _result;
    if (r == null) return;
    setState(() => _exportingPdf = true);

    try {
      // Load full Unicode Vietnamese fonts bundled via printing/GoogleFonts
      final regularFont = await PdfGoogleFonts.notoSansRegular();
      final boldFont = await PdfGoogleFonts.notoSansBold();
      final italicFont = await PdfGoogleFonts.notoSansItalic();

      final orderCode = _pick(r, ['orderId', 'OrderId', 'orderCode'], _resolvedOrderId ?? '');
      final patientName = _pick(r, ['patientName', 'PatientName'], BmsAuth.currentUserName);
      final patientCode = _pick(r, ['patientCode', 'PatientCode'], '—');
      final dob = BmsFormatters.date(r['dateOfBirth'] ?? r['DateOfBirth']);
      final gender = BmsFormatters.genderVi((r['gender'] ?? r['Gender'])?.toString());
      final packageName = _pick(r, ['packageName', 'PackageName', 'testName'], 'Phiếu Kết Quả Xét Nghiệm Y Khoa');
      final barcode = _pick(r, ['barcode', 'Barcode', 'sampleCode'], '—');
      final sampleType = _pick(r, ['sampleType', 'SampleType'], 'Máu toàn phần / Huyết thanh');
      final collectedAt = BmsFormatters.dateTime(r['collectionTime'] ?? r['CollectionTime'] ?? r['collectedAt']);
      final releasedAt = BmsFormatters.dateTime(r['releasedDate'] ?? r['ReleasedDate'] ?? r['approvedAt']);
      final techName = _pick(r, ['performedBy', 'PerformedBy', 'technicianName'], 'KTV Phòng Xét Nghiệm');
      final doctorName = _pick(r, ['approvedByDoctor', 'ApprovedByDoctor', 'doctorName'], 'Bác sĩ điều trị');
      final doctorSpec = _pick(r, ['doctorSpecialty', 'DoctorSpecialty'], 'Chuyên khoa Huyết học - Sinh hóa');
      final icd10 = _pick(r, ['icd10Code', 'Icd10Code'], '');
      final diagnosis = _pick(r, ['finalDiagnosis', 'FinalDiagnosis', 'doctorAssessment', 'DoctorAssessment', 'conclusion'], '');
      final advice = _pick(r, ['treatmentAdvice', 'TreatmentAdvice'], '');
      final followUp = _pick(r, ['followUpDate', 'FollowUpDate'], '');
      final hash = _pick(r, ['verificationHash', 'VerificationHash'], '');
      final params = _parameters;

      final doc = pw.Document(
        title: 'Phieu_Ket_Qua_$orderCode',
        author: 'BMS Clinical Laboratory',
      );

      final theme = pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
        italic: italicFont,
      );

      final primaryPdf = PdfColor.fromHex('#1E60E6');
      final slateDark = PdfColor.fromHex('#0F172A');
      final slateMuted = PdfColor.fromHex('#475569');
      final borderPdf = PdfColor.fromHex('#CBD5E1');
      final softBg = PdfColor.fromHex('#F8FAFC');
      final dangerPdf = PdfColor.fromHex('#DC2626');
      final successPdf = PdfColor.fromHex('#047857');

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
          theme: theme,
          footer: (ctx) => pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderPdf, width: 0.6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Phiếu kết quả điện tử chuẩn ISO 15189:2022 • BMS MedLab',
                  style: pw.TextStyle(fontSize: 8, color: slateMuted),
                ),
                pw.Text(
                  'Trang ${ctx.pageNumber}/${ctx.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: slateMuted),
                ),
              ],
            ),
          ),
          build: (ctx) => [
            // Header
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TRUNG TÂM XÉT NGHIỆM Y KHOA BMS MEDLAB',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryPdf,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '120 Hai Bà Trưng, P. Đa Kao, Quận 1, TP. Hồ Chí Minh',
                      style: pw.TextStyle(fontSize: 8.5, color: slateMuted),
                    ),
                    pw.Text(
                      'Hotline: 1900 6868 • Hệ thống đạt chuẩn ISO 15189:2022',
                      style: pw.TextStyle(fontSize: 8.5, color: slateMuted),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'MÃ PHIẾU: $orderCode',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: slateDark,
                      ),
                    ),
                    pw.Text(
                      'Barcode mẫu: $barcode',
                      style: pw.TextStyle(fontSize: 8.5, color: slateMuted),
                    ),
                    pw.Text(
                      'Phát hành: $releasedAt',
                      style: pw.TextStyle(fontSize: 8.5, color: slateMuted),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: primaryPdf, thickness: 1.5),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                'PHIẾU KẾT QUẢ XÉT NGHIỆM Y KHOA',
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: slateDark,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Gói dịch vụ: $packageName',
                style: pw.TextStyle(fontSize: 10, color: slateMuted),
              ),
            ),
            pw.SizedBox(height: 12),

            // Patient & Sample Info Grid
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: softBg,
                border: pw.Border.all(color: borderPdf, width: 0.8),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfMeta('Họ và tên:', patientName, bold: true),
                        _pdfMeta('Mã bệnh nhân (PID):', patientCode),
                        _pdfMeta('Ngày sinh / Giới tính:', '$dob • $gender'),
                        _pdfMeta('Loại bệnh phẩm:', sampleType),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfMeta('Bác sĩ phê duyệt:', doctorName, bold: true),
                        _pdfMeta('Chuyên khoa:', doctorSpec),
                        _pdfMeta('KTV thực hiện:', techName),
                        _pdfMeta('Thời gian lấy mẫu:', collectedAt),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Parameters Table
            pw.Text(
              'BẢNG CHỈ SỐ XÉT NGHIỆM SINH HỌC',
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: slateDark,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: borderPdf, width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(3.4),
                1: pw.FlexColumnWidth(1.2),
                2: pw.FlexColumnWidth(1.1),
                3: pw.FlexColumnWidth(1.8),
                4: pw.FlexColumnWidth(1.6),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#EFF6FF')),
                  children: [
                    _pdfTh('Tên chỉ số xét nghiệm'),
                    _pdfTh('Kết quả', align: pw.TextAlign.right),
                    _pdfTh('Đơn vị', align: pw.TextAlign.center),
                    _pdfTh('Khoảng tham chiếu', align: pw.TextAlign.center),
                    _pdfTh('Đánh giá', align: pw.TextAlign.center),
                  ],
                ),
                ...params.map((p) {
                  final pCode = _pick(p, ['parameterCode', 'code', 'Code'], '');
                  final pName = _pick(p, ['parameterName', 'ParameterName', 'name', 'testName'], pCode);
                  final val = _pick(p, ['value', 'Value', 'resultValue'], '—');
                  final unit = _pick(p, ['unit', 'Unit'], '');
                  final ref = _pick(p, ['referenceRange', 'ReferenceRange'], '—');
                  final flag = _pick(p, ['flag', 'Flag', 'abnormalFlag'], 'N');
                  final abnormal = _isAbnormalFlag(flag);

                  return pw.TableRow(
                    children: [
                      _pdfTd(pCode.isNotEmpty && !pName.contains(pCode) ? '$pCode • $pName' : pName),
                      _pdfTd(
                        val,
                        align: pw.TextAlign.right,
                        bold: true,
                        color: abnormal ? dangerPdf : slateDark,
                      ),
                      _pdfTd(unit, align: pw.TextAlign.center),
                      _pdfTd(ref, align: pw.TextAlign.center),
                      _pdfTd(
                        _flagLabelVi(flag),
                        align: pw.TextAlign.center,
                        bold: abnormal,
                        color: abnormal ? dangerPdf : successPdf,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 14),

            // Doctor Clinical Conclusion
            if (diagnosis.isNotEmpty || advice.isNotEmpty || icd10.isNotEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: softBg,
                  border: pw.Border(
                    left: pw.BorderSide(color: primaryPdf, width: 3),
                    top: pw.BorderSide(color: borderPdf, width: 0.6),
                    right: pw.BorderSide(color: borderPdf, width: 0.6),
                    bottom: pw.BorderSide(color: borderPdf, width: 0.6),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CHẨN ĐOÁN & KẾT LUẬN LÂM SÀNG CỦA BÁC SĨ',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryPdf,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    if (icd10.isNotEmpty)
                      pw.Text(
                        'Mã bệnh ICD-10: $icd10',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: slateDark,
                        ),
                      ),
                    if (diagnosis.isNotEmpty)
                      pw.Text(
                        diagnosis,
                        style: pw.TextStyle(fontSize: 9.5, color: slateDark),
                      ),
                    if (advice.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Lời dặn & hướng xử trí: $advice',
                        style: pw.TextStyle(fontSize: 9, color: slateMuted),
                      ),
                    ],
                    if (followUp.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Hẹn tái khám: ${BmsFormatters.date(followUp)}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: slateDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            pw.SizedBox(height: 18),

            // Signatures
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text(
                      'KỸ THUẬT VIÊN XÉT NGHIỆM',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: slateDark,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Đã kiểm chuẩn kỹ thuật',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                        color: successPdf,
                      ),
                    ),
                    pw.SizedBox(height: 18),
                    pw.Text(
                      techName,
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: slateDark,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text(
                      'BÁC SĨ ĐIỀU TRỊ PHÊ DUYỆT',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: slateDark,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Đã ký số điện tử • $releasedAt',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                        color: primaryPdf,
                      ),
                    ),
                    pw.SizedBox(height: 18),
                    pw.Text(
                      doctorName,
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: slateDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (hash.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                'Mã toàn vẹn chữ ký số SHA-256: $hash',
                style: pw.TextStyle(fontSize: 7.5, color: slateMuted),
              ),
            ],
          ],
        ),
      );

      await Printing.layoutPdf(
        name: 'Phieu_Ket_Qua_$orderCode.pdf',
        onLayout: (_) async => doc.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể xuất PDF: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  pw.Widget _pdfMeta(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label ',
              style: pw.TextStyle(
                fontSize: 8.8,
                color: PdfColor.fromHex('#475569'),
              ),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(
                fontSize: 8.8,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: PdfColor.fromHex('#0F172A'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfTh(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#0F172A'),
        ),
      ),
    );
  }

  pw.Widget _pdfTd(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColor.fromHex('#0F172A'),
        ),
      ),
    );
  }

  Future<void> _shareWithDoctor() async {
    final target = _resolvedOrderId ?? widget.orderId ?? '';
    if (target.isEmpty) return;
    setState(() => _sharing = true);
    try {
      final res = await _api.shareOrderResult(target);
      if (!mounted) return;
      setState(() => _sharing = false);
      final rawUrl = _pick(res, ['shareUrl', 'ShareUrl', 'verificationUrl']);
      final fullUrl = rawUrl.startsWith('http')
          ? rawUrl
          : '${BmsHttpClient.resolvedBaseUrl}$rawUrl';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Liên kết chia sẻ bác sĩ (7 ngày)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sao chép liên kết bảo mật bên dưới để gửi cho bác sĩ tư vấn bên ngoài:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              SelectableText(
                fullUrl,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
            ),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: fullUrl));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép liên kết chia sẻ bảo mật.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 17),
              label: const Text('Sao chép'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Phiếu kết quả xét nghiệm'),
        actions: [
          if (_result != null)
            IconButton(
              onPressed: _sharing ? null : _shareWithDoctor,
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Chia sẻ cho Bác sĩ',
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const BmsLoadingState(message: 'Đang tải phiếu kết quả y khoa...')
            : _error != null
            ? Padding(
                padding: const EdgeInsets.all(18),
                child: BmsErrorState(message: _error!, onRetry: _load),
              )
            : _buildReport(),
      ),
      bottomNavigationBar: _result == null
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.cardBorder)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sharing ? null : _shareWithDoctor,
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Chia sẻ BS'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _exportingPdf ? null : _exportRealA4Pdf,
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                        label: Text(
                          _exportingPdf
                              ? 'Đang tạo PDF A4...'
                              : 'In / Xuất PDF (A4)',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReport() {
    final r = _result!;
    final orderCode = _pick(r, ['orderId', 'OrderId', 'orderCode'], _resolvedOrderId ?? '');
    final patientName = _pick(r, ['patientName', 'PatientName'], BmsAuth.currentUserName);
    final patientCode = _pick(r, ['patientCode', 'PatientCode'], '—');
    final packageName = _pick(r, ['packageName', 'PackageName', 'testName'], 'Phiếu Kết Quả Xét Nghiệm');
    final barcode = _pick(r, ['barcode', 'Barcode', 'sampleCode'], '—');
    final techName = _pick(r, ['performedBy', 'PerformedBy'], 'KTV Phòng Xét Nghiệm');
    final doctorName = _pick(r, ['approvedByDoctor', 'ApprovedByDoctor'], 'Bác sĩ điều trị');
    final doctorSpec = _pick(r, ['doctorSpecialty', 'DoctorSpecialty'], 'Chuyên khoa Lâm sàng');
    final diagnosis = _pick(r, ['finalDiagnosis', 'FinalDiagnosis', 'doctorAssessment', 'DoctorAssessment', 'conclusion'], '');
    final icd10 = _pick(r, ['icd10Code', 'Icd10Code'], '');
    final advice = _pick(r, ['treatmentAdvice', 'TreatmentAdvice'], '');
    final hash = _pick(r, ['verificationHash', 'VerificationHash'], '');
    final params = _parameters;
    final abnormalCount = params
        .where((p) => _isAbnormalFlag(_pick(p, ['flag', 'Flag', 'abnormalFlag'], 'N')))
        .length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BmsSoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'ISO 15189:2022 • BẢN KÝ SỐ',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    BmsStatusPill(
                      status: abnormalCount > 0 ? 'High' : 'Normal',
                      customLabel: abnormalCount > 0
                          ? '$abnormalCount chỉ số bất thường'
                          : 'Tất cả bình thường',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  packageName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mã phiếu: $orderCode • Barcode: $barcode',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: AppColors.textSecondary,
                  ),
                ),
                const Divider(height: 22),
                BmsInfoRow(label: 'Bệnh nhân', value: patientName, isBold: true),
                BmsInfoRow(label: 'Mã BN (PID)', value: patientCode, isMono: true),
                BmsInfoRow(
                  label: 'Ngày sinh / Giới tính',
                  value:
                      '${BmsFormatters.date(r['dateOfBirth'] ?? r['DateOfBirth'])} • ${BmsFormatters.genderVi((r['gender'] ?? r['Gender'])?.toString())}',
                ),
                BmsInfoRow(
                  label: 'Lấy mẫu lúc',
                  value: BmsFormatters.dateTime(
                    r['collectionTime'] ?? r['CollectionTime'],
                  ),
                ),
                BmsInfoRow(
                  label: 'Ký duyệt lúc',
                  value: BmsFormatters.dateTime(
                    r['releasedDate'] ?? r['ReleasedDate'],
                  ),
                ),
                BmsInfoRow(label: 'KTV thực hiện', value: techName),
                BmsInfoRow(
                  label: 'BS phê duyệt',
                  value: '$doctorName ($doctorSpec)',
                  isBold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Parameters List
          BmsSoftCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bảng chi tiết chỉ số sinh học (${params.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ...params.map((p) {
                  final pCode = _pick(p, ['parameterCode', 'code'], '');
                  final pName = _pick(
                    p,
                    ['parameterName', 'ParameterName', 'name'],
                    pCode,
                  );
                  final val = _pick(p, ['value', 'Value'], '—');
                  final unit = _pick(p, ['unit', 'Unit'], '');
                  final ref = _pick(p, ['referenceRange', 'ReferenceRange'], '—');
                  final flag = _pick(p, ['flag', 'Flag', 'abnormalFlag'], 'N');
                  final abnormal = _isAbnormalFlag(flag);

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.cardBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pName,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Tham chiếu: $ref ${unit.isNotEmpty ? unit : ''}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$val ${unit.isNotEmpty ? unit : ''}',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: abnormal
                                    ? AppColors.danger
                                    : AppColors.textPrimary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            BmsStatusPill(
                              status: flag,
                              customLabel: _flagLabelVi(flag),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          if (diagnosis.isNotEmpty || advice.isNotEmpty || icd10.isNotEmpty) ...[
            const SizedBox(height: 12),
            BmsSoftCard(
              backgroundColor: AppColors.primaryLight,
              borderColor: AppColors.primaryBorder,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.medical_services_outlined,
                        color: AppColors.primary,
                        size: 19,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Chẩn đoán & Kết luận của Bác sĩ',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (icd10.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Mã bệnh ICD-10: $icd10',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  if (diagnosis.isNotEmpty)
                    Text(
                      diagnosis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  if (advice.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Lời dặn: $advice',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          if (hash.isNotEmpty) ...[
            const SizedBox(height: 12),
            BmsSoftCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chữ ký số SHA-256: $hash',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
