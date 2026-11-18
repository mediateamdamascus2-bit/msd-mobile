import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../data/command_data.dart';
import '../services/new_item_watcher.dart';
import '../services/notification_service.dart';
import '../theme/cmd_icon.dart';
import '../theme/tokens.dart';
import '../ui/msd_components.dart';
import 'ops/ops_live.dart';

/// Mobile central command — mirrors web لوحة القيادة المركزية (no facility board / stations strip).
class NativeHomeScreen extends StatefulWidget {
  const NativeHomeScreen({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
    this.onOpenMenu,
    this.onOpenSection,
    this.onBoardTime,
    this.active = true,
  });

  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;
  final VoidCallback? onOpenMenu;
  final void Function(String section)? onOpenSection;
  final ValueChanged<DateTime>? onBoardTime;
  final bool active;

  @override
  State<NativeHomeScreen> createState() => _NativeHomeScreenState();
}

class _NativeHomeScreenState extends State<NativeHomeScreen> with WidgetsBindingObserver {
  static const _missing = '—';

  CommandData? _data = CommandRepository.cached;
  String? _error;
  Timer? _timer;
  final _newEvents = NewItemWatcher();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final d = _data;
    if (d != null) {
      _newEvents.absorb(d.allEvents);
      widget.onBoardTime?.call(d.fetchedAt);
    }
    _load();
    _armTimer();
  }

  @override
  void didUpdateWidget(covariant NativeHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
    _armTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) _load();
    _armTimer();
  }

  void _armTimer() {
    final life = WidgetsBinding.instance.lifecycleState;
    final foreground = life == null || life == AppLifecycleState.resumed;
    if (widget.active && foreground) {
      _timer ??= Timer.periodic(const Duration(seconds: 30), (_) => _load());
    } else {
      _timer?.cancel();
      _timer = null;
    }
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
      widget.onBoardTime?.call(d.fetchedAt);
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

  String _n(int? v) => v == null ? _missing : fmtInt(v);

  String _stat(String section, String label, String fallback) {
    final n = _data?.summaryValue(section, label);
    return n == null ? fallback : fmtInt(n);
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

  void _open(String section) => widget.onOpenSection?.call(section);

  @override
  Widget build(BuildContext context) {
    final name = widget.user['displayNameAr']?.toString() ??
        widget.user['username']?.toString() ??
        '';
    final loading = _data == null && _error == null;
    final failedEmpty = _data == null && _error != null;

    return Scaffold(
      backgroundColor: MsdTokens.page,
      body: RefreshIndicator(
        color: MsdTokens.cyan,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _commandHeader(name)),
            if (loading)
              const SliverToBoxAdapter(child: MsdLoading(rows: 4))
            else if (failedEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MsdErrorState(message: 'تعذّر التحديث — اسحب للتحديث', onRetry: _load),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _summaryGrid(),
                    const SizedBox(height: 14),
                    _featuredEvents(),
                    const SizedBox(height: 12),
                    ..._domainCards(),
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
    final stamp = _stamp;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MsdTokens.deepWash),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [MsdTokens.white, MsdTokens.paper],
            ),
            boxShadow: [
              BoxShadow(
                color: MsdTokens.deep.withValues(alpha: 0.08),
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
                    color: MsdTokens.deep,
                    borderRadius: BorderRadius.circular(12),
                    child: Semantics(
                      label: 'القائمة',
                      button: true,
                      child: Tooltip(
                        message: 'القائمة',
                        child: InkWell(
                          onTap: widget.onOpenMenu,
                          borderRadius: BorderRadius.circular(12),
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(Icons.menu_rounded, color: MsdTokens.mintWash, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'لوحة القيادة المركزية',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            height: 1.15,
                            color: MsdTokens.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: MsdTokens.cyan.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: MsdTokens.cyan.withValues(alpha: 0.22)),
                            ),
                            child: Text(
                              role,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: MsdTokens.teal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (stamp != null) ...[
                const SizedBox(height: 12),
                Container(height: 1, color: MsdTokens.lineSoft),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: _stampColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stamp,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _stampColor),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? get _stamp {
    final d = _data;
    if (d == null) return null;
    if (_error != null) return 'تعذّر التحديث — اسحب للتحديث';
    return 'آخر تحديث ${hhmm(d.fetchedAt)}';
  }

  Color get _stampColor => _error != null ? MsdTokens.danger : MsdTokens.success;

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
    if (n == 0) return _missing;
    final m = sum / n;
    return m < 60 ? '${fmtInt(m.round())} د' : '${(m / 60).toStringAsFixed(1)} س';
  }

  String _sumKey(List<JsonRow> rows, String key) {
    if (rows.isEmpty) return _missing;
    var any = false;
    var n = 0;
    for (final row in rows) {
      final value = row[key];
      if (value is! num) continue;
      any = true;
      n += value.round();
    }
    return any ? fmtInt(n) : _missing;
  }

  String _availableBeds(List<JsonRow> rows) {
    if (rows.isEmpty) return _missing;
    var any = false;
    var n = 0;
    for (final row in rows) {
      final total = row['beds'];
      if (total is! num) continue;
      any = true;
      final used = row['bedsUsed'];
      n += total.round() - (used is num ? used.round() : 0);
    }
    return any ? fmtInt(n) : _missing;
  }

  Widget _summaryGrid() {
    final d = _data;
    final openEvents = d == null || !d.hasEvents
        ? _missing
        : fmtInt(d.allEvents.where(CommandData.isOpen).length);
    final vehicles = d?.allVehicles ?? const <JsonRow>[];
    final onMission = d == null || !(d.hasFleet)
        ? _missing
        : fmtInt(vehicles.where((v) => v['status'] == 'OnMission' || v['status'] == 'في مهمة').length);
    final inmates = d?.summaryValue('صحة السجون', 'إجمالي النزلاء') ?? d?.inmates;
    final cases = () {
      final board = d?.boardPrisons ?? const <JsonRow>[];
      if (board.isEmpty) return null;
      var any = false;
      var n = 0;
      for (final r in board) {
        final v = r['activeCases'];
        if (v is! num) continue;
        any = true;
        n += v.round();
      }
      return any ? n : null;
    }();
    final people = inmates ?? cases;
    final peopleLabel = inmates != null ? 'النزلاء' : 'الحالات';
    final openNeeds = d == null || !d.hasNeeds
        ? _missing
        : fmtInt(d.needs.values.fold<int>(0, (s, rows) => s + (rows?.length ?? 0)));

    final cells = <({String value, String label, String section, Color tone, String icon})>[
      (value: openEvents, label: 'الأحداث المفتوحة', section: 'events', tone: MsdTokens.cyan, icon: 'pulse'),
      (value: onMission, label: 'المركبات في مهمة', section: 'fleet', tone: MsdTokens.blue, icon: 'truck'),
      (value: people == null ? _missing : fmtInt(people), label: peopleLabel, section: 'prisons', tone: MsdTokens.teal, icon: 'prison'),
      (value: openNeeds, label: 'الاحتياجات المفتوحة', section: 'needs', tone: MsdTokens.amberFill, icon: 'box'),
    ];

    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCell(
                    value: cells[row * 2 + col].value,
                    label: cells[row * 2 + col].label,
                    tone: cells[row * 2 + col].tone,
                    icon: cells[row * 2 + col].icon,
                    onTap: () => _open(cells[row * 2 + col].section),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _featuredEvents() {
    final d = _data;
    final has = d?.hasEvents ?? false;
    final all = d?.allEvents ?? const <JsonRow>[];
    final open = all.where(CommandData.isOpen).toList();
    int rank(int r) => open.where((e) => CommandData.severityRank(e) == r).length;
    final transfers = d?.summaryValue('الأحداث الطبية', 'تحويلات');
    return _Shell(
      tone: MsdTokens.cyan,
      onTap: () => _open('events'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHead(title: 'الأحداث الطبية', tone: MsdTokens.cyan, icon: 'pulse'),
          _primaryValue(_stat('الأحداث الطبية', 'إجمالي الأحداث', has ? fmtInt(all.length) : _missing), 40),
          const Text('إجمالي الأحداث', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MsdTokens.sub)),
          const SizedBox(height: 12),
          _statLines([
            (_stat('الأحداث الطبية', 'نشطة الآن', has ? fmtInt(open.length) : _missing), 'مفتوحة الآن', MsdTokens.amberFill),
            if (transfers != null) (fmtInt(transfers), 'تحويلات', MsdTokens.ink),
            (has ? _avgClose(all) : _missing, 'متوسط زمن الإغلاق', MsdTokens.success),
          ]),
          const SizedBox(height: 14),
          const Text('المفتوحة حسب الخطورة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MsdTokens.faint)),
          const SizedBox(height: 8),
          _sev('عاجل', has ? fmtInt(rank(0)) : _missing, MsdTokens.danger),
          _sev('مرتفع / متوسط', has ? fmtInt(rank(1)) : _missing, MsdTokens.amberFill),
          _sev('منخفض / عادي', has ? fmtInt(rank(2)) : _missing, MsdTokens.success),
        ],
      ),
    );
  }

  Widget _primaryValue(String v, double size) {
    if (v == _missing) {
      return const Text(_missing, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: MsdTokens.faint, height: 1.3));
    }
    return Text(v, style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: MsdTokens.ink, height: 1));
  }

  List<Widget> _domainCards() {
    final d = _data;
    List<JsonRow> of(String t) => d?.ofType(t) ?? const [];
    String total(String t) => d == null ? _missing : fmtInt(of(t).length);
    String openEvents(String t) => d == null ? _missing : _n(_sum(of(t), d.events, where: CommandData.isOpen));
    String needy(String t) {
      if (d == null || !d.hasNeeds) return _missing;
      return fmtInt(of(t).where((f) => d.openNeedsOf(f['id']?.toString() ?? '').isNotEmpty).length);
    }

    final vehicles = d?.allVehicles ?? const <JsonRow>[];
    final hasFleet = d?.hasFleet ?? false;
    String fleetCount(String status) => hasFleet ? fmtInt(vehicles.where((v) => v['status'] == status).length) : _missing;

    final warehouses = of(CommandData.warehouse);
    final stocked = [for (final f in warehouses) d?.stores[f['id']]].whereType<List<JsonRow>>().toList();
    final items = stocked.isEmpty ? null : stocked.fold<int>(0, (s, r) => s + r.length);
    final low = stocked.isEmpty ? null : stocked.fold<int>(0, (s, r) => s + r.where((i) => i['low'] == true).length);

    final cards = <({
      String title,
      String icon,
      Color tone,
      String section,
      String primary,
      String primaryLabel,
      List<(String, String, bool)> stats,
    })>[
      (
        title: 'الأسطول',
        icon: 'truck',
        tone: MsdTokens.blue,
        section: 'fleet',
        primary: _stat('الأسطول', 'إجمالي المركبات', hasFleet ? fmtInt(vehicles.length) : _missing),
        primaryLabel: 'إجمالي المركبات',
        stats: [
          ('متاحة', _stat('الأسطول', 'متاحة', fleetCount('Ready')), false),
          ('في مهمة', _stat('الأسطول', 'في مهمة', fleetCount('OnMission')), false),
          ('صيانة', !hasFleet ? _missing : fmtInt(vehicles.where((v) => v['status'] == 'صيانة' || v['status'] == 'Maintenance').length), true),
        ],
      ),
      (
        title: 'صحة السجون',
        icon: 'prison',
        tone: MsdTokens.teal,
        section: 'prisons',
        primary: _stat('صحة السجون', 'إجمالي السجون', total(CommandData.prison)),
        primaryLabel: 'إجمالي السجون',
        stats: [
          ('نزلاء حسيا', _stat('صحة السجون', 'إجمالي النزلاء', _n(d?.inmates)), false),
          ('كوادر', _stat('صحة السجون', 'الكوادر الطبية', _sumKey(d?.boardPrisons ?? const [], 'medStaff')), false),
          ('أحداث مفتوحة', openEvents(CommandData.prison), true),
        ],
      ),
      (
        title: 'الوحدات الطبية',
        icon: 'kit',
        tone: MsdTokens.successFill,
        section: 'units',
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
      ),
      (
        title: 'مراكز الرعاية',
        icon: 'medcenter',
        tone: MsdTokens.blue,
        section: 'centers',
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
      ),
      (
        title: 'المشافي',
        icon: 'hospital',
        tone: MsdTokens.cyan,
        section: 'hospitals',
        primary: total(CommandData.hospital),
        primaryLabel: 'إجمالي المشافي',
        stats: [
          ('أسرّة', _stat('المشافي', 'أسرّة متاحة', _availableBeds(d?.boardHospitals ?? const [])), false),
          ('أحداث مفتوحة', openEvents(CommandData.hospital), false),
          ('تحتاج دعمًا', needy(CommandData.hospital), true),
        ],
      ),
      (
        title: 'المستودعات',
        icon: 'box',
        tone: MsdTokens.amberFill,
        section: 'warehouses',
        primary: _stat('المستودعات', 'إجمالي المستودعات', total(CommandData.warehouse)),
        primaryLabel: 'إجمالي المستودعات',
        stats: [
          ('أصناف', _stat('المستودعات', 'إجمالي الأصناف', _n(items)), false),
          ('منخفضة', _stat('المستودعات', 'أصناف منخفضة', _n(low)), false),
          ('طلبات معلّقة', _stat('المستودعات', 'طلبات معلّقة', d == null ? _missing : _n(_sum(warehouses, d.needs))), true),
        ],
      ),
    ];

    return [
      for (final c in cards) ...[
        _Shell(
          tone: c.tone,
          onTap: () => _open(c.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHead(title: c.title, tone: c.tone, icon: c.icon),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  _primaryValue(c.primary, 32),
                  const SizedBox(width: 8),
                  Text(c.primaryLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MsdTokens.sub)),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: MsdTokens.line),
              const SizedBox(height: 12),
              _statLines([
                for (final s in c.stats) (s.$2, s.$1, s.$3 ? MsdTokens.danger : MsdTokens.ink),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  Widget _trainingCard() {
    final d = _data;
    final courses = d?.boardCourses ?? const <JsonRow>[];
    final programs = d?.summaryValue('التدريب والتطوير', 'إجمالي البرامج');
    final active = d?.summaryValue('التدريب والتطوير', 'دورات نشطة');
    final enrolled = d?.summaryValue('التدريب والتطوير', 'إجمالي المتدربين');
    final certified = d?.summaryValue('التدريب والتطوير', 'الشهادات الممنوحة');
    final hasSummary = programs != null || active != null || enrolled != null || certified != null;
    if (courses.isEmpty && !hasSummary) {
      return _Shell(
        tone: MsdTokens.blue,
        onTap: () => _open('training'),
        child: Row(
          children: [
            const CmdIconTile(name: 'cap', tone: MsdTokens.blue, size: 42, iconSize: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('التدريب والتطوير', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: MsdTokens.ink)),
                  SizedBox(height: 2),
                  Text('لا توجد بيانات بعد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MsdTokens.faint)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, size: 18, color: MsdTokens.faint),
          ],
        ),
      );
    }
    int fold(String key) => courses.fold<int>(0, (s, e) => s + ((e[key] as num?)?.round() ?? 0));
    final activeCount = courses.isEmpty ? null : courses.where((e) => e['status'] == 'نشطة').length;
    return _Shell(
      tone: MsdTokens.blue,
      onTap: () => _open('training'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHead(title: 'التدريب والتطوير', tone: MsdTokens.blue, icon: 'cap'),
          _primaryValue(programs != null ? fmtInt(programs) : (courses.isEmpty ? _missing : fmtInt(courses.length)), 36),
          const Text('إجمالي البرامج', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MsdTokens.sub)),
          const SizedBox(height: 12),
          _statLines([
            (active != null ? fmtInt(active) : _n(activeCount), 'دورات نشطة', MsdTokens.ink),
            (enrolled != null ? fmtInt(enrolled) : (courses.isEmpty ? _missing : fmtInt(fold('enrolled'))), 'متدربون', MsdTokens.ink),
            (certified != null ? fmtInt(certified) : (courses.isEmpty ? _missing : fmtInt(fold('certified'))), 'شهادات', MsdTokens.ink),
          ]),
        ],
      ),
    );
  }

  Widget _cardHead({required String title, required Color tone, required String icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CmdIconTile(name: icon, tone: tone, size: 42, iconSize: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: MsdTokens.ink)),
          ),
          const Icon(Icons.chevron_left, size: 18, color: MsdTokens.faint),
        ],
      ),
    );
  }

  Widget _statLines(List<(String, String, Color)> items) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _lineStat(items[i].$1, items[i].$2, items[i].$3),
        ],
      ],
    );
  }

  Widget _lineStat(String value, String label, Color valueColor) {
    final missing = value == _missing;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: MsdTokens.lineSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MsdTokens.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MsdTokens.faint),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: missing ? MsdTokens.faint : valueColor,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sev(String label, String value, Color tone) {
    final missing = value == _missing;
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
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: MsdTokens.ink))),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: missing ? 14 : 15,
              color: missing ? MsdTokens.faint : tone,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.value,
    required this.label,
    required this.tone,
    required this.icon,
    required this.onTap,
  });

  final String value;
  final String label;
  final Color tone;
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final missing = value == '—';
    return Material(
      color: MsdTokens.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: MsdTokens.tealWash,
        highlightColor: MsdTokens.cyanWash,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MsdTokens.line),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CmdIconTile(name: icon, tone: tone, size: 34, iconSize: 16),
                    const Spacer(),
                    const Icon(Icons.chevron_left, size: 16, color: MsdTokens.faint),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: missing ? MsdTokens.faint : MsdTokens.ink,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MsdTokens.sub, height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.tone, required this.child, required this.onTap});
  final Color tone;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: MsdTokens.deepWash, blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Material(
        color: MsdTokens.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: MsdTokens.tealWash,
          highlightColor: MsdTokens.cyanWash,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MsdTokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: 3, color: tone),
                Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 14), child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
