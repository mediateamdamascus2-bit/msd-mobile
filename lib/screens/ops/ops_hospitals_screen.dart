import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../data/command_data.dart';
import 'ops_chrome.dart';
import 'ops_live.dart';

/// المشافي — read-only hospitals from `/api/facilities`.
/// [onOpenHarasta] deep-dives into the existing Harasta hospital hub (navigation only).
class OpsHospitalsScreen extends StatelessWidget {
  const OpsHospitalsScreen({super.key, required this.api, this.onOpenHarasta});

  final ApiClient api;
  final VoidCallback? onOpenHarasta;

  @override
  Widget build(BuildContext context) {
    return OpsLive(
      api: api,
      title: 'المشافي',
      eyebrow: 'HOSPITALS · REFERRALS',
      builder: (context, d, eyebrow, refresh) {
        if (d.boardHospitals.isNotEmpty) {
          final board = d.boardHospitals;
          final beds = board.fold<int>(0, (s, r) {
            final total = (r['beds'] as num?)?.round() ?? 0;
            final used = (r['bedsUsed'] as num?)?.round() ?? 0;
            return s + (total - used);
          });
          return OpsMonitorScreen(
            title: 'المشافي',
            eyebrow: eyebrow,
            kindLabel: 'HOSPITAL',
            unit: 'مشفى',
            searchHint: 'بحث باسم المشفى، المحافظة...',
            onRefresh: refresh,
            kpis: [
              OpsKpi('إجمالي المشافي', '${board.length}', 'hospital', OpsColors.cyan),
              OpsKpi('أسرّة متاحة', fmtInt(beds), 'check', OpsColors.green),
              OpsKpi('إحالات', fmtInt(board.fold<int>(0, (s, r) => s + ((r['referrals'] as num?)?.round() ?? 0))), 'pulse', OpsColors.blue),
              OpsKpi('أحداث مفتوحة', opsCount(sumOpen(d, d.ofType(CommandData.hospital), d.events, onlyOpen: true)), 'warn', OpsColors.amber),
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
                  icon: 'hospital',
                  tone: OpsColors.cyan,
                  group: r['province']?.toString(),
                  filterValue: r['status']?.toString(),
                  metricValue: '${((r['beds'] as num?)?.round() ?? 0) - ((r['bedsUsed'] as num?)?.round() ?? 0)}',
                  metricLabel: 'سرير',
                  actionLabel: r['id'] == 'HSP-00' && onOpenHarasta != null ? 'فتح واجهة المنشأة (حرستا)' : null,
                  onAction: r['id'] == 'HSP-00' ? onOpenHarasta : null,
                ),
            ],
          );
        }
        final list = d.ofType(CommandData.hospital);
        return OpsMonitorScreen(
          title: 'المشافي',
          eyebrow: eyebrow,
          kindLabel: 'HOSPITAL',
          unit: 'مشفى',
          searchHint: 'بحث باسم المشفى، المحافظة...',
          onRefresh: refresh,
          kpis: [
            OpsKpi('إجمالي المشافي', '${list.length}', 'hospital', OpsColors.cyan),
            OpsKpi('أحداث مفتوحة', opsCount(sumOpen(d, list, d.events, onlyOpen: true)), 'pulse', OpsColors.blue),
            OpsKpi('احتياجات مفتوحة', opsCount(sumOpen(d, list, d.needs)), 'warn', OpsColors.amber),
            const OpsKpi('أسرّة متاحة', kNoData, 'check', OpsColors.green),
          ],
          filters: facilityStatusFilters,
          groups: provinceGroups(list),
          items: [
            for (final f in list)
              facilityItem(
                d,
                f,
                icon: 'hospital',
                kindAr: f['typeAr']?.toString() ?? 'مشفى',
                extraInfo: const [('الأسرّة', kNoData)],
                actionLabel: f['id'] == 'harasta' && onOpenHarasta != null ? 'فتح واجهة مشفى حرستا' : null,
                onAction: f['id'] == 'harasta' ? onOpenHarasta : null,
              ),
          ],
        );
      },
    );
  }
}
