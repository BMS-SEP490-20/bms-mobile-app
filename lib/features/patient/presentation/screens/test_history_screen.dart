import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../services/bms_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/test_history_repository.dart';
import '../../models/test_history_model.dart';

String _date(DateTime? value) => value == null
    ? 'Chưa ghi nhận'
    : DateFormat(
        'dd/MM/yyyy HH:mm',
      ).format(value.toUtc().add(const Duration(hours: 7)));
String _flag(String value) =>
    const {
      '0': 'Bình thường',
      'Normal': 'Bình thường',
      'N': 'Bình thường',
      '1': 'Thấp',
      'Low': 'Thấp',
      'L': 'Thấp',
      '2': 'Cao',
      'High': 'Cao',
      'H': 'Cao',
      '3': 'Nguy hiểm',
      'CriticalPanic': 'Nguy hiểm',
      'CRITICAL': 'Nguy hiểm',
    }[value] ??
    (value.isEmpty ? 'Chưa ghi nhận' : value);

/// UC76 searchable history in the existing patient theme; backend ownership remains authoritative.
class TestHistoryScreen extends StatefulWidget {
  final TestHistoryRepository? repository;
  const TestHistoryScreen({super.key, this.repository});
  @override
  State<TestHistoryScreen> createState() => _TestHistoryScreenState();
}

class _TestHistoryScreenState extends State<TestHistoryScreen> {
  late final TestHistoryRepository _repository =
      widget.repository ?? TestHistoryRepository();
  final _search = TextEditingController();
  final _patient = TextEditingController();
  Timer? _debounce;
  TestHistoryPage? _data;
  String? _error;
  DateTimeRange? _range;
  int _page = 1, _generation = 0;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    if (TestHistoryRepository.canView) _load();
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    _patient.dispose();
    if (widget.repository == null) _repository.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final result = await _repository.list(
        search: _search.text.trim(),
        patientId: _patient.text.trim(),
        fromDate: _range == null
            ? ''
            : DateFormat('yyyy-MM-dd').format(_range!.start),
        toDate: _range == null
            ? ''
            : DateFormat('yyyy-MM-dd').format(_range!.end),
        page: _page,
      );
      if (!mounted || generation != _generation) return;
      if (_page > (result.totalPages < 1 ? 1 : result.totalPages)) {
        _page = result.totalPages < 1 ? 1 : result.totalPages;
        await _load();
        return;
      }
      setState(() => _data = result);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = error is TestHistoryException
              ? error.message
              : 'Không thể kết nối hoặc đọc lịch sử. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _changed(String _) {
    _debounce?.cancel();
    _generation++;
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _page = 1;
      _load();
    });
  }

  Future<void> _pickDates() async {
    final value = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      initialDateRange: _range,
      helpText: 'Ngày ghi nhận kết quả (UTC+7)',
    );
    if (!mounted || value == null) return;
    setState(() {
      _range = value;
      _page = 1;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!TestHistoryRepository.canView) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lịch sử xét nghiệm')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cần đăng nhập bằng tài khoản có quyền xem lịch sử.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/login').then((_) {
                        if (mounted) {
                          setState(() {});
                          if (TestHistoryRepository.canView) _load();
                        }
                      }),
                  child: const Text('Đăng nhập'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch sử xét nghiệm'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _search,
                      maxLength: 100,
                      onChanged: _changed,
                      decoration: const InputDecoration(
                        labelText: 'Mã kết quả, ID mẫu hoặc ID gói',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    TextField(
                      controller: _patient,
                      maxLength: 100,
                      onChanged: _changed,
                      decoration: const InputDecoration(
                        labelText: 'ID bệnh nhân (trong phạm vi được phép)',
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickDates,
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            _range == null
                                ? 'Chọn khoảng ngày'
                                : '${DateFormat('dd/MM/yyyy').format(_range!.start)} – ${DateFormat('dd/MM/yyyy').format(_range!.end)}',
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _debounce?.cancel();
                            _search.clear();
                            _patient.clear();
                            setState(() {
                              _range = null;
                              _page = 1;
                            });
                            _load();
                          },
                          child: const Text('Xóa bộ lọc'),
                        ),
                      ],
                    ),
                    const Text(
                      'Giờ UTC+7. Kết quả chưa có ngày sẽ không nằm trong bộ lọc khoảng ngày. Bệnh nhân chỉ xem dữ liệu liên kết tài khoản.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              ...List.generate(
                3,
                (_) => const Card(
                  child: SizedBox(
                    height: 80,
                    child: Center(child: LinearProgressIndicator()),
                  ),
                ),
              ),
            if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_data != null) ...[
              Text(
                '${_data!.total} kết quả',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (_data!.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: AppColors.textMuted),
                      Text('Chưa có lịch sử phù hợp'),
                    ],
                  ),
                )
              else
                ..._data!.items.map(
                  (result) => Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        result.packageName.isEmpty
                            ? 'Chưa ghi nhận gói'
                            : result.packageName,
                      ),
                      subtitle: Text(
                        '${result.resultCode.isEmpty ? result.id : result.resultCode}\nMẫu: ${result.sampleId}\nBệnh nhân: ${result.patientId}\n${_date(result.createdAt)}\n${result.available ? 'Đã phát hành' : 'Đang phân tích'}',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.primary,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _HistoryDetailScreen(
                            id: result.id,
                            repository: _repository,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _page <= 1 || _loading
                        ? null
                        : () {
                            _page--;
                            _load();
                          },
                    child: const Text('Trước'),
                  ),
                  Text(
                    '$_page/${_data!.totalPages < 1 ? 1 : _data!.totalPages}',
                  ),
                  TextButton(
                    onPressed: _page >= _data!.totalPages || _loading
                        ? null
                        : () {
                            _page++;
                            _load();
                          },
                    child: const Text('Sau'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reloads guarded detail rather than carrying clinical values in route arguments or local storage.
class _HistoryDetailScreen extends StatefulWidget {
  final String id;
  final TestHistoryRepository repository;
  const _HistoryDetailScreen({required this.id, required this.repository});
  @override
  State<_HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<_HistoryDetailScreen> {
  final _sessionToken = BmsAuth.accessToken;
  late Future<TestHistoryDetail> _detail = widget.repository.detail(widget.id);
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Chi tiết xét nghiệm'),
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: () =>
              setState(() => _detail = widget.repository.detail(widget.id)),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<TestHistoryDetail>(
      future: _detail,
      builder: (context, snapshot) {
        if (!TestHistoryRepository.canView ||
            _sessionToken != BmsAuth.accessToken) {
          return const Center(
            child: Text('Phiên đăng nhập đã thay đổi. Hãy mở lại lịch sử.'),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.error is TestHistoryException
                        ? snapshot.error.toString()
                        : 'Không thể tải chi tiết kết quả.',
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _detail = widget.repository.detail(widget.id),
                    ),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }
        final detail = snapshot.data!;
        final summary = detail.summary;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.packageName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    SelectableText(
                      summary.resultCode.isEmpty
                          ? summary.id
                          : summary.resultCode,
                    ),
                    Text(
                      'Bệnh nhân: ${summary.patientId}\nMẫu: ${summary.sampleId}\nNgày ghi nhận: ${_date(summary.createdAt)}\nNgày duyệt: ${_date(summary.approvedAt)}',
                    ),
                  ],
                ),
              ),
            ),
            if (!summary.available)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Đang phân tích. Chỉ số và kết luận chỉ hiển thị khi kết quả đã duyệt, có chữ ký và không còn yêu cầu chạy lại.',
                  ),
                ),
              )
            else ...[
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Đã duyệt và có chữ ký',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (detail.items.isEmpty) const Text('Chưa có chỉ số được lưu.'),
              ...detail.items.map(
                (item) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name.isEmpty ? item.code : item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${item.value.isEmpty ? 'Chưa ghi nhận' : item.value} ${item.unit}',
                            style: const TextStyle(
                              fontSize: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Text(
                          'Tham chiếu: ${item.referenceRange.isEmpty ? 'Chưa ghi nhận' : item.referenceRange}',
                        ),
                        Text('Cờ đã lưu: ${_flag(item.flag)}'),
                      ],
                    ),
                  ),
                ),
              ),
              if (detail.conclusion?.isNotEmpty == true)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Kết luận đã ghi nhận\n${detail.conclusion}'),
                  ),
                ),
            ],
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Thời gian UTC+7. Không tự tính lại chỉ số, cờ hoặc khoảng tham chiếu.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        );
      },
    ),
  );
}
