import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../data/command_data.dart';
import 'ops_chrome.dart';
import 'ops_live.dart';

/// الأحداث الطبية — directorate SITREP, plus create and close from the facility desk.
class OpsEventsScreen extends StatefulWidget {
  const OpsEventsScreen({super.key, required this.api, this.user, this.embedded = false});

  final ApiClient api;
  final Map<String, dynamic>? user;
  final bool embedded;

  @override
  State<OpsEventsScreen> createState() => _OpsEventsScreenState();
}

class _OpsEventsScreenState extends State<OpsEventsScreen> {
  static const _sev = ['عاجل', 'مرتفع', 'متوسط', 'منخفض', 'عادي'];

  OpsItem _ev(CommandData d, JsonRow e, Future<void> Function() refresh) {
    final sev = e['severity']?.toString() ?? 'عادي';
    final open = CommandData.isOpen(e);
    final status = open ? 'مفتوح' : 'مغلق';
    final fid = e['facilityId']?.toString();
    final id = e['id']?.toString() ?? '';
    final c = severityColor(sev);
    return OpsItem(
      id: id.length > 6 ? 'EV-${id.substring(0, 6).toUpperCase()}' : id,
      title: e['title']?.toString() ?? '—',
      subtitle: e['location'] != null
          ? '${e['kind'] ?? e['type'] ?? ''} · ${e['location']} — ${e['province'] ?? ''}'
          : '${e['kind'] ?? ''} · ${agoAr(CommandData.parseTime(e['createdAt']))} · '
              '${d.nameOf(fid)} — ${d.provinceOf(fid)}',
      icon: CommandData.severityRank(e) == 0 ? 'warn' : 'pulse',
      tone: c,
      filterValue: sev,
      group: status,
      pills: [OpsPill(sev, c), OpsPill(status, open ? OpsColors.amber : OpsColors.green)],
      actionLabel: open && fid != null && id.isNotEmpty ? 'إغلاق الحدث' : null,
      onAction: open && fid != null && id.isNotEmpty
          ? () => _close(fid, id, e['title']?.toString() ?? '', refresh)
          : null,
    );
  }

  Future<void> _create(CommandData d, Future<void> Function() refresh) async {
    final facilities = d.facilities.where((f) => (f['id']?.toString() ?? '').isNotEmpty).toList();
    if (facilities.isEmpty || !mounted) return;
    final linked = widget.user?['facilityId']?.toString();
    var facilityId = facilities.any((f) => f['id']?.toString() == linked)
        ? linked!
        : facilities.first['id'].toString();
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
                if (facilities.length > 1)
                  DropdownButtonFormField<String>(
                    initialValue: facilityId,
                    decoration: const InputDecoration(labelText: 'المنشأة'),
                    items: [
                      for (final f in facilities)
                        DropdownMenuItem(
                          value: f['id'].toString(),
                          child: Text(f['nameAr']?.toString() ?? f['id'].toString()),
                        ),
                    ],
                    onChanged: (v) => setLocal(() => facilityId = v ?? facilityId),
                  ),
                if (facilities.length > 1) const SizedBox(height: 10),
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
        facilityId,
        title: title.text.trim(),
        kind: kind,
        severity: severity,
        details: details.text.trim().isEmpty ? null : details.text.trim(),
      );
      await refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _close(String facilityId, String eventId, String title, Future<void> Function() refresh) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إغلاق الحدث'),
        content: Text('إغلاق «$title»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إغلاق')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await widget.api.closeFacilityEvent(facilityId, eventId);
      await refresh();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return OpsLive(
      api: widget.api,
      title: 'الأحداث الطبية',
      eyebrow: 'MONITOR · SITREP',
      implyLeading: !widget.embedded,
      builder: (context, d, eyebrow, refresh) {
        final all = d.allEvents;
        final open = all.where(CommandData.isOpen).toList();
        final today = DateTime.now();
        final closedToday = all.where((e) {
          final t = CommandData.parseTime(e['closedAt']);
          return t != null && t.year == today.year && t.month == today.month && t.day == today.day;
        }).length;
        final has = d.hasEvents;
        final present = {for (final e in all) e['severity']?.toString() ?? 'عادي'};
        final facilities = d.facilities.where((f) => (f['id']?.toString() ?? '').isNotEmpty).toList();
        return OpsMonitorScreen(
          title: 'الأحداث الطبية',
          eyebrow: eyebrow,
          kindLabel: 'CASE',
          unit: 'حدثًا',
          searchHint: 'بحث بعنوان الحدث، الموقع، النوع...',
          openDetail: false,
          implyLeading: !widget.embedded,
          onRefresh: refresh,
          floating: FloatingActionButton.extended(
            onPressed: facilities.isEmpty ? null : () => _create(d, refresh),
            icon: const Icon(Icons.add_alert_outlined),
            label: const Text('حدث'),
          ),
          kpis: [
            OpsKpi('إجمالي الأحداث', has ? fmtInt(all.length) : kNoData, 'pulse', OpsColors.cyan),
            OpsKpi('عاجلة مفتوحة', has ? fmtInt(open.where((e) => CommandData.severityRank(e) == 0).length) : kNoData,
                'warn', OpsColors.red),
            OpsKpi('مفتوحة', has ? fmtInt(open.length) : kNoData, 'sync', OpsColors.amber, hint: has ? 'مباشر' : null,
                hintColor: OpsColors.cyan),
            OpsKpi('أُغلقت اليوم', has ? fmtInt(closedToday) : kNoData, 'check', OpsColors.green),
          ],
          filters: [
            for (final s in _sev)
              if (present.contains(s)) OpsFilterOption(s, severityColor(s)),
          ],
          groups: const [OpsFilterOption('مفتوح', OpsColors.amber), OpsFilterOption('مغلق', OpsColors.green)],
          items: [for (final e in all) _ev(d, e, refresh)],
        );
      },
    );
  }
}
