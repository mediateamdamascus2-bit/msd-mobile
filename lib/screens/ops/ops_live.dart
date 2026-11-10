import 'dart:async';

import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../data/command_data.dart';
import 'ops_chrome.dart';

typedef OpsLiveBuilder = Widget Function(
  BuildContext context,
  CommandData data,
  String eyebrow,
  Future<void> Function() refresh,
);

/// Loads [CommandData] for an ops screen (cache first, then network) and refreshes every 30s.
class OpsLive extends StatefulWidget {
  const OpsLive({
    super.key,
    required this.api,
    required this.title,
    required this.eyebrow,
    required this.builder,
  });

  final ApiClient api;
  final String title;
  final String eyebrow;
  final OpsLiveBuilder builder;

  @override
  State<OpsLive> createState() => _OpsLiveState();
}

class _OpsLiveState extends State<OpsLive> {
  CommandData? _data = CommandRepository.cached;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await CommandRepository.load(widget.api);
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d != null) {
      return widget.builder(context, d, '${widget.eyebrow} · تحديث ${hhmm(d.fetchedAt)}', _load);
    }
    return OpsScaffold(
      title: widget.title,
      eyebrow: widget.eyebrow,
      onRefresh: _load,
      children: [
        if (_error == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: OpsColors.cyan)),
          )
        else ...[
          OpsEmpty(_error!),
          Center(
            child: OutlinedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ),
        ],
      ],
    );
  }
}

/// Screen for sections that have no server endpoint yet.
class OpsNoDataScreen extends StatelessWidget {
  const OpsNoDataScreen({
    super.key,
    required this.title,
    required this.eyebrow,
    required this.kpis,
  });

  final String title;
  final String eyebrow;
  final List<(String, String, Color)> kpis;

  @override
  Widget build(BuildContext context) => OpsScaffold(
        title: title,
        eyebrow: eyebrow,
        children: [
          OpsKpiRow(kpis: [for (final k in kpis) OpsKpi(k.$1, kNoData, k.$2, k.$3)]),
          const SizedBox(height: 12),
          const OpsEmpty('لا توجد بيانات — لم يُربط هذا القسم بالخادم بعد'),
        ],
      );
}

String opsCount(int? n) => n == null ? kNoData : fmtInt(n);

String fmtInt(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('٬');
    b.write(s[i]);
  }
  return b.toString();
}

Color severityColor(Object? severity) {
  final s = severity?.toString() ?? '';
  if (s.contains('عاجل') || s.contains('حرج')) return OpsColors.red;
  if (s.contains('مرتفع')) return OpsColors.amber;
  if (s.contains('متوسط')) return OpsColors.blue;
  return OpsColors.green;
}

/// Facility card from live data: open events, open needs and recent activity.
OpsItem facilityItem(
  CommandData d,
  JsonRow f, {
  required String icon,
  required String kindAr,
  List<(String, String)> extraInfo = const [],
  String? metricValue,
  String? metricLabel,
  List<OpsPill> extraPills = const [],
  List<String> tags = const [],
  String tagsTitle = 'الخدمات المتوفرة',
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final id = f['id']?.toString() ?? '';
  final active = f['isActive'] != false;
  final ev = d.events[id];
  final needs = d.needs[id];
  final open = ev?.where(CommandData.isOpen).toList();
  final urgent = open?.where((e) => CommandData.severityRank(e) == 0).length;
  final status = !active
      ? 'متوقفة'
      : (urgent != null && urgent > 0)
          ? 'حدث عاجل'
          : (needs != null && needs.isNotEmpty)
              ? 'تحتاج دعمًا'
              : 'تعمل';
  final tone = switch (status) {
    'متوقفة' => OpsColors.red,
    'حدث عاجل' => OpsColors.red,
    'تحتاج دعمًا' => OpsColors.amber,
    _ => OpsColors.green,
  };
  final province = f['provinceAr']?.toString() ?? '';
  final recent = (ev ?? const <JsonRow>[]).take(4).toList();
  return OpsItem(
    id: id,
    title: f['nameAr']?.toString() ?? id,
    subtitle: '$kindAr · $province',
    icon: icon,
    tone: tone,
    filterValue: status,
    group: province,
    pills: [
      OpsPill(status, tone),
      OpsPill('أحداث مفتوحة ${open == null ? '—' : open.length}', OpsColors.blue),
      ...extraPills,
    ],
    metricValue: metricValue ?? (open == null ? '—' : '${open.length}'),
    metricLabel: metricLabel ?? 'حدث مفتوح',
    bannerTitle: '$kindAr — $province',
    bannerSub: needs == null ? 'الاحتياجات: $kNoData' : '${needs.length} احتياج مفتوح',
    info: [
      ('المحافظة', province.isEmpty ? '—' : province),
      ('الحالة', active ? 'فعّالة' : 'غير فعّالة'),
      ('الأحداث المفتوحة', open == null ? kNoData : '${open.length}'),
      ('الاحتياجات المفتوحة', needs == null ? kNoData : '${needs.length}'),
      ...extraInfo,
    ],
    tags: tags.isNotEmpty ? tags : [for (final n in needs ?? const <JsonRow>[]) n['title']?.toString() ?? ''],
    tagsTitle: tags.isNotEmpty ? tagsTitle : 'الاحتياجات المفتوحة',
    steps: [
      for (final e in recent)
        OpsStep(
          hhmmOrDash(CommandData.parseTime(e['createdAt'])),
          e['title']?.toString() ?? '',
          !CommandData.isOpen(e),
        ),
    ],
    stepsTitle: 'آخر الأحداث',
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

String hhmmOrDash(DateTime? t) => t == null ? '—' : hhmm(t);

const facilityStatusFilters = [
  OpsFilterOption('تعمل', OpsColors.green),
  OpsFilterOption('تحتاج دعمًا', OpsColors.amber),
  OpsFilterOption('حدث عاجل', OpsColors.red),
  OpsFilterOption('متوقفة', OpsColors.red),
];

List<OpsFilterOption> provinceGroups(List<JsonRow> facilities) {
  final seen = <String>{};
  return [
    for (final f in facilities)
      if (seen.add(f['provinceAr']?.toString() ?? '')) OpsFilterOption(f['provinceAr']?.toString() ?? ''),
  ];
}

int? sumOpen(CommandData d, List<JsonRow> facilities, Map<String, List<JsonRow>?> source, {bool onlyOpen = false}) {
  var any = false;
  var n = 0;
  for (final f in facilities) {
    final rows = source[f['id']];
    if (rows == null) continue;
    any = true;
    n += onlyOpen ? rows.where(CommandData.isOpen).length : rows.length;
  }
  return any ? n : null;
}
