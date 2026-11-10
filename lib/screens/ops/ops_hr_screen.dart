import 'package:flutter/material.dart';

import '../../api_client.dart';
import 'ops_chrome.dart';
import 'ops_live.dart';

/// القوى البشرية — staff rows from `/api/directorate/state`.
class OpsHrScreen extends StatelessWidget {
  const OpsHrScreen({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return OpsLive(
      api: api,
      title: 'القوى البشرية',
      eyebrow: 'HR · WORKFORCE',
      builder: (context, d, eyebrow, refresh) {
        final list = d.boardStaff;
        final med = list.where((e) => e['kind'] == 'طبي').length;
        final admin = list.where((e) => e['kind'] == 'إداري').length;
        return OpsMonitorScreen(
          title: 'القوى البشرية',
          eyebrow: eyebrow,
          kindLabel: 'STAFF',
          unit: 'موظف',
          searchHint: 'بحث بالاسم، القسم...',
          openDetail: false,
          onRefresh: refresh,
          kpis: [
            OpsKpi('إجمالي الكوادر', list.isEmpty ? kNoData : '${list.length}', 'user', OpsColors.cyan),
            OpsKpi('كادر طبي', list.isEmpty ? kNoData : '$med', 'kit', OpsColors.cyan),
            OpsKpi('كادر إداري', list.isEmpty ? kNoData : '$admin', 'folder', OpsColors.amber),
          ],
          items: [
            for (final e in list)
              OpsItem(
                id: e['id']?.toString() ?? '',
                title: e['name']?.toString() ?? '—',
                subtitle: '${e['role'] ?? ''} · ${e['dept'] ?? ''}',
                icon: 'user',
                tone: OpsColors.cyan,
                group: e['branch']?.toString(),
                filterValue: e['kind']?.toString(),
                info: [
                  ('الفرع', e['branch']?.toString() ?? '—'),
                  ('القسم', e['dept']?.toString() ?? '—'),
                  ('الهاتف', e['phone']?.toString() ?? '—'),
                ],
              ),
          ],
        );
      },
    );
  }
}
