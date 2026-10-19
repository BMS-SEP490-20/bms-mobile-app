import 'package:flutter/material.dart';
import '../data/walkin_repository.dart';
import '../domain/walkin_models.dart';

/// UC26 – Walk-in registration (mobile receptionist / field nurse).
/// Medical Blue #1E40AF, sticky CTA, touch ≥44px.
class RegisterWalkInPage extends StatefulWidget {
  final WalkInRepository repository;

  const RegisterWalkInPage({super.key, required this.repository});

  @override
  State<RegisterWalkInPage> createState() => _RegisterWalkInPageState();
}

class _RegisterWalkInPageState extends State<RegisterWalkInPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cccdCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  String _gender = 'Male';
  bool _loading = false;
  String? _error;
  RegisterWalkInResponse? _result;

  static const _primary = Color(0xFF1E40AF);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cccdCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.repository.register(RegisterWalkInRequest(
        fullName: _nameCtrl.text.trim(),
        dateOfBirth: _dobCtrl.text.trim(),
        gender: _gender,
        phone: _phoneCtrl.text.trim(),
        identityNumber: _cccdCtrl.text.trim(),
      ));
      setState(() => _result = res);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đăng ký thành công'), backgroundColor: _primary),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mã BN: ${_result!.patientId}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Họ tên: ${_result!.fullName}'),
              Text('CCCD: ${_result!.identityNumber}'),
              Text('Ưu tiên: ${_result!.priority}'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _primary),
                  onPressed: () => setState(() {
                    _result = null;
                    _nameCtrl.clear();
                    _cccdCtrl.clear();
                    _phoneCtrl.clear();
                    _dobCtrl.clear();
                  }),
                  child: const Text('Đăng ký tiếp'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('BN vãng lai (UC26)'), backgroundColor: _primary),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Họ và tên *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dobCtrl,
              decoration: const InputDecoration(labelText: 'Ngày sinh YYYY-MM-DD *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: 'Giới tính', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Nam')),
                DropdownMenuItem(value: 'Female', child: Text('Nữ')),
                DropdownMenuItem(value: 'Other', child: Text('Khác')),
              ],
              onChanged: (v) => setState(() => _gender = v ?? 'Male'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cccdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'CCCD *', border: OutlineInputBorder()),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Bắt buộc';
                if (v.length != 9 && v.length != 12) return '9 hoặc 12 số';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'SĐT *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'Đang lưu…' : 'Đăng ký'),
            ),
          ),
        ),
      ),
    );
  }
}
