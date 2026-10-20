import 'package:flutter/material.dart';
import '../../data/iot_threshold_repository.dart';
import '../../models/iot_threshold_model.dart';

/// UC67 — Configure IoT Thresholds (Mobile)
/// Manager mobile screen for setting IoT environmental telemetry alert thresholds.
class ConfigureIotThresholdsScreen extends StatefulWidget {
  const ConfigureIotThresholdsScreen({super.key});

  @override
  State<ConfigureIotThresholdsScreen> createState() => _ConfigureIotThresholdsScreenState();
}

class _ConfigureIotThresholdsScreenState extends State<ConfigureIotThresholdsScreen> {
  final IotThresholdRepository _repository = IotThresholdRepository();
  IotConfigSummaryModel? _summary;
  List<IotThresholdModel> _thresholds = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summary = await _repository.fetchSummary();
      if (mounted) {
        setState(() {
          _summary = summary;
          _thresholds = summary?.thresholds ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load IoT thresholds.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSaveAll() async {
    setState(() => _isSaving = true);
    try {
      final success = await _repository.batchUpdateThresholds(_thresholds);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success ? const Color(0xFF16A34A) : Colors.redAccent,
            content: Text(success ? 'All IoT thresholds saved successfully!' : 'Failed to save thresholds.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleResetDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Defaults'),
        content: const Text('Restore all IoT sensor thresholds to standard laboratory regulatory boundaries?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await _repository.resetDefaults();
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Configure IoT Thresholds',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset defaults',
            onPressed: _handleResetDefaults,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6929C4)))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Overview Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_thresholds.length} Active Sensors',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                const Text('Cold storage & lab ambient monitoring', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                            FilledButton.icon(
                              onPressed: _isSaving ? null : _handleSaveAll,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF6929C4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.save, size: 16),
                              label: Text(_isSaving ? 'Saving' : 'Save all', style: const TextStyle(fontSize: 12.5)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Device Thresholds List
                      ..._thresholds.map((device) => _buildDeviceCard(device)),

                      const SizedBox(height: 16),

                      // Alert Recipients Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alert Recipients',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (_summary?.recipients ?? []).map((r) {
                                return Chip(
                                  avatar: const Icon(Icons.person, size: 16, color: Color(0xFF0284C7)),
                                  label: Text('${r.fullName} (${r.role})', style: const TextStyle(fontSize: 12)),
                                  backgroundColor: const Color(0xFFF1F5F9),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _summary?.escalationPolicy ?? 'FCM + Email notification. Escalates to SMS after 5 min.',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDeviceCard(IotThresholdModel device) {
    final isTemp = device.sensorType == 'Temperature';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    device.deviceId,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    device.location,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isTemp ? const Color(0xFFE0F2FE) : const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isTemp ? 'Temp' : 'Humidity',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isTemp ? const Color(0xFF0369A1) : const Color(0xFF7E22CE),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: device.lowAlert.toString(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: 'Low Alert',
                    suffixText: device.unit,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final d = double.tryParse(val);
                    if (d != null) device.lowAlert = d;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: device.highAlert.toString(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: 'High Alert',
                    suffixText: device.unit,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final d = double.tryParse(val);
                    if (d != null) device.highAlert = d;
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: device.intervalSeconds.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Interval',
                    suffixText: 's',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final i = int.tryParse(val);
                    if (i != null) device.intervalSeconds = i;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
