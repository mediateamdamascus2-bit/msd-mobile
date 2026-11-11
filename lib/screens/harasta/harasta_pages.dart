import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../data/harasta_catalog.dart';
import '../../theme/app_theme.dart';
import '../../ui/msd_notify.dart';
import '../../ui/msd_text_field.dart';
import '../booking_screen.dart';
import '../clinic_live_screen.dart';
import '../clinic_screen.dart';
import '../dept_screen.dart';
import '../reception_screen.dart';

import 'harasta_facility_chrome.dart';

export 'harasta_followup_boards.dart';
export 'harasta_facility_chrome.dart';

class HarastaOverviewPage extends StatelessWidget {
  const HarastaOverviewPage({
    super.key,
    required this.ops,
    required this.loading,
    required this.onOpenStation,
  });

  final List<Map<String, dynamic>> ops;
  final bool loading;
  final void Function(String key) onOpenStation;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text('غرفة العمليات اليومية', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'نفس أقسام واجهة الويب — بالعربية على الجوال',
          style: TextStyle(color: MsdColors.sub, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in [
              ('محطة الاستقبال', 'reception_station'),
              ('حجز الإدارات', 'booking'),
              ('لوحة العيادات', 'clinic_live'),
              ('شاشة النداء', 'display'),
            ])
              ActionChip(
                onPressed: () => onOpenStation(a.$2),
                label: Text(a.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                backgroundColor: Colors.white,
                side: const BorderSide(color: MsdColors.line),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('مؤشرات ثابتة', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in HarastaCatalog.kpis)
              _MiniStat(label: k.$1, value: k.$2),
          ],
        ),
        const SizedBox(height: 16),
        Text('تشغيل اليوم', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (ops.isEmpty)
          const Text('لا تتوفر مؤشرات لحظية حالياً', style: TextStyle(color: MsdColors.sub))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in ops)
                _MiniStat(
                  label: '${o['key'] ?? ''}',
                  value: '${o['value'] ?? 0}',
                  detail: '${o['detail'] ?? ''}',
                ),
            ],
          ),
      ],
    );
  }
}

class HarastaStructurePage extends StatefulWidget {
  const HarastaStructurePage({super.key});

  @override
  State<HarastaStructurePage> createState() => _HarastaStructurePageState();
}

class _HarastaStructurePageState extends State<HarastaStructurePage> {
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final shown = HarastaCatalog.domains.where((d) => _filter == null || d.$1 == _filter);
    return HpPage(
      children: [
        const HpIntro(
          eyebrow: 'STRUCTURE',
          lead: 'مجالات الخدمة ووحداتها مع حالة التوافر.',
        ),
        HpChips(
          value: _filter,
          options: [
            (null, 'الكل'),
            for (final d in HarastaCatalog.domains) (d.$1, d.$1),
          ],
          onChanged: (v) => setState(() => _filter = v),
        ),
        for (final d in shown)
          HpPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HpSectionHead(title: d.$1, subtitle: '${d.$2.length} وحدة'),
                for (final row in d.$2) HpUnitRow(title: row.$1, subtitle: row.$2),
              ],
            ),
          ),
      ],
    );
  }
}

class HarastaFloorsPage extends StatelessWidget {
  const HarastaFloorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return HpPage(
      children: [
        const HpIntro(
          eyebrow: 'FLOORS',
          lead: 'خريطة مبسّطة لتوزّع الأجنحة والخدمات على طوابق المشفى.',
        ),
        for (final f in HarastaCatalog.floors)
          HpFloorCard(floor: f.$1, side: f.$2, unit: f.$3, note: f.$4),
      ],
    );
  }
}

class HarastaStaffPage extends StatelessWidget {
  const HarastaStaffPage({super.key});

  @override
  Widget build(BuildContext context) {
    final total = HarastaCatalog.staff.fold<int>(0, (a, b) => a + b.$2);
    final max = HarastaCatalog.staff.fold<int>(0, (a, b) => b.$2 > a ? b.$2 : a);
    return HpPage(
      children: [
        const HpIntro(
          eyebrow: 'STAFF',
          lead: 'توزيع الكادر المذكور في هيكلية المشفى.',
        ),
        HpPanel(
          child: Row(
            children: [
              Text('إجمالي مذكور', style: TextStyle(fontWeight: FontWeight.w700, color: Hp.sub)),
              const Spacer(),
              Text('$total', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Hp.data)),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: [
            for (final s in HarastaCatalog.staff)
              HpStaffCard(
                label: s.$1,
                value: s.$2,
                bar: max == 0 ? 0 : s.$2 / max,
              ),
          ],
        ),
      ],
    );
  }
}

class HarastaVisionPage extends StatelessWidget {
  const HarastaVisionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return HpPage(
      children: [
        const HpIntro(
          eyebrow: 'VISION 2030',
          lead: 'مسار التحول والتوسع والاعتماد لمشفى حرستا على مدى السنوات القادمة.',
        ),
        for (final v in HarastaCatalog.vision)
          HpPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${v.$1} · ${v.$2}',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: Hp.data),
                ),
                const SizedBox(height: 10),
                for (final line in v.$3)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: Hp.data, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(line, style: TextStyle(fontSize: 13.5, height: 1.45, color: Hp.ink, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class HarastaFilesPage extends StatefulWidget {
  const HarastaFilesPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<HarastaFilesPage> createState() => _HarastaFilesPageState();
}

class _HarastaFilesPageState extends State<HarastaFilesPage> {
  final _q = TextEditingController();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _kind = 'الكل';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await widget.api.patientFiles(
        HarastaCatalog.facilityId,
        q: _q.text,
        kind: _kind,
      );
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (mounted) await MsdNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _data?['stats'] as Map<String, dynamic>?;
    final items = (_data?['items'] as List?) ?? const [];
    final total = int.tryParse('${stats?['total'] ?? 0}') ?? 0;
    final emergency = int.tryParse('${stats?['emergency'] ?? 0}') ?? 0;
    final lead = total == 0
        ? 'لا ملفات ظاهرة بعد — ستظهر الأضابير هنا فور فتحها من المحطات.'
        : emergency > 0
            ? '$total إضبارة · منها $emergency إسعافي تحتاج متابعة أوضح.'
            : '$total إضبارة مسجّلة — صفِّ بالنوع أو ابحث بالاسم والرقم.';

    return HpPage(
      onRefresh: _load,
      children: [
        HpIntro(eyebrow: 'PATIENT FILES', lead: lead),
        HpPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: MsdTextField(
                      controller: _q,
                      labelText: 'بحث بالاسم / الرقم / الرقم الوطني',
                      textInputAction: TextInputAction.search,
                      prefixIcon: const Icon(Icons.search_rounded, color: Hp.faint),
                      onSubmitted: (_) => _load(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Hp.drawerMid,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _load,
                      borderRadius: BorderRadius.circular(14),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.search_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              HpChips(
                value: _kind,
                options: const [
                  ('الكل', 'الكل'),
                  ('إسعافي', 'إسعافي'),
                  ('عامة', 'عامة'),
                  ('خاصة', 'خاصة'),
                ],
                onChanged: (v) {
                  setState(() => _kind = v ?? 'الكل');
                  _load();
                },
              ),
            ],
          ),
        ),
        if (stats != null)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              HpOpsCard(label: 'إجمالي الملفات', value: '${stats['total'] ?? 0}', detail: 'إضبارة', tone: 'calm'),
              HpOpsCard(label: 'حجز مسبق', value: '${stats['prebooked'] ?? 0}', detail: 'دخول'),
              HpOpsCard(
                label: 'إسعافي',
                value: '${stats['emergency'] ?? 0}',
                detail: 'طارئ',
                tone: emergency > 0 ? 'emergency' : null,
              ),
              HpOpsCard(
                label: 'حالات خاصة',
                value: '${stats['special'] ?? 0}',
                detail: 'فئة',
                tone: (int.tryParse('${stats['special'] ?? 0}') ?? 0) > 0 ? 'special' : null,
              ),
            ],
          ),
        if (_loading)
          const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(color: Hp.data)))
        else if (items.isEmpty)
          HpPanel(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Column(
                children: [
                  Icon(Icons.folder_off_outlined, size: 36, color: Hp.faint.withValues(alpha: 0.85)),
                  const SizedBox(height: 10),
                  Text('لا نتائج مطابقة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Hp.ink)),
                  const SizedBox(height: 4),
                  Text(
                    'عدِّل البحث أو الفلتر، أو اسحب للتحديث.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: Hp.sub, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Text(
            'السجل · ${items.length}',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Hp.faint),
          ),
          for (final raw in items)
            HpFileCard(
              caseNumber: '${(raw as Map)['caseNumber'] ?? ''}',
              patientName: '${raw['patientName'] ?? ''}',
              entryType: '${raw['entryType'] ?? ''}',
              status: '${raw['statusAr'] ?? raw['status'] ?? ''}',
              location: [
                '${raw['currentClinic'] ?? raw['bookedClinic'] ?? ''}'.trim(),
                '${raw['currentDepartment'] ?? ''}'.trim(),
              ].where((s) => s.isNotEmpty).join(' · '),
            ),
        ],
      ],
    );
  }
}

class HarastaFleetPage extends StatefulWidget {
  const HarastaFleetPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<HarastaFleetPage> createState() => _HarastaFleetPageState();
}

class _HarastaFleetPageState extends State<HarastaFleetPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.fleet(HarastaCatalog.facilityId);
      if (!mounted) return;
      setState(() => _rows = list.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      if (mounted) await MsdNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(Map<String, dynamic> v, String status) async {
    String? note;
    if (status == 'OnMission') {
      final c = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('إرسال في مهمة'),
          content: MsdTextField(controller: c, labelText: 'وصف المهمة'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
          ],
        ),
      );
      if (ok != true) return;
      note = c.text.trim();
    }
    try {
      await widget.api.setFleetStatus(
        HarastaCatalog.facilityId,
        v['id'].toString(),
        status: status,
        missionNote: note,
      );
      await _load();
    } catch (e) {
      if (mounted) await MsdNotify.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return HpPage(
      onRefresh: _load,
      children: [
        const HpIntro(
          eyebrow: 'FLEET',
          lead: 'متابعة جاهزية المركبات والمهام الجارية والصيانة.',
        ),
        if (_loading)
          const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(color: Hp.data)))
        else if (_rows.isEmpty)
          const HpPanel(child: Text('لا توجد مركبات', style: TextStyle(color: Hp.sub)))
        else
          for (final v in _rows)
            HpListTile(
              title: '${v['vehicleType'] ?? ''}',
              subtitle:
                  '${v['code'] ?? ''} · لوحة ${v['plate'] ?? ''}\n'
                  'السائق ${v['driverName'] ?? '—'} · ${v['statusAr'] ?? v['status'] ?? ''}'
                  '${v['missionNote'] != null ? '\nمهمة: ${v['missionNote']}' : ''}',
              trailing: PopupMenuButton<String>(
                onSelected: (s) => _setStatus(v, s),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'Ready', child: Text('جاهزة')),
                  PopupMenuItem(value: 'OnMission', child: Text('في مهمة')),
                  PopupMenuItem(value: 'Maintenance', child: Text('صيانة')),
                ],
              ),
            ),
      ],
    );
  }
}

class HarastaStoresPage extends StatefulWidget {
  const HarastaStoresPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<HarastaStoresPage> createState() => _HarastaStoresPageState();
}

class _HarastaStoresPageState extends State<HarastaStoresPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.stores(HarastaCatalog.facilityId);
      if (!mounted) return;
      setState(() => _rows = list.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      if (mounted) await MsdNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HpPage(
      onRefresh: _load,
      children: [
        const HpIntro(
          eyebrow: 'STORES',
          lead: 'أصناف المخزون والكميات المنخفضة وتواريخ الانتهاء.',
        ),
        if (_loading)
          const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(color: Hp.data)))
        else if (_rows.isEmpty)
          const HpPanel(child: Text('لا توجد أصناف', style: TextStyle(color: Hp.sub)))
        else
          for (final i in _rows)
            HpListTile(
              accent: i['low'] == true,
              title: '${i['name'] ?? ''}',
              subtitle:
                  '${i['storeName'] ?? ''} · ${i['quantity'] ?? 0} ${i['unit'] ?? ''}'
                  '${i['expiryDate'] != null ? ' · ينتهي ${i['expiryDate']}' : ''}',
              trailing: i['low'] == true
                  ? Text('منخفض', style: TextStyle(color: Hp.amber, fontWeight: FontWeight.w800, fontSize: 12))
                  : null,
            ),
      ],
    );
  }
}

class HarastaAssetsPage extends StatefulWidget {
  const HarastaAssetsPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<HarastaAssetsPage> createState() => _HarastaAssetsPageState();
}

class _HarastaAssetsPageState extends State<HarastaAssetsPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.assets(HarastaCatalog.facilityId);
      if (!mounted) return;
      setState(() => _rows = list.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      if (mounted) await MsdNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _units(String status) {
    var n = 0;
    for (final a in _rows) {
      final s = '${a['status'] ?? ''}'.toLowerCase();
      final ar = '${a['statusAr'] ?? ''}';
      final match = switch (status) {
        'working' => s == 'working' || ar == 'يعمل',
        'maint' => s == 'needsmaintenance' || ar.contains('صيانة'),
        'out' => s == 'outofservice' || ar == 'معطل' || ar == 'معطّل',
        _ => false,
      };
      if (match) n += int.tryParse('${a['count']}') ?? 1;
    }
    return n;
  }

  int get _total => _rows.fold<int>(0, (s, a) => s + (int.tryParse('${a['count']}') ?? 1));

  @override
  Widget build(BuildContext context) {
    return HpPage(
      onRefresh: _load,
      children: [
        const HpIntro(
          eyebrow: 'ASSETS',
          lead: 'متابعة الحالة والأعداد فقط — الإضافة وتغيير الحالة من مكتب الأصول المستقل (مستخدم assets-office).',
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            HpOpsCard(label: 'إجمالي الأجهزة', value: '$_total', detail: 'وحدة'),
            HpOpsCard(label: 'تعمل', value: '${_units('working')}', detail: 'جاهز'),
            HpOpsCard(label: 'تحتاج صيانة', value: '${_units('maint')}', detail: 'متابعة'),
            HpOpsCard(label: 'معطّلة', value: '${_units('out')}', detail: 'إيقاف'),
          ],
        ),
        HpPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HpSectionHead(title: 'قائمة الأصول', subtitle: 'مشاهدة فقط'),
              if (_loading)
                const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: Hp.data)))
              else if (_rows.isEmpty)
                Text('لا توجد أصول مسجّلة', style: TextStyle(color: Hp.sub))
              else
                for (final a in _rows)
                  HpUnitRow(
                    title: '${a['name'] ?? ''}',
                    subtitle: '${a['code'] ?? ''} · ${a['department'] ?? ''} · عدد ${a['count'] ?? 1}',
                    badge: '${a['statusAr'] ?? a['status'] ?? ''}',
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Independent Assets Office — add devices and cycle status.
class HarastaAssetsOfficePage extends StatefulWidget {
  const HarastaAssetsOfficePage({super.key, required this.api, this.onLogout});
  final ApiClient api;
  final Future<void> Function()? onLogout;

  @override
  State<HarastaAssetsOfficePage> createState() => _HarastaAssetsOfficePageState();
}

class _HarastaAssetsOfficePageState extends State<HarastaAssetsOfficePage> {
  static const _depts = [
    'الأشعة', 'الإسعاف', 'غسيل الكلى', 'القلبية', 'الأطفال',
    'العناية', 'العمليات', 'العلاج الفيزيائي', 'الخدمات',
  ];

  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _saving = false;
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _note = TextEditingController();
  final _count = TextEditingController(text: '1');
  String _dept = _depts.first;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _note.dispose();
    _count.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.assets(HarastaCatalog.facilityId);
      if (!mounted) return;
      setState(() => _rows = list.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      if (mounted) await MsdNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cycle(Map<String, dynamic> a) async {
    final id = '${a['id'] ?? ''}';
    if (id.isEmpty) return;
    try {
      await widget.api.cycleAssetStatus(HarastaCatalog.facilityId, id);
      await _load();
    } catch (e) {
      if (mounted) await MsdNotify.error(context, e.toString());
    }
  }

  Future<void> _add() async {
    setState(() => _saving = true);
    try {
      await widget.api.addAsset(
        HarastaCatalog.facilityId,
        code: _code.text.trim(),
        name: _name.text.trim(),
        department: _dept,
        count: int.tryParse(_count.text.trim()) ?? 1,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      _code.clear();
      _name.clear();
      _note.clear();
      _count.text = '1';
      if (mounted) await MsdNotify.success(context, 'تم إضافة الأصل.');
      await _load();
    } catch (e) {
      if (mounted) await MsdNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Hp.page,
      appBar: AppBar(
        backgroundColor: Hp.appBar,
        foregroundColor: MsdTokens.onDeep,
        title: Text('مكتب الأصول', style: TextStyle(fontWeight: FontWeight.w800, color: MsdTokens.onDeep)),
        actions: [
          if (widget.onLogout != null)
            IconButton(
              tooltip: 'خروج',
              onPressed: () => widget.onLogout!(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: HpPage(
        onRefresh: _load,
        children: [
          const HpIntro(
            eyebrow: 'ASSETS OFFICE',
            lead: 'إضافة التجهيزات وتغيير حالتها تحت إشراف مكتب الأصول. واجهة مستقلة عن لوحة المشفى.',
          ),
          HpPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HpSectionHead(title: 'سجل الأصول', subtitle: 'اضغط الحالة لتدويرها'),
                if (_loading)
                  const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: Hp.data)))
                else if (_rows.isEmpty)
                  Text('لا توجد أصول — أضف جهازاً أدناه', style: TextStyle(color: Hp.sub))
                else
                  for (final a in _rows)
                    HpListTile(
                      title: '${a['name'] ?? ''}',
                      subtitle: '${a['code'] ?? ''} · ${a['department'] ?? ''} · عدد ${a['count'] ?? 1}',
                      trailing: TextButton(
                        onPressed: () => _cycle(a),
                        child: Text(
                          '${a['statusAr'] ?? a['status'] ?? ''}',
                          style: TextStyle(fontWeight: FontWeight.w800, color: Hp.data),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          HpPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HpSectionHead(title: 'إضافة أصل / جهاز'),
                MsdTextField(controller: _code, labelText: 'الرمز'),
                const SizedBox(height: 8),
                MsdTextField(controller: _name, labelText: 'الاسم'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _dept,
                  decoration: const InputDecoration(labelText: 'القسم', border: OutlineInputBorder()),
                  items: [for (final d in _depts) DropdownMenuItem(value: d, child: Text(d))],
                  onChanged: (v) => setState(() => _dept = v ?? _depts.first),
                ),
                const SizedBox(height: 8),
                MsdTextField(controller: _count, labelText: 'العدد', keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                MsdTextField(controller: _note, labelText: 'ملاحظة (اختياري)'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _add,
                  style: FilledButton.styleFrom(backgroundColor: Hp.data, foregroundColor: Colors.white),
                  child: Text(_saving ? 'جاري الحفظ...' : 'حفظ الأصل', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HarastaCallDisplayPage extends StatefulWidget {
  const HarastaCallDisplayPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<HarastaCallDisplayPage> createState() => _HarastaCallDisplayPageState();
}

class _HarastaCallDisplayPageState extends State<HarastaCallDisplayPage> {
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final live = await widget.api.clinicLive(HarastaCatalog.facilityId);
      if (!mounted) return;
      setState(() => _rows = live.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text('شاشة النداء', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text('عرض حالة العيادات للنداء (نسخة جوال من لوحة العرض)', style: TextStyle(color: MsdColors.sub)),
          const SizedBox(height: 12),
          for (final r in _rows)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MsdColors.deepMid,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${r['clinic'] ?? ''}',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                  Text(
                    '${r['waiting'] ?? 0}',
                    style: TextStyle(color: MsdColors.sky, fontWeight: FontWeight.w800, fontSize: 28),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Helpers to open operational stations from Harasta shell.
void openHarastaStation(BuildContext context, ApiClient api, String key, {Future<void> Function()? onLogout}) {
  Widget page;
  switch (key) {
    case 'reception_station':
      page = ReceptionScreen(api: api, facilityId: HarastaCatalog.facilityId, onLogout: onLogout);
      break;
    case 'booking':
      page = BookingScreen(api: api, onLogout: onLogout);
      break;
    case 'clinic_live':
      page = ClinicLiveScreen(api: api, facilityId: HarastaCatalog.facilityId, onLogout: onLogout);
      break;
    case 'display':
      page = HarastaCallDisplayPage(api: api);
      break;
    case 'assets_office':
      page = HarastaAssetsOfficePage(api: api, onLogout: onLogout);
      break;
    default:
      return;
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

void openHarastaClinic(BuildContext context, ApiClient api, String clinic, {Future<void> Function()? onLogout}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ClinicScreen(api: api, facilityId: HarastaCatalog.facilityId, clinic: clinic, onLogout: onLogout),
  ));
}

void openHarastaDept(BuildContext context, ApiClient api, String dept, {Future<void> Function()? onLogout}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => DeptScreen(api: api, facilityId: HarastaCatalog.facilityId, department: dept, onLogout: onLogout),
  ));
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.detail});
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MsdColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: MsdColors.sub, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: MsdColors.teal)),
          if (detail != null && detail!.isNotEmpty)
            Text(detail!, style: TextStyle(fontSize: 12, color: MsdColors.faint)),
        ],
      ),
    );
  }
}
