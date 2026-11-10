import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../data/command_data.dart';
import 'ops_chrome.dart';
import 'ops_live.dart';

/// الأحداث الطبية — SITREP monitoring only (no case desk / actions).
class OpsEventsScreen extends StatelessWidget {
  const OpsEventsScreen({super.key, required this.api});

  final ApiClient api;

  static const _sev = ['عاجل', 'مرتفع', 'متوسط', 'منخفض', 'عادي'];

  OpsItem _ev(CommandData d, JsonRow e) {
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return OpsLive(
      api: api,
      title: 'الأحداث الطبية',
      eyebrow: 'MONITOR · SITREP',
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
        return OpsMonitorScreen(
          title: 'الأحداث الطبية',
          eyebrow: eyebrow,
          kindLabel: 'CASE',
          unit: 'حدثًا',
          searchHint: 'بحث بعنوان الحدث، الموقع، النوع...',
          openDetail: false,
          onRefresh: refresh,
          kpis: [
            OpsKpi('إجمالي الأحداث', has ? fmtInt(all.length) : kNoData, 'pulse', OpsColors.cyan),
            OpsKpi('عاجلة مفتوحة', has ? '${open.where((e) => CommandData.severityRank(e) == 0).length}' : kNoData,
                'warn', OpsColors.red),
            OpsKpi('مفتوحة', has ? '${open.length}' : kNoData, 'sync', OpsColors.amber, hint: has ? 'مباشر' : null,
                hintColor: OpsColors.cyan),
            OpsKpi('أُغلقت اليوم', has ? '$closedToday' : kNoData, 'check', OpsColors.green),
          ],
          filters: [
            for (final s in _sev)
              if (present.contains(s)) OpsFilterOption(s, severityColor(s)),
          ],
          groups: const [OpsFilterOption('مفتوح', OpsColors.amber), OpsFilterOption('مغلق', OpsColors.green)],
          items: [for (final e in all) _ev(d, e)],
        );
      },
    );
  }
}
