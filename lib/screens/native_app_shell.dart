import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme/cmd_icon.dart';
import 'harasta_hub_screen.dart';
import 'hasia_hub_screen.dart';
import 'native_events_screen.dart';
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
import 'ops/ops_settings_screen.dart';
import 'ops/ops_training_screen.dart';
import 'ops/ops_units_screen.dart';
import 'ops/ops_warehouses_screen.dart';
import 'settings_screen.dart';
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

class _NativeAppShellState extends State<NativeAppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  var _index = 0;

  static const _teal = MsdTokens.cyan;
  static const _faint = MsdTokens.faint;
  static const _page = MsdTokens.page;
  static const _deep = MsdTokens.deep;

  void _openDrawer() => _scaffoldKey.currentState?.openEndDrawer();

  void _goTab(int i) {
    setState(() => _index = i);
    Navigator.of(context).maybePop();
  }

  /// Close the drawer, then push a full-screen read-only ops page (AppBar back returns to shell).
  void _openOps(Widget page) {
    final nav = Navigator.of(context);
    nav.pop(); // close endDrawer
    nav.push(MaterialPageRoute(builder: (_) => page));
  }

  void _openHasia() => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HasiaHubScreen(api: widget.api, user: widget.user, onLogout: widget.onLogout),
        ),
      );

  void _openHarasta() => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HarastaHubScreen(api: widget.api, user: widget.user, onLogout: widget.onLogout),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pages = [
      NativeHomeScreen(
        api: widget.api,
        user: widget.user,
        onLogout: widget.onLogout,
        onOpenMenu: _openDrawer,
      ),
      NativeEventsScreen(api: widget.api, user: widget.user),
      NeedsScreen(api: widget.api, user: widget.user),
      SettingsScreen(api: widget.api, user: widget.user, onLogout: widget.onLogout),
    ];

    final name = widget.user['displayNameAr']?.toString() ??
        widget.user['username']?.toString() ??
        '';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _page,
      endDrawer: Drawer(
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
                        errorBuilder: (_, __, ___) => Container(
                          width: 44,
                          height: 44,
                          color: Colors.white12,
                          child: const Icon(Icons.medical_services, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إدارة الخدمات الطبية',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: MsdTokens.onDeep),
                          ),
                          Text(
                            name.isEmpty ? 'COMMAND' : name,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MsdTokens.mintWash),
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
                    _drawerItem('home', 'الرئيسية', selected: _index == 0, onTap: () => _goTab(0)),
                    _drawerItem('pulse', 'الأحداث الطبية', onTap: () => _openOps(OpsEventsScreen(api: widget.api))),
                    _drawerItem('truck', 'الأسطول', onTap: () => _openOps(OpsFleetScreen(api: widget.api))),
                    _drawerItem(
                      'prison',
                      'صحة السجون',
                      onTap: () => _openOps(OpsPrisonsScreen(api: widget.api, onOpenHasia: _openHasia)),
                    ),
                    _drawerItem('kit', 'الوحدات الطبية', onTap: () => _openOps(OpsUnitsScreen(api: widget.api))),
                    _drawerItem('medcenter', 'مراكز الرعاية الطبية', onTap: () => _openOps(OpsCentersScreen(api: widget.api))),
                    _drawerItem(
                      'hospital',
                      'المشافي',
                      onTap: () => _openOps(OpsHospitalsScreen(api: widget.api, onOpenHarasta: _openHarasta)),
                    ),
                    _drawerItem('pin', 'الخريطة التفاعلية', onTap: () => _openOps(OpsMapScreen(api: widget.api))),
                    _drawerItem('box', 'المستودعات', onTap: () => _openOps(OpsWarehousesScreen(api: widget.api))),
                    _drawerItem('cap', 'التدريب والتطوير', onTap: () => _openOps(OpsTrainingScreen(api: widget.api))),
                    _drawerItem('user', 'القوى البشرية', onTap: () => _openOps(OpsHrScreen(api: widget.api))),
                    _drawerItem('chart', 'التقارير والإحصاءات', onTap: () => _openOps(OpsReportsScreen(api: widget.api))),
                    _drawerItem(
                      'gear',
                      'الإعدادات',
                      onTap: () => _openOps(
                        OpsSettingsScreen(api: widget.api, user: widget.user, onLogout: widget.onLogout),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: MsdTokens.successFill, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('النظام يعمل بشكل طبيعي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MsdTokens.onDeep)),
                            Text('SYNC · منذ دقيقة', style: TextStyle(fontSize: 12, color: MsdTokens.mintWash)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: widget.onLogout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MsdTokens.onDeep,
                      side: const BorderSide(color: MsdTokens.mintLine),
                      backgroundColor: _deep.withValues(alpha: 0.55),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
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
          backgroundColor: Colors.white,
          indicatorColor: MsdTokens.cyanWash,
          elevation: 0,
          height: 68,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? _teal : _faint,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(color: selected ? _teal : _faint, size: 22);
          }),
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: MsdTokens.tealWash)),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
              NavigationDestination(icon: Icon(Icons.monitor_heart_outlined), selectedIcon: Icon(Icons.monitor_heart), label: 'الأحداث'),
              NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'الاحتياجات'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(String icon, String label, {bool selected = false, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? MsdTokens.mintLine : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? MsdTokens.mintLine : Colors.transparent),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? MsdTokens.mintLine : Colors.white.withValues(alpha: 0.06),
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
