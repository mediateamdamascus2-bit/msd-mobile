import 'package:flutter/material.dart';

import '../api_client.dart';
import '../data/harasta_catalog.dart';
import '../theme/app_theme.dart';
import '../ui/msd_notify.dart';
import 'harasta/harasta_pages.dart';

/// Mobile Harasta home — mirrors web `/f/harasta` «غرفة عمليات المشفى».
class HarastaHubScreen extends StatefulWidget {
  const HarastaHubScreen({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
  });

  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;

  @override
  State<HarastaHubScreen> createState() => _HarastaHubScreenState();
}

class _HarastaHubScreenState extends State<HarastaHubScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loading = true;
  List<Map<String, dynamic>> _depts = [];
  List<Map<String, dynamic>> _ops = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final depts = await widget.api.departmentsLive(HarastaCatalog.facilityId);
      final ops = await widget.api.harastaOps(HarastaCatalog.facilityId);
      if (!mounted) return;
      setState(() {
        _depts = depts.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _ops = ops.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      await MsdNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _waitingNow {
    var n = 0;
    for (final d in _depts) {
      final queued = _asInt(d['queued']);
      final present = _asInt(d['present']);
      final cap = d['capacity'];
      n += queued + (cap == null ? present : 0);
    }
    return n;
  }

  List<Map<String, dynamic>> get _pressure {
    final items = <({Map<String, dynamic> dept, double load, int need})>[];
    for (final d in _depts) {
      final cap = d['capacity'];
      final occupied = _asInt(d['occupied']);
      final present = _asInt(d['present']);
      final queued = _asInt(d['queued']);
      final load = (cap is num && cap > 0) ? occupied * 100.0 / cap : (present > 0 ? 100.0 : 0.0);
      final need = queued + (cap == null ? present : 0);
      if (need > 0 || load >= 75) {
        items.add((dept: d, load: load, need: need));
      }
    }
    items.sort((a, b) {
      final c = b.need.compareTo(a.need);
      return c != 0 ? c : b.load.compareTo(a.load);
    });
    return items.take(4).map((e) => e.dept).toList();
  }

  String get _finding {
    final pressure = _pressure;
    if (_waitingNow > 0) {
      return '$_waitingNow بانتظار الدور الآن — راقب الاستقبال قبل أن يطول الانتظار.';
    }
    if (pressure.isNotEmpty) {
      return 'ضغط على ${pressure.first['name'] ?? ''} — تابع الأقسام قبل امتلاء السعة.';
    }
    return 'التشغيل مستقر حالياً — راقب العيادات والأقسام عند الحاجة.';
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _openSub(String title, Widget child) {
    _open(Scaffold(
      backgroundColor: MsdColors.mist,
      appBar: AppBar(
        backgroundColor: MsdTokens.deep,
        foregroundColor: MsdTokens.onDeep,
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: MsdTokens.onDeep)),
      ),
      body: child,
    ));
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  Color _toneColor(String? tone) {
    switch ((tone ?? '').toLowerCase()) {
      case 'red':
        return MsdTokens.danger;
      case 'amber':
        return MsdTokens.amberFill;
      case 'green':
        return MsdTokens.successFill;
      case 'blue':
        return MsdTokens.blue;
      case 'teal':
        return MsdColors.deepMid;
      default:
        return MsdColors.cyan;
    }
  }

  void _go(VoidCallback action) {
    Navigator.of(context).maybePop();
    action();
  }

  Widget _sideNav() {
    const deep = MsdTokens.deep;
    const mid = MsdTokens.deep;
    const accent = MsdTokens.cyan;
    const soft = MsdTokens.paper;

    Widget group({required String title, required List<Widget> children}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Text(
                title,
                style: TextStyle(
                  color: MsdTokens.faint,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: MsdTokens.mist),
                boxShadow: const [
                  BoxShadow(color: MsdTokens.lineSoft, blurRadius: 18, offset: Offset(0, 6)),
                ],
              ),
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const Divider(height: 1, thickness: 1, color: MsdTokens.paper, indent: 58, endIndent: 14),
                    children[i],
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Drawer(
      backgroundColor: soft,
      width: MediaQuery.sizeOf(context).width * 0.84,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.only(
          topStart: Radius.circular(22),
          bottomStart: Radius.circular(22),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(18, MediaQuery.paddingOf(context).top + 16, 18, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [deep, mid, MsdTokens.teal],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0.08),
                          ],
                        ),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                      ),
                      child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            HarastaCatalog.titleAr,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'غرفة عمليات المشفى',
                            style: TextStyle(
                              color: MsdTokens.mintWash,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: MsdTokens.sky,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'واجهات المتابعة والمحطات',
                          style: TextStyle(
                            color: MsdTokens.mintWash,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
              children: [
                group(
                  title: 'البداية',
                  children: [
                    _navItem(
                      icon: Icons.home_rounded,
                      label: 'الرئيسية',
                      tone: accent,
                      selected: true,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
                group(
                  title: 'متابعة التشغيل',
                  children: [
                    _navItem(
                      icon: Icons.badge_outlined,
                      label: 'متابعة الاستقبال',
                      tone: accent,
                      onTap: () => _go(() => _openSub(
                            'متابعة الاستقبال',
                            HarastaReceptionBoardPage(api: widget.api),
                          )),
                    ),
                    _navItem(
                      icon: Icons.medical_services_outlined,
                      label: 'متابعة العيادات',
                      tone: accent,
                      onTap: () => _go(() => _openSub(
                            'متابعة العيادات',
                            HarastaClinicsBoardPage(
                              api: widget.api,
                              onOpenLive: () => openHarastaStation(
                                context, widget.api, 'clinic_live', onLogout: widget.onLogout),
                            ),
                          )),
                    ),
                    _navItem(
                      icon: Icons.apartment_outlined,
                      label: 'أقسام التحويل',
                      tone: mid,
                      onTap: () => _go(() => _openSub(
                            'أقسام التحويل',
                            HarastaDeptsBoardPage(api: widget.api),
                          )),
                    ),
                  ],
                ),
                group(
                  title: 'المنشأة واللوجستيات',
                  children: [
                    _navItem(icon: Icons.account_tree_outlined, label: 'الهيكلية', tone: mid, onTap: () => _go(() => _openSub('الهيكلية', const HarastaStructurePage()))),
                    _navItem(icon: Icons.layers_outlined, label: 'الطوابق', tone: mid, onTap: () => _go(() => _openSub('الطوابق', const HarastaFloorsPage()))),
                    _navItem(icon: Icons.groups_outlined, label: 'الكوادر', tone: mid, onTap: () => _go(() => _openSub('الكوادر', const HarastaStaffPage()))),
                    _navItem(icon: Icons.folder_shared_outlined, label: 'ملفات المرضى', tone: mid, onTap: () => _go(() => _openSub('ملفات المرضى', HarastaFilesPage(api: widget.api)))),
                    _navItem(icon: Icons.local_shipping_outlined, label: 'الأسطول', tone: mid, onTap: () => _go(() => _openSub('الأسطول', HarastaFleetPage(api: widget.api)))),
                    _navItem(icon: Icons.inventory_2_outlined, label: 'المستودعات', tone: mid, onTap: () => _go(() => _openSub('المستودعات', HarastaStoresPage(api: widget.api)))),
                    _navItem(
                      icon: Icons.precision_manufacturing_outlined,
                      label: 'الأصول',
                      tone: accent,
                      onTap: () => _go(() => _openSub(
                            'متابعة الأصول',
                            HarastaAssetsPage(api: widget.api),
                          )),
                    ),
                    _navItem(icon: Icons.flag_outlined, label: 'الرؤية 2030', tone: MsdTokens.amberFill, onTap: () => _go(() => _openSub('الرؤية 2030', const HarastaVisionPage()))),
                    _navItem(
                      icon: Icons.tv_outlined,
                      label: 'شاشة النداء',
                      tone: mid,
                      onTap: () => _go(() => openHarastaStation(
                            context, widget.api, 'display', onLogout: widget.onLogout)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MsdTokens.dangerSoft),
                ),
                child: _navItem(
                  icon: Icons.logout_rounded,
                  label: 'تسجيل الخروج',
                  tone: MsdTokens.danger,
                  danger: true,
                  onTap: () => _go(() => widget.onLogout()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required Color tone,
    required VoidCallback onTap,
    bool selected = false,
    bool danger = false,
  }) {
    final fg = danger ? tone : (selected ? tone : MsdTokens.deep);
    return Material(
      color: selected ? tone.withValues(alpha: 0.09) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: tone.withValues(alpha: 0.08),
        highlightColor: tone.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: selected || danger ? 0.16 : 0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: tone),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected || danger ? FontWeight.w800 : FontWeight.w700,
                    color: fg,
                    height: 1.2,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
                )
              else
                Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: (danger ? tone : MsdTokens.faint).withValues(alpha: 0.85),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: MsdTokens.paper,
      endDrawer: _sideNav(),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _hero()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(_error!, style: const TextStyle(color: MsdColors.danger)),
                    ),
                  _attention(),
                  const SizedBox(height: 12),
                  _kpis(),
                  const SizedBox(height: 14),
                  _sectionHead('الأقسام الآن', 'الحمل ووجهات التحويل'),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ..._depts.map(_deptCard),
                  const SizedBox(height: 14),
                  _clinicTeaser(),
                  const SizedBox(height: 14),
                  _capacity(),
                  const SizedBox(height: 14),
                  _sectionHead('من نشاط النظام', 'مؤشرات التشغيل والإنجاز'),
                  const SizedBox(height: 8),
                  _opsGrid(),
                  const SizedBox(height: 14),
                  _sectionHead('نبض التشغيل', 'أرقام من هيكلية المشفى'),
                  const SizedBox(height: 8),
                  _staticOps(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [MsdTokens.deep, MsdTokens.deep, MsdTokens.cyan],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text('H', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(HarastaCatalog.titleAr, style: TextStyle(color: MsdTokens.onDeep, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('Police Hospital · Harasta', style: TextStyle(color: MsdTokens.onDeep, fontSize: 12), textDirection: TextDirection.ltr),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'تحديث',
                onPressed: _reload,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
              IconButton(
                tooltip: 'قائمة المشفى',
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                icon: const Icon(Icons.menu, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('غرفة عمليات المشفى', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(_finding, style: TextStyle(color: MsdTokens.onDeep, fontSize: 14, height: 1.45)),
        ],
      ),
    );
  }

  Widget _attention() {
    final pressure = _pressure;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MsdTokens.deepWash),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('متابعة فورية', style: TextStyle(color: MsdColors.sub, fontSize: 12, fontWeight: FontWeight.w700)),
                    Text('شريط الانتظار', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  ],
                ),
              ),
              Text(
                pressure.isEmpty ? 'لا ضغط ظاهر' : '${pressure.length} يحتاج مراجعة',
                style: TextStyle(color: MsdColors.teal, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (pressure.isEmpty)
            Text('كل الأقسام ضمن الحمل الطبيعي حالياً.', style: TextStyle(color: MsdColors.sub))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in pressure)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: MsdTokens.lineSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(
                          _asInt(d['queued']) > 0 ? '${d['queued']} بانتظار' : 'مراجعة السعة',
                          style: TextStyle(color: MsdColors.sub, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _kpis() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final k in HarastaCatalog.kpis)
          Container(
            width: (MediaQuery.sizeOf(context).width - 44) / 2,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MsdTokens.deepWash),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k.$1, style: TextStyle(color: MsdColors.sub, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(k.$2, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: MsdTokens.deep)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _sectionHead(String label, String title, {Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: MsdColors.sub, fontSize: 12, fontWeight: FontWeight.w700)),
              Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _deptCard(Map<String, dynamic> d) {
    final tone = _toneColor(d['tone']?.toString());
    final capacity = d['capacity'];
    final occupied = _asInt(d['occupied']);
    final free = _asInt(d['free']);
    final queued = _asInt(d['queued']);
    final present = _asInt(d['present']);
    final pct = (capacity is num && capacity > 0) ? (occupied * 100.0 / capacity) : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MsdTokens.lineSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openHarastaDept(
          context,
          widget.api,
          '${d['name'] ?? ''}',
          onLogout: widget.onLogout,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 3, color: tone),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('${d['name'] ?? ''}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                      if (queued > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: tone.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                          child: Text('بالدور $queued', style: TextStyle(color: tone, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (capacity is num) ...[
                    Row(
                      children: [
                        _metric('$capacity', 'العدد'),
                        _metric('$occupied', 'مشغول', warn: true),
                        _metric('$free', 'فارغ', ok: free > 0),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (pct / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: MsdTokens.lineSoft,
                        color: pct >= 90 ? MsdTokens.danger : pct >= 75 ? MsdTokens.amberFill : tone,
                      ),
                    ),
                  ] else
                    Text(
                      present > 0 ? '$present بانتظار الدور الآن' : 'لا انتظار حالياً',
                      style: TextStyle(color: present > 0 ? MsdTokens.amberFill : MsdColors.sub, fontWeight: FontWeight.w700),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _metric('${d['todayReferrals'] ?? 0}', 'توجيهات اليوم'),
                      _metric('${d['avgWaitLabel'] ?? '—'}', 'متوسط الانتظار'),
                      _metric('${d['maxWaitLabel'] ?? '—'}', 'أطول انتظار'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String value, String label, {bool warn = false, bool ok = false}) {
    final color = warn
        ? MsdTokens.amberFill
        : ok
            ? MsdTokens.successFill
            : MsdTokens.deep;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: MsdColors.sub)),
        ],
      ),
    );
  }

  Widget _clinicTeaser() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MsdTokens.deep,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('العيادات', style: TextStyle(color: MsdTokens.mintWash, fontSize: 12, fontWeight: FontWeight.w700)),
          Text('إحصائيات العيادات — اليوم', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 4),
          Text('الانتظار، التوجيهات، ومتوسط الانتظار لكل عيادة.', style: TextStyle(color: MsdTokens.onDeep, fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => openHarastaStation(
                  context, widget.api, 'clinic_live', onLogout: widget.onLogout),
                style: FilledButton.styleFrom(backgroundColor: MsdTokens.cyan),
                child: const Text('عرض كاملة'),
              ),
              TextButton(
                onPressed: () => _openSub(
                  'متابعة العيادات',
                  HarastaClinicsBoardPage(
                    api: widget.api,
                    onOpenLive: () => openHarastaStation(
                      context, widget.api, 'clinic_live', onLogout: widget.onLogout),
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('متابعة المسؤول'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _capacity() {
    const beds = [
      ('أقسام الإقامة', 124, MsdTokens.cyan),
      ('العناية والحواضن', 45, MsdTokens.blue),
      ('الجناح الاحترازي', 22, MsdTokens.amberFill),
      ('الإسعاف', 15, MsdTokens.danger),
    ];
    final max = beds.map((e) => e.$2).reduce((a, b) => a > b ? a : b).toDouble();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MsdTokens.deepWash),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('السعة', style: TextStyle(color: MsdColors.sub, fontSize: 12, fontWeight: FontWeight.w700)),
          Text('توزيع الأسرّة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 10),
          for (final b in beds) ...[
            Row(
              children: [
                SizedBox(width: 110, child: Text(b.$1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: b.$2 / max,
                      minHeight: 10,
                      backgroundColor: MsdTokens.lineSoft,
                      color: b.$3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${b.$2}', style: TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'دراسة لرفع الطاقة الاستيعابية الكلية من 250 إلى 400 سرير',
            style: TextStyle(color: MsdColors.sub, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _opsGrid() {
    if (_ops.isEmpty) {
      return Text('لا مؤشرات حالياً', style: TextStyle(color: MsdColors.sub));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in _ops)
          Container(
            width: (MediaQuery.sizeOf(context).width - 44) / 2,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MsdTokens.deepWash),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${o['key'] ?? ''}', style: TextStyle(color: MsdColors.sub, fontSize: 12, fontWeight: FontWeight.w700)),
                Text('${o['value'] ?? 0}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: MsdTokens.deep)),
                Text('${o['detail'] ?? ''}', style: TextStyle(color: MsdColors.faint, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _staticOps() {
    const items = [
      ('عمليات تخصصية', '30–40', 'يوميًا'),
      ('مراجعو العيادات', '~500', 'يوميًا'),
      ('ولادات', '10', 'يوميًا'),
      ('تحاليل مخبرية', '40,000', 'شهريًا'),
      ('غسيل كلى', '120', 'جلسة/شهر'),
      ('علاج فيزيائي', '150', 'حالة/أسبوع'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final i in items)
          Container(
            width: (MediaQuery.sizeOf(context).width - 44) / 2,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MsdTokens.deepWash),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.$1, style: TextStyle(color: MsdColors.sub, fontSize: 12, fontWeight: FontWeight.w700)),
                Text(i.$2, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: MsdTokens.cyan)),
                Text(i.$3, style: TextStyle(color: MsdColors.faint, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }
}
