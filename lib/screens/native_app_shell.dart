import 'package:flutter/material.dart';

import '../api_client.dart';
import '../data/command_data.dart';
import '../theme/cmd_icon.dart';
import 'harasta_hub_screen.dart';
import 'hasia_hub_screen.dart';
import 'native_home_screen.dart';
import 'needs_screen.dart';
import 'ops/ops_centers_screen.dart';
import 'ops/ops_events_screen.dart';
import 'ops/ops_fleet_screen.dart';
import 'ops/ops_hospitals_screen.dart';
import 'ops/ops_hr_screen.dart';
import 'ops/ops_map_screen.dart';
import 'ops/ops_prisons_screen.dart';
import 'ops/ops_reports_screen.dart';
import 'ops/ops_training_screen.dart';
import 'ops/ops_units_screen.dart';
import 'ops/ops_warehouses_screen.dart';
import 'settings_screen.dart';
import '../theme/station_chrome.dart';
import '../theme/tokens.dart';

class NativeAppShell extends StatefulWidget {
  const NativeAppShell({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
  });

  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;

  @override
  State<NativeAppShell> createState() => _NativeAppShellState();
}

class _NativeAppShellState extends State<NativeAppShell> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  var _index = 0;
  var _section = 'home';
  bool? _online;
  DateTime? _boardAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boardAt = CommandRepository.cached?.fetchedAt;
    _ping();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ping();
  }

  Future<void> _ping() async {
    final ok = await widget.api.serverReachable();
    if (!mounted) return;
    setState(() => _online = ok);
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
    final cached = CommandRepository.cached?.fetchedAt;
    if (cached != null) _boardAt = cached;
    _ping();
  }

  void _closeDrawer() => _scaffoldKey.currentState?.closeDrawer();

  void _goTab(int i) {
    setState(() {
      _index = i;
      _section = const ['home', 'events', 'needs'][i];
    });
    _closeDrawer();
  }

  Future<void> _push(String id, Widget page) async {
    final previous = _section;
    setState(() => _section = id);
    _closeDrawer();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (!mounted) return;
    setState(() => _section = previous);
  }

  void _openNamed(String id) {
    switch (id) {
      case 'home':
        _goTab(0);
      case 'events':
        _goTab(1);
      case 'needs':
        _goTab(2);
      case 'fleet':
        _push(id, OpsFleetScreen(api: widget.api));
      case 'prisons':
        _push(id, OpsPrisonsScreen(api: widget.api, onOpenHasia: _openHasia));
      case 'units':
        _push(id, OpsUnitsScreen(api: widget.api));
      case 'centers':
        _push(id, OpsCentersScreen(api: widget.api));
      case 'hospitals':
        _push(id, OpsHospitalsScreen(api: widget.api, onOpenHarasta: _openHarasta));
      case 'map':
        _push(id, OpsMapScreen(api: widget.api));
      case 'warehouses':
        _push(id, OpsWarehousesScreen(api: widget.api));
      case 'training':
        _push(id, OpsTrainingScreen(api: widget.api));
      case 'hr':
        _push(id, OpsHrScreen(api: widget.api));
      case 'reports':
        _push(id, OpsReportsScreen(api: widget.api));
      case 'settings':
        _push(id, SettingsScreen(api: widget.api, user: widget.user, onLogout: _confirmLogout));
    }
  }

  void _openHasia() => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HasiaHubScreen(api: widget.api, user: widget.user, onLogout: _confirmLogout),
        ),
      );

  void _openHarasta() => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HarastaHubScreen(api: widget.api, user: widget.user, onLogout: _confirmLogout),
        ),
      );

  Future<void> _confirmLogout() async {
    if (await confirmLogout(context)) await widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      NativeHomeScreen(
        api: widget.api,
        user: widget.user,
        onLogout: _confirmLogout,
        active: _index == 0 && _section == 'home',
        onOpenMenu: _openDrawer,
        onOpenSection: _openNamed,
        onBoardTime: (t) {
          if (!mounted || _boardAt == t) return;
          setState(() => _boardAt = t);
        },
      ),
      OpsEventsScreen(api: widget.api, user: widget.user, embedded: true),
      NeedsScreen(api: widget.api, user: widget.user),
    ];

    final name = widget.user['displayNameAr']?.toString() ??
        widget.user['username']?.toString() ??
        '';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: MsdTokens.page,
      drawer: Drawer(
        backgroundColor: MsdTokens.deep,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 44,
                          height: 44,
                          color: MsdTokens.whiteWash,
                          child: const Icon(Icons.medical_services, color: MsdTokens.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إدارة الخدمات الطبية',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: MsdTokens.onDeep),
                          ),
                          Text(
                            name.isEmpty ? 'COMMAND' : name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MsdTokens.mintWash),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: MsdTokens.whiteWash),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  children: [
                    _drawerItem('home', 'الرئيسية', id: 'home'),
                    _drawerItem('pulse', 'الأحداث الطبية', id: 'events'),
                    _drawerItem('truck', 'الأسطول', id: 'fleet'),
                    _drawerItem('prison', 'صحة السجون', id: 'prisons'),
                    _drawerItem('kit', 'الوحدات الطبية', id: 'units'),
                    _drawerItem('medcenter', 'مراكز الرعاية الطبية', id: 'centers'),
                    _drawerItem('hospital', 'المشافي', id: 'hospitals'),
                    _drawerItem('pin', 'الخريطة التفاعلية', id: 'map'),
                    _drawerItem('box', 'المستودعات', id: 'warehouses'),
                    _drawerItem('cap', 'التدريب والتطوير', id: 'training'),
                    _drawerItem('user', 'القوى البشرية', id: 'hr'),
                    _drawerItem('chart', 'التقارير والإحصاءات', id: 'reports'),
                    _drawerItem('gear', 'الإعدادات', id: 'settings'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: _statusBox(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _confirmLogout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MsdTokens.onDeep,
                      side: const BorderSide(color: MsdTokens.mintLine),
                      backgroundColor: MsdTokens.deep.withValues(alpha: 0.55),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: MsdTokens.white,
          indicatorColor: MsdTokens.cyanWash,
          elevation: 0,
          height: 68,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? MsdTokens.teal : MsdTokens.faint,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(color: selected ? MsdTokens.teal : MsdTokens.faint, size: 22);
          }),
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: MsdTokens.white,
            border: Border(top: BorderSide(color: MsdTokens.tealWash)),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              if (i == 3) {
                _openDrawer();
                return;
              }
              _goTab(i);
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
              NavigationDestination(icon: Icon(Icons.monitor_heart_outlined), selectedIcon: Icon(Icons.monitor_heart), label: 'الأحداث'),
              NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'الاحتياجات'),
              NavigationDestination(icon: Icon(Icons.menu_rounded), label: 'المزيد'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBox() {
    final online = _online == true;
    final down = _online == false;
    final color = online ? MsdTokens.successFill : (down ? MsdTokens.danger : MsdTokens.faint);
    final label = online ? 'متصل' : (down ? 'غير متصل' : '—');
    final when = _boardAt == null ? '—' : hhmm(_boardAt!);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MsdTokens.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MsdTokens.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                Text('آخر تحديث $when', style: const TextStyle(fontSize: 12, color: MsdTokens.mintWash)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(String icon, String label, {required String id}) {
    final selected = _section == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? MsdTokens.mintLine : MsdTokens.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _openNamed(id),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? MsdTokens.mintLine : MsdTokens.transparent),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? MsdTokens.mintLine : MsdTokens.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: CmdIcon(icon, size: 18, color: selected ? MsdTokens.sky : MsdTokens.mintWash),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14,
                    color: selected ? MsdTokens.onDeep : MsdTokens.mist,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
