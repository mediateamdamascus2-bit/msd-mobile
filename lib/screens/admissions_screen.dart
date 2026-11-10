import 'package:flutter/material.dart';

import '../api_client.dart';

class AdmissionsScreen extends StatefulWidget {
  const AdmissionsScreen({
    super.key,
    required this.api,
    required this.facilityId,
    required this.facilityName,
  });

  final ApiClient api;
  final String facilityId;
  final String facilityName;

  @override
  State<AdmissionsScreen> createState() => _AdmissionsScreenState();
}

class _AdmissionsScreenState extends State<AdmissionsScreen> {
  final _admissions = TextEditingController();
  final _occupied = TextEditingController();
  final _available = TextEditingController();
  final _transfers = TextEditingController();
  final _notes = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _ok;
  String? _updatedMeta;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _admissions.dispose();
    _occupied.dispose();
    _available.dispose();
    _transfers.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _ok = null;
    });
    try {
      final data = await widget.api.getTodayAdmissions(widget.facilityId);
      _admissions.text = '${data['admissionsCount'] ?? 0}';
      _occupied.text = '${data['occupiedBeds'] ?? 0}';
      _available.text = '${data['availableBeds'] ?? 0}';
      _transfers.text = '${data['transfersCount'] ?? 0}';
      _notes.text = data['notes']?.toString() ?? '';
      final by = data['updatedBy']?.toString() ?? '';
      final at = data['updatedAt']?.toString() ?? '';
      _updatedMeta = by.isEmpty ? null : 'آخر تحديث: $at · بواسطة $by';
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _ok = null;
    });
    try {
      final data = await widget.api.putTodayAdmissions(
        widget.facilityId,
        admissionsCount: int.tryParse(_admissions.text) ?? 0,
        occupiedBeds: int.tryParse(_occupied.text) ?? 0,
        availableBeds: int.tryParse(_available.text) ?? 0,
        transfersCount: int.tryParse(_transfers.text) ?? 0,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      final by = data['updatedBy']?.toString() ?? '';
      final at = data['updatedAt']?.toString() ?? '';
      _updatedMeta = by.isEmpty ? null : 'آخر تحديث: $at · بواسطة $by';
      _ok = 'تم حفظ أرقام الإشغالات بنجاح.';
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشغالات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(widget.facilityName, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text(
                  'تسجيل أرقام اليوم — يظهر في لوحة المنشأة',
                  style: TextStyle(color: Colors.black54),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (_ok != null) ...[
                  const SizedBox(height: 12),
                  Text(_ok!, style: const TextStyle(color: Color(0xFF2E9E6C))),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _admissions,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'عدد القبول',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _occupied,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'أسرة مشغولة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _available,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'أسرة فارغة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _transfers,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'التحويلات',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'جاري الحفظ...' : 'حفظ الأرقام'),
                ),
                if (_updatedMeta != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _updatedMeta!,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ],
            ),
    );
  }
}
