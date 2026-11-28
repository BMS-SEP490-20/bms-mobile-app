import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bms_ui_kit.dart';
import '../../data/staff_portal_api.dart';

/// Lightweight Mobile IoT Cold-Chain Status & Alerts Monitor
/// shared by Manager (`canAcknowledge: true`) and Admin (`canAcknowledge: false` per RBAC).
class StaffIotMonitorTab extends StatefulWidget {
  final bool canAcknowledge;

  const StaffIotMonitorTab({super.key, required this.canAcknowledge});

  @override
  State<StaffIotMonitorTab> createState() => _StaffIotMonitorTabState();
}

class _StaffIotMonitorTabState extends State<StaffIotMonitorTab> {
  final StaffPortalApi _api = const StaffPortalApi();

  bool _loading = true;
  String? _error;
  int _segment = 0;
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Future.wait([
        _api.getIotDevices(),
        _api.getIotAlerts(),
      ]);
      if (!mounted) return;
      setState(() {
        _devices = res[0];
        _alerts = res[1];
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

  Future<void> _acknowledge(Map<String, dynamic> alert) async {
    final id = (alert['id'] ?? alert['alertId'] ?? '').toString();
    if (id.isEmpty) return;
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xử lý cảnh báo IoT'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Ghi chú xử lý (tùy chọn)',
            hintText: 'VD: Đã kiểm tra cửa tủ lạnh & ổn định nhiệt độ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.acknowledgeIotAlert(id, note: noteCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xác nhận cảnh báo IoT.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final openAlerts = _alerts
        .where(
          (a) =>
              a['isAcknowledged'] != true &&
              (a['status'] ?? '').toString().toLowerCase() != 'acknowledged' &&
              (a['status'] ?? '').toString().toLowerCase() != 'resolved',
        )
        .length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BmsPageHeaderCard(
            icon: Icons.sensors_rounded,
            badgeText: widget.canAcknowledge
                ? 'GIÁM SÁT CHUỖI LẠNH IOT • QUẢN LÝ'
                : 'CHỈ XEM • HẠ TẦNG IOT',
            title: 'Giám sát Tủ bảo quản IoT',
            subtitle:
                '${_devices.length} cảm biến • $openAlerts cảnh báo chưa xác nhận',
          ),
          const SizedBox(height: 12),
          BmsSegmentedTabs(
            tabs: [
              'Thiết bị (${_devices.length})',
              'Cảnh báo (${_alerts.length})',
            ],
            selectedIndex: _segment,
            onChanged: (i) => setState(() => _segment = i),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const BmsLoadingState(message: 'Đang đọc dữ liệu cảm biến IoT...')
          else if (_error != null)
            BmsErrorState(message: _error!, onRetry: _load)
          else if (_segment == 0)
            _buildDevices()
          else
            _buildAlerts(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDevices() {
    if (_devices.isEmpty) {
      return const BmsEmptyState(
        icon: Icons.thermostat_outlined,
        title: 'Chưa có thiết bị IoT kết nối',
        subtitle: 'Các cảm biến nhiệt độ / độ ẩm tủ mẫu sẽ hiển thị tại đây.',
      );
    }
    return Column(
      children: _devices.map((d) {
        final name = (d['deviceName'] ?? d['name'] ?? d['deviceId'] ?? 'Thiết bị IoT')
            .toString();
        final id = (d['deviceId'] ?? d['id'] ?? '').toString();
        final loc = (d['location'] ?? d['roomName'] ?? 'Kho lạnh mẫu').toString();
        final temp =
            d['latestTemperature'] ??
            d['temperature'] ??
            d['currentTemperature'] ??
            d['lastTemperature'];
        final hum =
            d['latestHumidity'] ??
            d['humidity'] ??
            d['currentHumidity'] ??
            d['lastHumidity'];
        final connState = (d['connectionState'] ?? '').toString().toLowerCase();
        final statusStr = (d['status'] ?? d['latestStatus'] ?? '')
            .toString()
            .toLowerCase();
        final online =
            d['isConnected'] == true ||
            d['isOnline'] == true ||
            connState == 'connected' ||
            statusStr == 'online' ||
            statusStr == 'normal';

        return BmsSoftCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '$id • $loc',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  BmsStatusPill(
                    status: online ? 'Active' : 'Cancelled',
                    customLabel: online ? 'Trực tuyến' : 'Mất kết nối',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _metricBox(
                      'Nhiệt độ',
                      temp != null ? '$temp °C' : '—',
                      Icons.thermostat_rounded,
                      AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metricBox(
                      'Độ ẩm',
                      hum != null ? '$hum %' : '—',
                      Icons.water_drop_outlined,
                      AppColors.teal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _metricBox(String label, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                val,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlerts() {
    if (_alerts.isEmpty) {
      return const BmsEmptyState(
        icon: Icons.verified_outlined,
        title: 'Không có cảnh báo IoT',
        subtitle: 'Tất cả tủ bảo quản mẫu đang nằm trong ngưỡng an toàn.',
      );
    }
    return Column(
      children: _alerts.map((a) {
        final ack = a['isAcknowledged'] == true ||
            (a['status'] ?? '').toString().toLowerCase() == 'acknowledged' ||
            (a['status'] ?? '').toString().toLowerCase() == 'resolved';
        final device = (a['deviceName'] ?? a['deviceId'] ?? 'Thiết bị IoT').toString();
        final sensorType = (a['sensorType'] ?? '').toString();
        final observed = a['observedValue'];
        final unit = (a['unit'] ?? '').toString();
        final low = a['lowAlert'];
        final high = a['highAlert'];
        final fallbackMsg = sensorType.isNotEmpty && observed != null
            ? '$sensorType: $observed$unit (Ngưỡng: $low–$high$unit)'
            : 'Cảnh báo vượt ngưỡng';
        final msg = (a['message'] ?? a['description'] ?? fallbackMsg)
            .toString();

        return BmsSoftCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          borderColor: ack ? AppColors.cardBorder : AppColors.dangerBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      device,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  BmsStatusPill(
                    status: ack ? 'Completed' : 'Critical',
                    customLabel: ack ? 'Đã xác nhận' : 'Cần xử lý',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                msg,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                BmsFormatters.dateTime(a['createdAt'] ?? a['triggeredAt']),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              if (widget.canAcknowledge && !ack) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _acknowledge(a),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Xác nhận đã tiếp nhận cảnh báo'),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
