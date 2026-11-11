import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme/app_theme.dart';

class NativeEventsScreen extends StatefulWidget {
  const NativeEventsScreen({
    super.key,
    required this.api,
    required this.user,
  });

  final ApiClient api;
  final Map<String, dynamic> user;

  @override
  State<NativeEventsScreen> createState() => _NativeEventsScreenState();
}

class _NativeEventsScreenState extends State<NativeEventsScreen> {
  String? _facilityId;
  List<dynamic> _facilities = const [];
  Future<List<dynamic>>? _events;
  String? _error;

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
      _loadEvents();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _loadEvents() {
    final id = _facilityId;
    if (id == null || id.isEmpty) {
      setState(() => _events = Future.value(const []));
      return;
    }
    setState(() => _events = widget.api.facilityEvents(id, openOnly: false));
  }

  Color _sev(String? s) {
    final v = (s ?? '').toLowerCase();
    if (v.contains('critical') || v.contains('حرج') || v.contains('عاج')) return MsdColors.danger;
    if (v.contains('high') || v.contains('عال')) return MsdColors.amber;
    if (v.contains('med') || v.contains('متوسط')) return MsdColors.cyan;
    return MsdColors.green;
  }

  bool _isOpen(Map<String, dynamic> e) {
    final status = (e['status']?.toString() ?? '').toLowerCase();
    return status.contains('open') || status.contains('مفتوح') || status.contains('جاري') || e['closedAt'] == null;
  }

  Future<void> _createEvent() async {
    final id = _facilityId;
    if (id == null) return;
    final title = TextEditingController();
    final details = TextEditingController();
    var kind = 'طبي';
    var severity = 'متوسط';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('حدث جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'النوع'),
                  items: const [
                    DropdownMenuItem(value: 'طبي', child: Text('طبي')),
                    DropdownMenuItem(value: 'إمداد', child: Text('إمداد')),
                    DropdownMenuItem(value: 'أسطول', child: Text('أسطول')),
                    DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
                  ],
                  onChanged: (v) => setLocal(() => kind = v ?? kind),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: severity,
                  decoration: const InputDecoration(labelText: 'الخطورة'),
                  items: const [
                    DropdownMenuItem(value: 'عاجل', child: Text('عاجل')),
                    DropdownMenuItem(value: 'مرتفع', child: Text('مرتفع')),
                    DropdownMenuItem(value: 'متوسط', child: Text('متوسط')),
                    DropdownMenuItem(value: 'منخفض', child: Text('منخفض')),
                  ],
                  onChanged: (v) => setLocal(() => severity = v ?? severity),
                ),
                const SizedBox(height: 10),
                TextField(controller: details, decoration: const InputDecoration(labelText: 'التفاصيل'), maxLines: 3),
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
      await widget.api.createFacilityEvent(
        id,
        title: title.text.trim(),
        kind: kind,
        severity: severity,
        details: details.text.trim().isEmpty ? null : details.text.trim(),
      );
      _loadEvents();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _closeEvent(Map<String, dynamic> e) async {
    final id = _facilityId;
    final eventId = e['id']?.toString();
    if (id == null || eventId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إغلاق الحدث'),
        content: Text('إغلاق «${e['title'] ?? ''}»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إغلاق')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await widget.api.closeFacilityEvent(id, eventId);
      _loadEvents();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأحداث الطبية'),
        actions: [
          IconButton(tooltip: 'تحديث', onPressed: _bootstrap, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _facilityId == null ? null : _createEvent,
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('حدث'),
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
                        _loadEvents();
                      },
                    ),
                  ),
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: _events,
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
                        return const Center(child: Text('لا توجد أحداث لهذه المنشأة'));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final e = Map<String, dynamic>.from(rows[i] as Map);
                          final sev = e['severity']?.toString() ?? '';
                          final color = _sev(sev);
                          final open = _isOpen(e);
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: ListTile(
                              onLongPress: open ? () => _closeEvent(e) : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: MsdColors.line),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.15),
                                child: Icon(Icons.monitor_heart_outlined, color: color),
                              ),
                              title: Text(
                                e['title']?.toString() ?? 'حدث',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                '${e['kind'] ?? ''} · ${e['status'] ?? ''}\n${e['createdAt'] ?? ''}',
                              ),
                              isThreeLine: true,
                              trailing: open
                                  ? IconButton(
                                      tooltip: 'إغلاق',
                                      onPressed: () => _closeEvent(e),
                                      icon: const Icon(Icons.check_circle_outline, color: MsdColors.green),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        sev.isEmpty ? 'مغلق' : sev,
                                        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
                                      ),
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
