import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../data/command_data.dart';
import 'ops_chrome.dart';
import 'ops_live.dart';

/// المستودعات — read-only stock monitoring from `/api/facilities` + `/stores`.
class OpsWarehousesScreen extends StatelessWidget {
  const OpsWarehousesScreen({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return OpsLive(
      api: api,
      title: 'المستودعات',
      eyebrow: 'WAREHOUSES · INVENTORY',
      builder: (context, d, eyebrow, refresh) {
        if (d.boardWarehouses.isNotEmpty) {
          final board = d.boardWarehouses;
          final items = board.fold<int>(0, (s, r) => s + ((r['items'] as num?)?.round() ?? 0));
          final pending = board.fold<int>(0, (s, r) => s + ((r['pending'] as num?)?.round() ?? 0));
          final low = board.fold<int>(0, (s, r) {
            final rows = r['lowItems'];
            return s + (rows is List ? rows.length : 0);
          });
          return OpsMonitorScreen(
            title: 'المستودعات',
            eyebrow: eyebrow,
            kindLabel: 'WAREHOUSE',
            unit: 'مستودع',
            searchHint: 'بحث باسم المستودع، المحافظة...',
            onRefresh: refresh,
            kpis: [
              OpsKpi('إجمالي المستودعات', '${board.length}', 'box', OpsColors.cyan),
              OpsKpi('إجمالي الأصناف', fmtInt(items), 'kit', OpsColors.blue),
              OpsKpi('أصناف منخفضة', fmtInt(low), 'warn', OpsColors.amber),
              OpsKpi('طلبات توريد معلّقة', fmtInt(pending), 'sync', OpsColors.teal),
            ],
            items: [
              for (final r in board)
                OpsItem(
                  id: r['id']?.toString() ?? '',
                  title: r['name']?.toString() ?? '—',
                  subtitle: '${r['province'] ?? ''} · ${r['manager'] ?? ''}',
                  icon: 'box',
                  tone: OpsColors.amber,
                  group: r['province']?.toString(),
                  filterValue: r['status']?.toString(),
                  metricValue: r['fill']?.toString(),
                  metricLabel: '%',
                ),
            ],
          );
        }
        final list = d.ofType(CommandData.warehouse);
        final stocked = [for (final f in list) d.stores[f['id']]].whereType<List<JsonRow>>().toList();
        final items = stocked.isEmpty ? null : stocked.fold<int>(0, (s, r) => s + r.length);
        final low = stocked.isEmpty
            ? null
            : stocked.fold<int>(0, (s, r) => s + r.where((i) => i['low'] == true).length);
        return OpsMonitorScreen(
          title: 'المستودعات',
          eyebrow: eyebrow,
          kindLabel: 'WAREHOUSE',
          unit: 'مستودع',
          searchHint: 'بحث باسم المستودع، المحافظة...',
          onRefresh: refresh,
          kpis: [
            OpsKpi('إجمالي المستودعات', '${list.length}', 'box', OpsColors.cyan),
            OpsKpi('إجمالي الأصناف', opsCount(items), 'kit', OpsColors.blue),
            OpsKpi('أصناف منخفضة', opsCount(low), 'warn', OpsColors.amber),
            OpsKpi('طلبات توريد معلّقة', opsCount(sumOpen(d, list, d.needs)), 'sync', OpsColors.teal),
          ],
          filters: facilityStatusFilters,
          groups: provinceGroups(list),
          items: [
            for (final f in list)
              () {
                final rows = d.stores[f['id']];
                final lowRows = rows?.where((i) => i['low'] == true).toList();
                return facilityItem(
                  d,
                  f,
                  icon: 'box',
                  kindAr: f['typeAr']?.toString() ?? 'مستودع',
                  metricValue: rows == null ? '—' : '${rows.length}',
                  metricLabel: 'صنف',
                  extraPills: [
                    if (lowRows != null && lowRows.isNotEmpty) OpsPill('منخفض ${lowRows.length}', OpsColors.amber),
                  ],
                  extraInfo: [
                    ('الأصناف', rows == null ? kNoData : '${rows.length}'),
                    ('أصناف منخفضة', lowRows == null ? kNoData : '${lowRows.length}'),
                  ],
                  tags: [
                    for (final i in lowRows ?? const <JsonRow>[])
                      '${i['name']} — ${i['quantity']} / ${i['minQuantity']} ${i['unit'] ?? ''}'.trim(),
                  ],
                  tagsTitle: 'أصناف منخفضة',
                );
              }(),
          ],
        );
      },
    );
  }
}
