import 'package:flutter/material.dart';

import '../../api_client.dart';
import 'ops_chrome.dart';
import 'ops_live.dart';

/// التدريب والتطوير — courses from `/api/directorate/state`.
class OpsTrainingScreen extends StatelessWidget {
  const OpsTrainingScreen({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return OpsLive(
      api: api,
      title: 'التدريب والتطوير',
      eyebrow: 'TRAINING · DEVELOPMENT',
      builder: (context, d, eyebrow, refresh) {
        final list = d.boardCourses;
        final active = list.where((e) => e['status'] == 'نشطة').length;
        final enrolled = list.fold<int>(0, (s, e) => s + ((e['enrolled'] as num?)?.round() ?? 0));
        final certified = list.fold<int>(0, (s, e) => s + ((e['certified'] as num?)?.round() ?? 0));
        return OpsMonitorScreen(
          title: 'التدريب والتطوير',
          eyebrow: eyebrow,
          kindLabel: 'COURSE',
          unit: 'برنامج',
          searchHint: 'بحث بعنوان الدورة...',
          openDetail: false,
          onRefresh: refresh,
          kpis: [
            OpsKpi('إجمالي البرامج', list.isEmpty ? kNoData : '${list.length}', 'cap', OpsColors.cyan),
            OpsKpi('الدورات النشطة', list.isEmpty ? kNoData : '$active', 'pulse', OpsColors.blue),
            OpsKpi('إجمالي المتدربين', list.isEmpty ? kNoData : '$enrolled', 'user', OpsColors.teal),
            OpsKpi('الشهادات الممنوحة', list.isEmpty ? kNoData : '$certified', 'check', OpsColors.green),
          ],
          items: [
            for (final e in list)
              OpsItem(
                id: e['id']?.toString() ?? '',
                title: e['title']?.toString() ?? '—',
                subtitle: '${e['category'] ?? ''} · ${e['trainer'] ?? ''}',
                icon: 'cap',
                tone: OpsColors.cyan,
                group: e['category']?.toString(),
                filterValue: e['status']?.toString(),
                pills: [OpsPill(e['status']?.toString() ?? '—', OpsColors.cyan)],
                metricValue: e['enrolled']?.toString(),
                metricLabel: 'متدرب',
              ),
          ],
        );
      },
    );
  }
}
