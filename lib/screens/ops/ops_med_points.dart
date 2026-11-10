import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../data/command_data.dart';
import 'ops_chrome.dart';
import 'ops_live.dart';

enum OpsPointKind { unit, center }

/// Shared read-only view for medical units (وحدات) and care centers (مراكز) from `/api/facilities`.
class OpsMedPointsScreen extends StatelessWidget {
  const OpsMedPointsScreen({super.key, required this.api, required this.kind});

  final ApiClient api;
  final OpsPointKind kind;

  @override
  Widget build(BuildContext context) {
    final isCenter = kind == OpsPointKind.center;
    final title = isCenter ? 'مراكز الرعاية الطبية' : 'الوحدات الطبية';
    return OpsLive(
      api: api,
      title: title,
      eyebrow: isCenter ? 'CENTERS · MEDICAL CENTERS · OPS' : 'UNITS · MEDICAL UNITS · OPS',
      builder: (context, d, eyebrow, refresh) {
        final kindName = isCenter ? 'مركز طبي' : 'وحدة طبية';
        final board = d.boardPoints.where((p) => p['type']?.toString() == kindName).toList();
        if (board.isNotEmpty) {
          final staff = board.fold<int>(0, (s, r) => s + ((r['staff'] as num?)?.round() ?? 0));
          final visits = board.fold<int>(0, (s, r) => s + ((r['visits'] as num?)?.round() ?? 0));
          final needy = board.where((r) => r['status'] == 'نقص موارد' || r['status'] == 'ضغط مرتفع').length;
          return OpsMonitorScreen(
            title: title,
            eyebrow: eyebrow,
            kindLabel: kindName,
            unit: isCenter ? 'مركز' : 'وحدة',
            searchHint: 'بحث بالاسم، المحافظة...',
            onRefresh: refresh,
            kpis: [
              OpsKpi(isCenter ? 'إجمالي المراكز' : 'إجمالي الوحدات', '${board.length}', isCenter ? 'medcenter' : 'kit',
                  isCenter ? OpsColors.blue : OpsColors.teal),
              OpsKpi('الكوادر الطبية', fmtInt(staff), 'user', OpsColors.green),
              OpsKpi('زيارات اليوم', fmtInt(visits), 'pulse', OpsColors.cyan),
              OpsKpi('تحتاج دعمًا', '$needy', 'warn', OpsColors.red),
            ],
            items: [
              for (final r in board)
                OpsItem(
                  id: r['id']?.toString() ?? '',
                  title: r['name']?.toString() ?? '—',
                  subtitle: '${r['site'] ?? ''} · ${r['province'] ?? ''}',
                  icon: isCenter ? 'medcenter' : 'kit',
                  tone: isCenter ? OpsColors.blue : OpsColors.teal,
                  group: r['province']?.toString(),
                  filterValue: r['status']?.toString(),
                  metricValue: r['visits']?.toString(),
                  metricLabel: 'زيارة',
                ),
            ],
          );
        }
        final list = d.ofType(isCenter ? CommandData.center : CommandData.unit);
        final needy = d.hasNeeds ? list.where((f) => d.openNeedsOf(f['id']?.toString() ?? '').isNotEmpty).length : null;
        return OpsMonitorScreen(
          title: title,
          eyebrow: eyebrow,
          kindLabel: isCenter ? 'مركز طبي' : 'وحدة طبية',
          unit: isCenter ? 'مركز' : 'وحدة',
          searchHint: 'بحث بالاسم، المحافظة...',
          onRefresh: refresh,
          kpis: [
            OpsKpi(isCenter ? 'إجمالي المراكز' : 'إجمالي الوحدات', '${list.length}', isCenter ? 'medcenter' : 'kit',
                isCenter ? OpsColors.blue : OpsColors.teal),
            const OpsKpi('الكوادر الطبية', kNoData, 'user', OpsColors.green),
            OpsKpi('أحداث مفتوحة', opsCount(sumOpen(d, list, d.events, onlyOpen: true)), 'pulse', OpsColors.cyan),
            OpsKpi('تحتاج دعمًا', opsCount(needy), 'warn', OpsColors.red),
          ],
          filters: facilityStatusFilters,
          groups: provinceGroups(list),
          items: [
            for (final f in list)
              facilityItem(
                d,
                f,
                icon: isCenter ? 'medcenter' : 'kit',
                kindAr: f['typeAr']?.toString() ?? (isCenter ? 'مركز طبي' : 'وحدة طبية'),
              ),
          ],
        );
      },
    );
  }
}
