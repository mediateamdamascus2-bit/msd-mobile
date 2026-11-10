import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../data/command_data.dart';
import 'ops_chrome.dart';
import 'ops_live.dart';

/// الأسطول — SITREP monitoring only (ops from independent fleet desks).
class OpsFleetScreen extends StatelessWidget {
  const OpsFleetScreen({super.key, required this.api});

  final ApiClient api;

  static const _status = {
    'Ready': ('متاحة', OpsColors.green),
    'OnMission': ('في مهمة', OpsColors.blue),
    'Maintenance': ('صيانة', OpsColors.amber),
    'متاحة': ('متاحة', OpsColors.green),
    'في مهمة': ('في مهمة', OpsColors.blue),
    'صيانة': ('صيانة', OpsColors.amber),
    'خارج الخدمة': ('خارج الخدمة', OpsColors.red),
  };

  OpsItem _v(CommandData d, JsonRow v) {
    final s = _status[v['status']] ?? (v['statusAr']?.toString() ?? '—', OpsColors.faint);
    final label = v['statusAr']?.toString() ?? s.$1;
    final type = v['vehicleType']?.toString() ?? 'مركبة';
    final fid = v['facilityId']?.toString();
    final odo = v['odometerKm'];
    final odoText = odo is num ? '${fmtInt(odo.round())} كم' : kNoData;
    final mission = v['missionNote']?.toString();
    return OpsItem(
      id: v['code']?.toString() ?? '',
      title: v['code']?.toString() ?? '—',
      subtitle: '${v['plate'] ?? ''} · $type · ${d.nameOf(fid).isEmpty ? (v['province'] ?? '') : d.nameOf(fid)}',
      icon: type.contains('إسعاف') ? 'ambulance' : 'truck',
      tone: s.$2,
      filterValue: s.$1,
      group: type,
      pills: [OpsPill(label, s.$2)],
      metricValue: odo is num ? fmtInt(odo.round()) : '—',
      metricLabel: 'كم',
      bannerTitle: (mission == null || mission.isEmpty) ? 'لا توجد مهمة حالية' : mission,
      bannerSub: '${d.nameOf(fid)} — ${d.provinceOf(fid)}',
      info: [
        ('السائق', v['driverName']?.toString() ?? '—'),
        ('النوع', type),
        ('العدّاد', odoText),
        ('آخر صيانة', v['lastServiceDate']?.toString() ?? '—'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return OpsLive(
      api: api,
      title: 'الأسطول',
      eyebrow: 'MONITOR · FLEET',
      builder: (context, d, eyebrow, refresh) {
        final all = d.allVehicles;
        final has = d.hasFleet;
        int count(List<String> keys) => all.where((v) => keys.contains(v['status'])).length;
        final types = <String>{for (final v in all) v['vehicleType']?.toString() ?? 'مركبة'};
        return OpsMonitorScreen(
          title: 'الأسطول',
          eyebrow: eyebrow,
          kindLabel: 'VEHICLE',
          unit: 'مركبة',
          searchHint: 'بحث برمز المركبة، النوع، المنشأة...',
          openDetail: false,
          onRefresh: refresh,
          kpis: [
            OpsKpi('إجمالي المركبات', has ? '${all.length}' : kNoData, 'truck', OpsColors.cyan),
            OpsKpi('متاحة الآن', has ? '${count(['Ready', 'متاحة'])}' : kNoData, 'check', OpsColors.green),
            OpsKpi('في مهمة', has ? '${count(['OnMission', 'في مهمة'])}' : kNoData, 'ambulance', OpsColors.blue),
            OpsKpi('صيانة', has ? '${count(['Maintenance', 'صيانة'])}' : kNoData, 'gear', OpsColors.amber),
          ],
          filters: [
            for (final e in {for (final row in _status.values) row.$1: row.$2}.entries) OpsFilterOption(e.key, e.value),
          ],
          groups: [for (final t in types) OpsFilterOption(t)],
          items: [for (final v in all) _v(d, v)],
        );
      },
    );
  }
}
