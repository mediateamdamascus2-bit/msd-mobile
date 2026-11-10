import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api_client.dart';
import '../data/command_data.dart';
import '../services/new_item_watcher.dart';
import '../services/notification_service.dart';
import '../theme/cmd_icon.dart';
import 'facility_screen.dart';
import 'harasta_hub_screen.dart';
import 'hasia_hub_screen.dart';
import 'ops/ops_centers_screen.dart';
import 'ops/ops_events_screen.dart';
import 'ops/ops_fleet_screen.dart';
import 'ops/ops_training_screen.dart';
import 'ops/ops_units_screen.dart';
import 'ops/ops_warehouses_screen.dart';

/// Mobile central command — mirrors web لوحة القيادة المركزية (no facility board / stations strip).
class NativeHomeScreen extends StatefulWidget {
  const NativeHomeScreen({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
    this.onOpenMenu,
  });

  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;
  final VoidCallback? onOpenMenu;

  @override
  State<NativeHomeScreen> createState() => _NativeHomeScreenState();
}

class _NativeHomeScreenState extends State<NativeHomeScreen> {
  static const _ink = Color(0xFF143139);
  static const _sub = Color(0xFF4C6B71);
  static const _faint = Color(0xFF86A1A1);
  static const _line = Color(0x1F143139);
  static const _page = Color(0xFFEAF6FB);
  static const _cyan = Color(0xFF0F8F86);
  static const _teal = Color(0xFF136B6B);
  static const _blue = Color(0xFF3A7BA6);
  static const _green = Color(0xFF2E9E6C);
  static const _amber = Color(0xFFC0913A);
  static const _red = Color(0xFFCF5A52);
  static const _noData = 'لا توجد بيانات';

  CommandData? _data = CommandRepository.cached;
  String? _error;
  Timer? _timer;
  final _newEvents = NewItemWatcher();

  @override
  void initState() {
    super.initState();
    final d = _data;
    if (d != null) _newEvents.absorb(d.allEvents);
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
      final fresh = _newEvents.diff(d.allEvents);
      setState(() {
        _data = d;
        _error = null;
      });
      if (fresh.isNotEmpty) {
        unawaited(NotificationService.instance.newEvents(
          [for (final e in fresh) '${e['title'] ?? 'حدث'} — ${d.nameOf(e['facilityId']?.toString())}'],
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _n(int? v) => v == null ? _noData : _fmt(v);

  String _stat(String section, String label, String fallback) {
    final n = _data?.summaryValue(section, label);
    return n == null ? fallback : _fmt(n);
  }

  static String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('٬');
      b.write(s[i]);
    }
    return b.toString();
  }

  int? _sum(List<JsonRow> facilities, Map<String, List<JsonRow>?> source, {bool Function(JsonRow)? where}) {
    var any = false;
    var n = 0;
    for (final f in facilities) {
      final rows = source[f['id']];
      if (rows == null) continue;
      any = true;
      n += where == null ? rows.length : rows.where(where).length;
    }
    return any ? n : null;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['displayNameAr']?.toString() ??
        widget.user['username']?.toString() ??
        '';

    return Scaffold(
      backgroundColor: _page,
      body: RefreshIndicator(
        color: _cyan,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _commandHeader(name)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _featuredEvents(),
                  const SizedBox(height: 12),
                  ..._domainCards(),
                  const SizedBox(height: 12),
                  _trainingCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _commandHeader(String name) {
    final role = name.isEmpty ? 'COMMAND' : name;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x2214363C)),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFFFFFFF), Color(0xFFF3FAF9)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D3038).withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Material(
                    color: const Color(0xFF123840),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: widget.onOpenMenu,
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(Icons.menu_rounded, color: Color(0xFFE8FFF8), size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'لوحة القيادة المركزية',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.tajawal(
                            fontWeight: FontWeight.w800,
                            fontSize: 16.5,
                            height: 1.15,
                            color: _ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _cyan.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: _cyan.withValues(alpha: 0.22)),
                            ),
                            child: Text(
                              role,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.tajawal(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _teal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0x1614363C)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'رؤية شاملة وإحاطة دقيقة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.tajawal(fontSize: 12.5, fontWeight: FontWeight.w600, color: _sub),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7F6),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x1A14363C)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _stampColor,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: _stampColor.withValues(alpha: 0.35), blurRadius: 6)],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _stamp,
                          style: GoogleFonts.tajawal(fontSize: 11.5, fontWeight: FontWeight.w700, color: _sub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _stamp {
    final d = _data;
    if (d == null) return _error == null ? 'جارٍ التحميل…' : 'تعذر التحديث';
    return _error == null ? 'تحديث ${hhmm(d.fetchedAt)}' : 'آخر تحديث ${hhmm(d.fetchedAt)}';
  }

  Color get _stampColor => _error != null ? _red : (_data == null ? _amber : _green);

  String _avgClose(List<JsonRow> events) {
    var n = 0;
    var sum = 0;
    for (final e in events) {
      final a = CommandData.parseTime(e['createdAt']);
      final b = CommandData.parseTime(e['closedAt']);
      if (a == null || b == null) continue;
      n++;
      sum += b.difference(a).inMinutes;
    }
    if (n == 0) return _noData;
    final m = sum / n;
    return m < 60 ? '${m.round()} د' : '${(m / 60).toStringAsFixed(1)} س';
  }

  String _sumKey(List<JsonRow> rows, String key) {
    if (rows.isEmpty) return _noData;
    var any = false;
    var n = 0;
    for (final row in rows) {
      final value = row[key];
      if (value is! num) continue;
      any = true;
      n += value.round();
    }
    return any ? '$n' : _noData;
  }

  String _availableBeds(List<JsonRow> rows) {
    if (rows.isEmpty) return _noData;
    var any = false;
    var n = 0;
    for (final row in rows) {
      final total = row['beds'];
      if (total is! num) continue;
      any = true;
      final used = row['bedsUsed'];
      n += total.round() - (used is num ? used.round() : 0);
    }
    return any ? '$n' : _noData;
  }

  Widget _featuredEvents() {
    final d = _data;
    final has = d?.hasEvents ?? false;
    final all = d?.allEvents ?? const <JsonRow>[];
    final open = all.where(CommandData.isOpen).toList();
    int rank(int r) => open.where((e) => CommandData.severityRank(e) == r).length;
    return _Shell(
      tone: _cyan,
      onTap: () => _openOps(OpsEventsScreen(api: widget.api)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHead(num: '01', title: 'الأحداث الطبية', tone: _cyan, icon: 'pulse'),
          _primaryValue(_stat('الأحداث الطبية', 'إجمالي الأحداث', has ? _fmt(all.length) : _noData), 40),
          Text('إجمالي الأحداث', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: _sub)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _mini(_stat('الأحداث الطبية', 'نشطة الآن', has ? '${open.length}' : _noData), 'مفتوحة الآن', valueColor: _amber)),
              const SizedBox(width: 8),
              Expanded(child: _mini(_stat('الأحداث الطبية', 'تحويلات', _noData), 'تحويلات')),
              const SizedBox(width: 8),
              Expanded(child: _mini(has ? _avgClose(all) : _noData, 'متوسط زمن الإغلاق', valueColor: _green)),
            ],
          ),
          const SizedBox(height: 14),
          Text('المفتوحة حسب الخطورة', style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w700, color: _faint)),
          const SizedBox(height: 8),
          _sev('عاجل', has ? '${rank(0)}' : _noData, _red),
          _sev('مرتفع / متوسط', has ? '${rank(1)}' : _noData, _amber),
          _sev('منخفض / عادي', has ? '${rank(2)}' : _noData, _green),
        ],
      ),
    );
  }

  Widget _primaryValue(String v, double size) {
    if (v == _noData) {
      return Text(_noData, style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w800, color: _faint, height: 1.3));
    }
    return Text(v, style: GoogleFonts.tajawal(fontSize: size, fontWeight: FontWeight.w900, color: _ink, height: 1));
  }

  List<Widget> _domainCards() {
    final d = _data;
    List<JsonRow> of(String t) => d?.ofType(t) ?? const [];
    String total(String t) => d == null ? _noData : '${of(t).length}';
    String openEvents(String t) => d == null ? _noData : _n(_sum(of(t), d.events, where: CommandData.isOpen));
    String needy(String t) {
      if (d == null || !d.hasNeeds) return _noData;
      return '${of(t).where((f) => d.openNeedsOf(f['id']?.toString() ?? '').isNotEmpty).length}';
    }

    final vehicles = d?.allVehicles ?? const <JsonRow>[];
    final hasFleet = d?.hasFleet ?? false;
    String fleetCount(String status) => hasFleet ? '${vehicles.where((v) => v['status'] == status).length}' : _noData;

    final warehouses = of(CommandData.warehouse);
    final stocked = [for (final f in warehouses) d?.stores[f['id']]].whereType<List<JsonRow>>().toList();
    final items = stocked.isEmpty ? null : stocked.fold<int>(0, (s, r) => s + r.length);
    final low = stocked.isEmpty ? null : stocked.fold<int>(0, (s, r) => s + r.where((i) => i['low'] == true).length);

    final cards = <({
      String num,
      String title,
      String icon,
      Color tone,
      String primary,
      String primaryLabel,
      List<(String, String, bool)> stats,
      VoidCallback? onTap,
    })>[
      (
        num: '02',
        title: 'الأسطول',
        icon: 'truck',
        tone: _blue,
        primary: _stat('الأسطول', 'إجمالي المركبات', hasFleet ? '${vehicles.length}' : _noData),
        primaryLabel: 'إجمالي المركبات',
        stats: [
          ('متاحة', _stat('الأسطول', 'متاحة', fleetCount('Ready')), false),
          ('في مهمة', _stat('الأسطول', 'في مهمة', fleetCount('OnMission')), false),
          ('صيانة', !hasFleet ? _noData : '${vehicles.where((v) => v['status'] == 'صيانة' || v['status'] == 'Maintenance').length}', true),
        ],
        onTap: () => _openOps(OpsFleetScreen(api: widget.api)),
      ),
      (
        num: '03',
        title: 'صحة السجون',
        icon: 'prison',
        tone: _teal,
        primary: _stat('صحة السجون', 'إجمالي السجون', total(CommandData.prison)),
        primaryLabel: 'إجمالي السجون',
        stats: [
          ('نزلاء حسيا', _stat('صحة السجون', 'إجمالي النزلاء', _n(d?.inmates)), false),
          ('كوادر', _stat('صحة السجون', 'الكوادر الطبية', _sumKey(d?.boardPrisons ?? const [], 'medStaff')), false),
          ('أحداث مفتوحة', openEvents(CommandData.prison), true),
        ],
        onTap: () => _openFacility('hasia'),
      ),
      (
        num: '04',
        title: 'الوحدات الطبية',
        icon: 'kit',
        tone: _green,
        primary: _stat('الوحدات الطبية', 'إجمالي الوحدات', total(CommandData.unit)),
        primaryLabel: 'إجمالي الوحدات',
        stats: [
          ('كوادر', _stat('الوحدات الطبية', 'الكوادر الطبية', _sumKey(
            (d?.boardPoints ?? const []).where((p) => p['type']?.toString() == 'وحدة طبية').toList(),
            'staff',
          )), false),
          ('أحداث مفتوحة', openEvents(CommandData.unit), false),
          ('تحتاج دعمًا', _stat('الوحدات الطبية', 'تحتاج دعمًا', needy(CommandData.unit)), true),
        ],
        onTap: () => _openOps(OpsUnitsScreen(api: widget.api)),
      ),
      (
        num: '05',
        title: 'مراكز الرعاية',
        icon: 'medcenter',
        tone: _blue,
        primary: _stat('مراكز الرعاية الطبية', 'إجمالي المراكز', total(CommandData.center)),
        primaryLabel: 'إجمالي المراكز',
        stats: [
          ('كوادر', _stat('مراكز الرعاية الطبية', 'الكوادر الطبية', _sumKey(
            (d?.boardPoints ?? const []).where((p) => p['type']?.toString() == 'مركز طبي').toList(),
            'staff',
          )), false),
          ('أحداث مفتوحة', openEvents(CommandData.center), false),
          ('تحتاج دعمًا', _stat('مراكز الرعاية الطبية', 'تحتاج دعمًا', needy(CommandData.center)), true),
        ],
        onTap: () => _openOps(OpsCentersScreen(api: widget.api)),
      ),
      (
        num: '06',
        title: 'المشافي',
        icon: 'hospital',
        tone: _cyan,
        primary: total(CommandData.hospital),
        primaryLabel: 'إجمالي المشافي',
        stats: [
          ('أسرّة', _stat('المشافي', 'أسرّة متاحة', _availableBeds(d?.boardHospitals ?? const [])), false),
          ('أحداث مفتوحة', openEvents(CommandData.hospital), false),
          ('تحتاج دعمًا', needy(CommandData.hospital), true),
        ],
        onTap: () => _openFacility('harasta'),
      ),
      (
        num: '07',
        title: 'المستودعات',
        icon: 'box',
        tone: _amber,
        primary: _stat('المستودعات', 'إجمالي المستودعات', total(CommandData.warehouse)),
        primaryLabel: 'إجمالي المستودعات',
        stats: [
          ('أصناف', _stat('المستودعات', 'إجمالي الأصناف', _n(items)), false),
          ('منخفضة', _stat('المستودعات', 'أصناف منخفضة', _n(low)), false),
          ('طلبات معلّقة', _stat('المستودعات', 'طلبات معلّقة', d == null ? _noData : _n(_sum(warehouses, d.needs))), true),
        ],
        onTap: () => _openOps(OpsWarehousesScreen(api: widget.api)),
      ),
    ];

    return [
      for (final c in cards) ...[
        _Shell(
          tone: c.tone,
          onTap: c.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHead(num: c.num, title: c.title, tone: c.tone, icon: c.icon),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  _primaryValue(c.primary, 32),
                  const SizedBox(width: 8),
                  Text(c.primaryLabel, style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: _sub)),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: _line),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < c.stats.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _mini(
                        c.stats[i].$2,
                        c.stats[i].$1,
                        valueColor: c.stats[i].$3 ? _red : _ink,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  Widget _trainingCard() {
    return _Shell(
      tone: _blue,
      onTap: () => _openOps(OpsTrainingScreen(api: widget.api)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHead(num: '08', title: 'التدريب والتطوير', tone: _blue, icon: 'cap'),
          _primaryValue(_stat('التدريب والتطوير', 'إجمالي البرامج', _noData), 36),
          Text('إجمالي البرامج', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.w600, color: _sub)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _mini(_stat('التدريب والتطوير', 'دورات نشطة', _noData), 'دورات نشطة')),
              const SizedBox(width: 8),
              Expanded(child: _mini(_stat('التدريب والتطوير', 'إجمالي المتدربين', _noData), 'متدربون')),
              const SizedBox(width: 8),
              Expanded(child: _mini(_stat('التدريب والتطوير', 'الشهادات الممنوحة', _noData), 'شهادات')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardHead({required String num, required String title, required Color tone, required String icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CmdIconTile(name: icon, tone: tone, size: 42, iconSize: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(num, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w800, color: _faint)),
                Text(title, style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(String value, String label, {Color valueColor = _ink}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x0C134048),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (value == _noData)
            SizedBox(
              height: 17.6,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(_noData,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.tajawal(fontSize: 10.5, fontWeight: FontWeight.w700, color: _faint)),
              ),
            )
          else
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w900, color: valueColor, height: 1.1)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.tajawal(fontSize: 10.5, fontWeight: FontWeight.w600, color: _faint)),
        ],
      ),
    );
  }

  Widget _sev(String label, String value, Color tone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: tone, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: GoogleFonts.tajawal(fontWeight: FontWeight.w700, fontSize: 12.5, color: _ink))),
          Text(value,
              style: value == _noData
                  ? GoogleFonts.tajawal(fontWeight: FontWeight.w700, fontSize: 11.5, color: _faint)
                  : GoogleFonts.tajawal(fontWeight: FontWeight.w900, fontSize: 15, color: tone)),
        ],
      ),
    );
  }

  void _openOps(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _openFacility(String id) {
    Widget page;
    if (id == 'harasta') {
      page = HarastaHubScreen(api: widget.api, user: widget.user, onLogout: widget.onLogout);
    } else if (id == 'hasia') {
      page = HasiaHubScreen(api: widget.api, user: widget.user, onLogout: widget.onLogout);
    } else {
      page = FacilityScreen(api: widget.api, facilityId: id);
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.tone, required this.child, this.onTap});
  final Color tone;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1F143139)),
        boxShadow: const [BoxShadow(color: Color(0x24102F36), blurRadius: 20, offset: Offset(0, 10))],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border(top: BorderSide(color: tone, width: 3)),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: body),
    );
  }
}
