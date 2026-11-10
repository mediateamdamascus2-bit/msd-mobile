import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../services/new_item_watcher.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class HasiaCasesScreen extends StatefulWidget {
  const HasiaCasesScreen({super.key, required this.api, required this.user});

  final ApiClient api;
  final Map<String, dynamic> user;

  @override
  State<HasiaCasesScreen> createState() => _HasiaCasesScreenState();
}

class _HasiaCasesScreenState extends State<HasiaCasesScreen> {
  late Future<List<dynamic>> _future;
  var _archive = false;

  static const _services = [
    ('p-er', 'إسعاف النقطة'),
    ('p-dent', 'عيادة سنية أولية'),
    ('p-int', 'عيادة داخلية أولية'),
    ('h-er', 'إسعاف المشفى'),
    ('h-int', 'عيادة داخلية متقدمة'),
    ('h-surg', 'عيادة الجراحة العظمية'),
    ('h-or', 'غرفة العمليات'),
    ('h-icu', 'أسرّة العناية'),
    ('h-ward', 'أسرّة الاستشفاء'),
    ('h-dent', 'عيادة سنية متقدمة'),
  ];

  Timer? _timer;
  final _watcher = NewItemWatcher();

  @override
  void initState() {
    super.initState();
    _reload();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) => _silentReload());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reload() {
    final archive = _archive;
    final future = widget.api.hasiaCases(archiveOnly: archive);
    if (!archive) future.then((rows) => _watcher.absorb(rows, idKey: 'caseCode'), onError: (_) {});
    setState(() => _future = future);
  }

  Future<void> _silentReload() async {
    final archive = _archive;
    try {
      final rows = await widget.api.hasiaCases(archiveOnly: archive);
      if (!mounted || archive != _archive) return;
      if (!archive) {
        final fresh = _watcher.diff(rows, idKey: 'caseCode');
        NotificationService.instance.newPatients(
          fresh.map((m) => 'نزيل ${m['inmateNo'] ?? ''} · ${m['complaint'] ?? ''}').toList(),
          where: 'حالات حسيا',
        );
      }
      setState(() => _future = Future.value(rows));
    } catch (_) {
      // Keep the last good list; the next tick retries.
    }
  }

  Future<void> _openTriage() async {
    final inmateNo = TextEditingController();
    final complaint = TextEditingController();
    final triager = TextEditingController(
      text: widget.user['displayNameAr']?.toString() ??
          widget.user['username']?.toString() ??
          'فرز',
    );
    var toService = _services.first.$1;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('فتح فرز'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: inmateNo, decoration: const InputDecoration(labelText: 'رقم النزيل')),
                const SizedBox(height: 8),
                TextField(controller: complaint, decoration: const InputDecoration(labelText: 'الشكوى'), maxLines: 2),
                const SizedBox(height: 8),
                TextField(controller: triager, decoration: const InputDecoration(labelText: 'المفرز')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: toService,
                  decoration: const InputDecoration(labelText: 'التوجيه إلى'),
                  items: _services
                      .map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2)))
                      .toList(),
                  onChanged: (v) => setLocal(() => toService = v ?? toService),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('فتح')),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    if (inmateNo.text.trim().isEmpty || complaint.text.trim().isEmpty) return;

    try {
      await widget.api.hasiaTriage(
        triager: triager.text.trim(),
        inmateNo: inmateNo.text.trim(),
        complaint: complaint.text.trim(),
        toServiceId: toService,
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _step(Map<String, dynamic> row) async {
    final caseId = row['id']?.toString();
    if (caseId == null) return;
    final provider = TextEditingController(
      text: widget.user['displayNameAr']?.toString() ??
          widget.user['username']?.toString() ??
          'طبيب',
    );
    final diagnosis = TextEditingController();
    final note = TextEditingController();
    var action = 'complete';
    String? target;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('خطوة · ${row['caseCode'] ?? ''}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: provider, decoration: const InputDecoration(labelText: 'المقدم')),
                const SizedBox(height: 8),
                TextField(controller: diagnosis, decoration: const InputDecoration(labelText: 'التشخيص')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: action,
                  decoration: const InputDecoration(labelText: 'الإجراء'),
                  items: const [
                    DropdownMenuItem(value: 'complete', child: Text('إنهاء')),
                    DropdownMenuItem(value: 'transfer', child: Text('تحويل')),
                    DropdownMenuItem(value: 'hold', child: Text('تعليق')),
                  ],
                  onChanged: (v) => setLocal(() => action = v ?? action),
                ),
                if (action == 'transfer') ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: target,
                    decoration: const InputDecoration(labelText: 'الوجهة'),
                    items: _services
                        .map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2)))
                        .toList(),
                    onChanged: (v) => setLocal(() => target = v),
                  ),
                ],
                if (action == 'hold') ...[
                  const SizedBox(height: 8),
                  TextField(controller: note, decoration: const InputDecoration(labelText: 'سبب التعليق')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تنفيذ')),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    try {
      await widget.api.hasiaCaseStep(caseId, {
        'provider': provider.text.trim(),
        'diagnosis': diagnosis.text.trim().isEmpty ? null : diagnosis.text.trim(),
        'procedures': null,
        'meds': const [],
        'action': action,
        'targetServiceId': target,
        'holdReason': note.text.trim().isEmpty ? null : note.text.trim(),
      });
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  String _svcLabel(String? id) {
    for (final s in _services) {
      if (s.$1 == id) return s.$2;
    }
    return id ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_archive ? 'أرشيف الحالات' : 'الحالات الجارية'),
        actions: [
          IconButton(
            tooltip: _archive ? 'الجارية' : 'الأرشيف',
            onPressed: () {
              setState(() => _archive = !_archive);
              _reload();
            },
            icon: Icon(_archive ? Icons.folder_open : Icons.archive_outlined),
          ),
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: _archive
          ? null
          : FloatingActionButton.extended(
              onPressed: _openTriage,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('فرز'),
            ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'.replaceFirst('Exception: ', '')));
          }
          final rows = snap.data ?? const [];
          if (rows.isEmpty) {
            return const Center(child: Text('لا توجد حالات'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final m = Map<String, dynamic>.from(rows[i] as Map);
              final status = m['status']?.toString() ?? '';
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  onTap: _archive ? null : () => _step(m),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: MsdColors.line),
                  ),
                  title: Text(
                    '${m['caseCode'] ?? ''} · نزيل ${m['inmateNo'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${m['complaint'] ?? ''}\n${_svcLabel(m['atServiceId']?.toString())} · $status',
                  ),
                  isThreeLine: true,
                  trailing: _archive
                      ? const Icon(Icons.check_circle, color: MsdColors.green)
                      : const Icon(Icons.chevron_left),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
