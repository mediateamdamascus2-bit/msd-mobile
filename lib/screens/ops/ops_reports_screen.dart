import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../data/command_data.dart';
import 'ops_chrome.dart';
import 'ops_live.dart';

/// التقارير والإحصاءات — computed from the facility events returned by the server.
class OpsReportsScreen extends StatefulWidget {
  const OpsReportsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<OpsReportsScreen> createState() => _OpsReportsScreenState();
}

class _OpsReportsScreenState extends State<OpsReportsScreen> {
  static const _periods = {'7 أيام': 7, '30 يوم': 30, '90 يوم': 90};
  var _period = _periods.keys.first;

  static const _weekdays = ['اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];

  /// Buckets (label, total, closed) — daily for 7 days, weekly for 30, monthly-ish (30d) for 90.
  List<(String, int, int)> _trend(List<JsonRow> events, int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final step = days == 7 ? 1 : (days == 30 ? 7 : 30);
    final count = (days / step).ceil();
    final out = <(String, int, int)>[];
    for (var i = count - 1; i >= 0; i--) {
      final end = today.add(Duration(days: 1 - i * step));
      final start = end.subtract(Duration(days: step));
      var total = 0, closed = 0;
      for (final e in events) {
        final t = CommandData.parseTime(e['createdAt']);
        if (t == null || t.isBefore(start) || !t.isBefore(end)) continue;
        total++;
        if (!CommandData.isOpen(e)) closed++;
      }
      final label = step == 1 ? _weekdays[start.weekday - 1] : (step == 7 ? 'أ${count - i}' : 'ش${count - i}');
      out.add((label, total, closed));
    }
    return out;
  }

  double? _responseMinutes(Iterable<JsonRow> events) {
    var n = 0;
    var sum = 0.0;
    for (final e in events) {
      final a = CommandData.parseTime(e['createdAt']);
      final b = CommandData.parseTime(e['closedAt']);
      if (a == null || b == null) continue;
      n++;
      sum += b.difference(a).inSeconds / 60;
    }
    return n == 0 ? null : sum / n;
  }

  String _minutes(double? m) {
    if (m == null) return kNoData;
    if (m < 60) return '${m.round()} د';
    return '${(m / 60).toStringAsFixed(1)} س';
  }

  @override
  Widget build(BuildContext context) {
    return OpsLive(
      api: widget.api,
      title: 'التقارير والإحصاءات',
      eyebrow: 'REPORTS · ANALYTICS',
      builder: (context, d, eyebrow, refresh) {
        final days = _periods[_period]!;
        final since = DateTime.now().subtract(Duration(days: days));
        final events = d.allEvents.where((e) {
          final t = CommandData.parseTime(e['createdAt']);
          return t != null && t.isAfter(since);
        }).toList();
        final has = d.hasEvents;
        final closed = events.where((e) => !CommandData.isOpen(e)).length;
        final trend = _trend(events, days);
        final maxV = trend.fold<int>(1, (m, x) => x.$2 > m ? x.$2 : m);

        final bySev = <String, int>{};
        for (final e in events) {
          final s = e['severity']?.toString() ?? 'عادي';
          bySev[s] = (bySev[s] ?? 0) + 1;
        }
        final byProvince = <String, List<JsonRow>>{};
        for (final e in events) {
          final p = d.provinceOf(e['facilityId']?.toString());
          byProvince.putIfAbsent(p.isEmpty ? '—' : p, () => []).add(e);
        }
        final response = [
          for (final p in byProvince.entries)
            if (_responseMinutes(p.value) != null) (p.key, double.parse(_responseMinutes(p.value)!.toStringAsFixed(1)), OpsColors.blue),
        ];

        return OpsScaffold(
          title: 'التقارير والإحصاءات',
          eyebrow: eyebrow,
          onRefresh: refresh,
          children: [
            OpsFilterChips(
              options: [for (final p in _periods.keys) OpsFilterOption(p)],
              value: _period,
              onChanged: (v) => setState(() => _period = v),
            ),
            const SizedBox(height: 12),
            OpsKpiRow(
              kpis: [
                OpsKpi('أحداث الفترة', has ? fmtInt(events.length) : kNoData, 'pulse', OpsColors.cyan),
                OpsKpi('نسبة الإغلاق', has && events.isNotEmpty ? '${(closed * 100 / events.length).round()}٪' : kNoData,
                    'check', OpsColors.green),
                OpsKpi('متوسط زمن الإغلاق', _minutes(_responseMinutes(events)), 'clock', OpsColors.blue),
                const OpsKpi('إحالات للمشافي', kNoData, 'hospital', OpsColors.teal),
              ],
            ),
            const SizedBox(height: 12),
            OpsCard(
              tone: OpsColors.cyan,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OpsSectionTitle(no: '01', title: 'اتجاه الأحداث'),
                  if (events.isEmpty)
                    const OpsEmpty(kNoData)
                  else ...[
                    Row(
                      children: [
                        _legend('أحداث', OpsColors.cyan),
                        const SizedBox(width: 12),
                        _legend('مُغلقة', OpsColors.green),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 150,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final x in trend)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text('${x.$2}', style: opsText(12, w: FontWeight.w800, color: OpsColors.faint)),
                                    const SizedBox(height: 3),
                                    Expanded(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Expanded(child: _col(x.$2 / maxV, OpsColors.cyan)),
                                          const SizedBox(width: 2),
                                          Expanded(child: _col(x.$3 / maxV, OpsColors.green)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(x.$1, style: opsText(12, color: OpsColors.faint)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (bySev.isEmpty)
              const _EmptyCard(no: '02', title: 'الأحداث حسب الخطورة')
            else
              OpsDistributionCard(
                no: '02',
                title: 'الأحداث حسب الخطورة',
                tone: OpsColors.red,
                rows: [for (final s in bySev.entries) (s.key, s.value, severityColor(s.key))],
              ),
            const SizedBox(height: 12),
            if (response.isEmpty)
              const _EmptyCard(no: '03', title: 'متوسط زمن الإغلاق حسب المحافظة (دقيقة)')
            else
              OpsDistributionCard(
                no: '03',
                title: 'متوسط زمن الإغلاق حسب المحافظة (دقيقة)',
                tone: OpsColors.blue,
                rows: response,
              ),
            const SizedBox(height: 12),
            const _EmptyCard(no: '04', title: 'إحالات المشافي'),
          ],
        );
      },
    );
  }

  Widget _legend(String label, Color c) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 5),
          Text(label, style: opsText(12, w: FontWeight.w700, color: OpsColors.sub)),
        ],
      );

  Widget _col(double f, Color c) => FractionallySizedBox(
        heightFactor: f.clamp(0.03, 1.0),
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: BoxDecoration(
            color: c,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.no, required this.title});
  final String no;
  final String title;

  @override
  Widget build(BuildContext context) => OpsCard(
        tone: OpsColors.line,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [OpsSectionTitle(no: no, title: title), const OpsEmpty(kNoData)],
        ),
      );
}
