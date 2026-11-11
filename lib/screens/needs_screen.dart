import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme/app_theme.dart';

class NeedsScreen extends StatefulWidget {
  const NeedsScreen({
    super.key,
    required this.api,
    required this.user,
  });

  final ApiClient api;
  final Map<String, dynamic> user;

  @override
  State<NeedsScreen> createState() => _NeedsScreenState();
}

class _NeedsScreenState extends State<NeedsScreen> {
  String? _facilityId;
  List<dynamic> _facilities = const [];
  Future<List<dynamic>>? _needs;
  String? _error;
  var _openOnly = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final linked = widget.user['facilityId']?.toString();
      final list = await widget.api.facilities();
      if (!mounted) return;
      setState(() {
        _facilities = list;
        _facilityId = (linked != null && linked.isNotEmpty)
            ? linked
            : (list.isNotEmpty ? (list.first as Map)['id']?.toString() : null);
        _error = null;
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _load() {
    final id = _facilityId;
    if (id == null || id.isEmpty) {
      setState(() => _needs = Future.value(const []));
      return;
    }
    setState(() => _needs = widget.api.facilityNeeds(id, openOnly: _openOnly));
  }

  Future<void> _createNeed() async {
    final id = _facilityId;
    if (id == null) return;
    final title = TextEditingController();
    final qty = TextEditingController(text: '1');
    final notes = TextEditingController();
    var category = 'مستلزمات';
    var priority = 'متوسط';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('احتياج جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'التصنيف'),
                  items: const [
                    DropdownMenuItem(value: 'مستلزمات', child: Text('مستلزمات')),
                    DropdownMenuItem(value: 'أدوية', child: Text('أدوية')),
                    DropdownMenuItem(value: 'أجهزة', child: Text('أجهزة')),
                    DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
                  ],
                  onChanged: (v) => setLocal(() => category = v ?? category),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'الأولوية'),
                  items: const [
                    DropdownMenuItem(value: 'عاجل', child: Text('عاجل')),
                    DropdownMenuItem(value: 'مرتفع', child: Text('مرتفع')),
                    DropdownMenuItem(value: 'متوسط', child: Text('متوسط')),
                    DropdownMenuItem(value: 'منخفض', child: Text('منخفض')),
                  ],
                  onChanged: (v) => setLocal(() => priority = v ?? priority),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الكمية'),
                ),
                const SizedBox(height: 10),
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'ملاحظات')),
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
    if (title.text.trim().isEmpty) return;
    try {
      await widget.api.createFacilityNeed(
        id,
        title: title.text.trim(),
        category: category,
        priority: priority,
        quantity: int.tryParse(qty.text.trim()) ?? 1,
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _setStatus(Map<String, dynamic> row, String status) async {
    final id = _facilityId;
    final needId = row['id']?.toString();
    if (id == null || needId == null) return;
    try {
      await widget.api.updateFacilityNeedStatus(id, needId, status);
      _load();
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
        title: const Text('الاحتياجات'),
        actions: [
          IconButton(
            tooltip: _openOnly ? 'إظهار الكل' : 'المفتوحة فقط',
            onPressed: () {
              setState(() => _openOnly = !_openOnly);
              _load();
            },
            icon: Icon(_openOnly ? Icons.filter_alt : Icons.filter_alt_off),
          ),
          IconButton(tooltip: 'تحديث', onPressed: _bootstrap, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _facilityId == null ? null : _createNeed,
        icon: const Icon(Icons.add),
        label: const Text('احتياج'),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _bootstrap, child: const Text('إعادة المحاولة')),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                if (_facilities.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: DropdownButtonFormField<String>(
                      initialValue: _facilityId,
                      decoration: const InputDecoration(labelText: 'المنشأة'),
                      items: _facilities.map((raw) {
                        final f = Map<String, dynamic>.from(raw as Map);
                        final id = f['id']?.toString() ?? '';
                        return DropdownMenuItem(
                          value: id,
                          child: Text(f['nameAr']?.toString() ?? id),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() => _facilityId = v);
                        _load();
                      },
                    ),
                  ),
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: _needs,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(
                          child: Text(snap.error.toString().replaceFirst('Exception: ', '')),
                        );
                      }
                      final rows = snap.data ?? const [];
                      if (rows.isEmpty) {
                        return const Center(child: Text('لا توجد احتياجات'));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final e = Map<String, dynamic>.from(rows[i] as Map);
                          final status = e['status']?.toString() ?? '';
                          final open = status.toLowerCase().contains('open') ||
                              status.contains('مفتوح') ||
                              status.contains('قيد');
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: MsdColors.line),
                              ),
                              title: Text(
                                e['title']?.toString() ?? 'احتياج',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                '${e['category'] ?? ''} · أولوية ${e['priority'] ?? ''} · كمية ${e['quantity'] ?? ''}\n$status',
                              ),
                              isThreeLine: true,
                              trailing: open
                                  ? PopupMenuButton<String>(
                                      onSelected: (v) => _setStatus(e, v),
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'مُلبّى', child: Text('تم التلبية')),
                                        PopupMenuItem(value: 'ملغى', child: Text('إلغاء')),
                                        PopupMenuItem(value: 'قيد التوريد', child: Text('قيد التوريد')),
                                      ],
                                    )
                                  : Icon(
                                      Icons.check_circle,
                                      color: status.contains('ملغ') ? MsdColors.faint : MsdColors.green,
                                    ),
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
