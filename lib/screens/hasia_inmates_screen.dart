import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme/app_theme.dart';

class HasiaInmatesScreen extends StatefulWidget {
  const HasiaInmatesScreen({super.key, required this.api, required this.user});

  final ApiClient api;
  final Map<String, dynamic> user;

  @override
  State<HasiaInmatesScreen> createState() => _HasiaInmatesScreenState();
}

class _HasiaInmatesScreenState extends State<HasiaInmatesScreen> {
  late Future<List<dynamic>> _future;
  String _q = '';

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _future = widget.api.hasiaInmates();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _silentReload());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _silentReload() async {
    try {
      final rows = await widget.api.hasiaInmates();
      if (mounted) setState(() => _future = Future.value(rows));
    } catch (_) {
      // Keep the last good list; the next tick retries.
    }
  }

  Future<void> _reload() async {
    setState(() => _future = widget.api.hasiaInmates());
    await _future;
  }

  Future<void> _create() async {
    final inmateNo = TextEditingController();
    final fileNo = TextEditingController();
    final nationality = TextEditingController(text: 'سوري');
    final blood = TextEditingController(text: 'O+');
    final place = TextEditingController(text: 'حسيا');
    final entry = TextEditingController(
      text: DateTime.now().toIso8601String().split('T').first,
    );
    var sex = 'ذكر';
    var marital = 'أعزب';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('تسجيل نزيل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: inmateNo, decoration: const InputDecoration(labelText: 'رقم النزيل')),
                const SizedBox(height: 8),
                TextField(controller: fileNo, decoration: const InputDecoration(labelText: 'رقم الإضبارة')),
                const SizedBox(height: 8),
                TextField(controller: nationality, decoration: const InputDecoration(labelText: 'الجنسية')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: sex,
                  decoration: const InputDecoration(labelText: 'الجنس'),
                  items: const [
                    DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                    DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
                  ],
                  onChanged: (v) => setLocal(() => sex = v ?? sex),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: marital,
                  decoration: const InputDecoration(labelText: 'الحالة الاجتماعية'),
                  items: const [
                    DropdownMenuItem(value: 'أعزب', child: Text('أعزب')),
                    DropdownMenuItem(value: 'متزوج', child: Text('متزوج')),
                    DropdownMenuItem(value: 'مطلق', child: Text('مطلق')),
                    DropdownMenuItem(value: 'أرمل', child: Text('أرمل')),
                  ],
                  onChanged: (v) => setLocal(() => marital = v ?? marital),
                ),
                const SizedBox(height: 8),
                TextField(controller: blood, decoration: const InputDecoration(labelText: 'الزمرة')),
                const SizedBox(height: 8),
                TextField(controller: place, decoration: const InputDecoration(labelText: 'مكان الإيداع')),
                const SizedBox(height: 8),
                TextField(controller: entry, decoration: const InputDecoration(labelText: 'تاريخ الدخول')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    if (inmateNo.text.trim().isEmpty || fileNo.text.trim().isEmpty) return;

    try {
      await widget.api.createHasiaInmate({
        'inmateNo': inmateNo.text.trim(),
        'fileNo': fileNo.text.trim(),
        'nationality': nationality.text.trim(),
        'bloodType': blood.text.trim(),
        'sex': sex,
        'marital': marital,
        'place': place.text.trim(),
        'entryDate': entry.text.trim(),
        'chronicCsv': '',
        'allergies': '',
        'stays': [
          {
            'place': place.text.trim(),
            'entry': entry.text.trim(),
            'exit': null,
          }
        ],
      });
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل النزلاء'),
        actions: [
          IconButton(tooltip: 'تحديث', onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('نزيل'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'بحث برقم النزيل / الإضبارة',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done && !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('${snap.error}'.replaceFirst('Exception: ', '')));
                }
                var rows = snap.data ?? const [];
                if (_q.isNotEmpty) {
                  rows = rows.where((raw) {
                    final m = Map<String, dynamic>.from(raw as Map);
                    final blob = '${m['inmateNo']} ${m['fileNo']} ${m['place']}'.toLowerCase();
                    return blob.contains(_q.toLowerCase());
                  }).toList();
                }
                if (rows.isEmpty) {
                  return const Center(child: Text('لا يوجد نزلاء'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final m = Map<String, dynamic>.from(rows[i] as Map);
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: MsdColors.line),
                        ),
                        leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
                        title: Text(
                          'نزيل ${m['inmateNo'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          'إضبارة ${m['fileNo'] ?? ''} · ${m['sex'] ?? ''} · ${m['bloodType'] ?? ''}\n'
                          '${m['place'] ?? ''} · دخول ${m['entryDate'] ?? ''}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
