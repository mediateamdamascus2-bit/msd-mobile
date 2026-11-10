import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../data/command_data.dart';
import 'ops_chrome.dart';
import 'ops_live.dart';

/// صحة السجون — read-only prison clinics from `/api/facilities`.
/// [onOpenHasia] deep-dives into the existing Hasia hub (navigation only).
class OpsPrisonsScreen extends StatelessWidget {
  const OpsPrisonsScreen({super.key, required this.api, this.onOpenHasia});

  final ApiClient api;
  final VoidCallback? onOpenHasia;

  @override
  Widget build(BuildContext context) {
    return OpsLive(
      api: api,
      title: 'صحة السجون',
      eyebrow: 'PRISONS · HEALTH',
      builder: (context, d, eyebrow, refresh) {
        if (d.boardPrisons.isNotEmpty) {
          final board = d.boardPrisons;
          final inmates = board.fold<int>(0, (s, r) => s + ((r['occupancy'] as num?)?.round() ?? 0));
          final staff = board.fold<int>(0, (s, r) => s + ((r['medStaff'] as num?)?.round() ?? 0));
          final cases = board.fold<int>(0, (s, r) => s + ((r['activeCases'] as num?)?.round() ?? 0));
          return OpsMonitorScreen(
            title: 'صحة السجون',
            eyebrow: eyebrow,
            kindLabel: 'PRISON',
            unit: 'سجن',
            searchHint: 'بحث باسم السجن، المحافظة...',
            onRefresh: refresh,
            kpis: [
              OpsKpi('إجمالي السجون', '${board.length}', 'prison', OpsColors.cyan),
              OpsKpi('النزلاء', fmtInt(inmates), 'user', OpsColors.blue),
              OpsKpi('حالات نشطة', fmtInt(cases), 'pulse', OpsColors.amber),
              OpsKpi('الكوادر الطبية', fmtInt(staff), 'kit', OpsColors.teal),
            ],
            groups: [
              for (final p in {for (final r in board) r['province']?.toString() ?? ''})
                if (p.isNotEmpty) OpsFilterOption(p, OpsColors.cyan),
            ],
            items: [
              for (final r in board)
                OpsItem(
                  id: r['id']?.toString() ?? '',
                  title: r['name']?.toString() ?? '—',
                  subtitle: '${r['type'] ?? ''} · ${r['province'] ?? ''}',
                  icon: 'prison',
                  tone: OpsColors.cyan,
                  group: r['province']?.toString(),
                  metricValue: r['occupancy']?.toString(),
                  metricLabel: 'نزيل',
                  info: [
                    ('الكوادر', '${r['medStaff'] ?? '—'}'),
                    ('الحالات', '${r['activeCases'] ?? '—'}'),
                    ('التقييم', '${r['health'] ?? '—'}'),
                  ],
                  actionLabel: r['id'] == 'PRN-00' && onOpenHasia != null ? 'فتح واجهة المنشأة (حسيا)' : null,
                  onAction: r['id'] == 'PRN-00' ? onOpenHasia : null,
                ),
            ],
          );
        }
        final list = d.ofType(CommandData.prison);
        return OpsMonitorScreen(
          title: 'صحة السجون',
          eyebrow: eyebrow,
          kindLabel: 'FACILITY',
          unit: 'سجن',
          searchHint: 'بحث باسم السجن، المحافظة...',
          onRefresh: refresh,
          kpis: [
            OpsKpi('إجمالي السجون', '${list.length}', 'prison', OpsColors.cyan),
            OpsKpi('نزلاء حسيا', opsCount(d.inmates), 'user', OpsColors.blue),
            OpsKpi('أحداث مفتوحة', opsCount(sumOpen(d, list, d.events, onlyOpen: true)), 'pulse', OpsColors.amber),
            const OpsKpi('الكوادر الطبية', kNoData, 'kit', OpsColors.teal),
          ],
          filters: facilityStatusFilters,
          groups: provinceGroups(list),
          items: [
            for (final f in list)
              () {
                final hasia = f['id'] == 'hasia';
                final inmates = hasia ? d.inmates : null;
                return facilityItem(
                  d,
                  f,
                  icon: 'prison',
                  kindAr: f['typeAr']?.toString() ?? 'عيادة سجن',
                  metricValue: inmates == null ? null : fmtInt(inmates),
                  metricLabel: inmates == null ? null : 'نزيل',
                  extraInfo: [('النزلاء', inmates == null ? kNoData : fmtInt(inmates))],
                  actionLabel: hasia && onOpenHasia != null ? 'فتح واجهة المنشأة (حسيا)' : null,
                  onAction: hasia ? onOpenHasia : null,
                );
              }(),
          ],
        );
      },
    );
  }
}
