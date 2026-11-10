import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Local app preferences (no API required).
class SettingsStore {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const _kNotifEvents = 'notif_events';
  static const _kNotifFleet = 'notif_fleet';
  static const _kNotifSystem = 'notif_system';
  static const _kApiBase = 'api_base_url';
  static const _kDemoUser = 'demo_display_name';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    final p = _prefs;
    if (p == null) {
      throw StateError('SettingsStore.init() must be called first');
    }
    return p;
  }

  bool get notifyEvents => _p.getBool(_kNotifEvents) ?? true;
  bool get notifyFleet => _p.getBool(_kNotifFleet) ?? true;
  bool get notifySystem => _p.getBool(_kNotifSystem) ?? true;

  Future<void> setNotifyEvents(bool v) => _p.setBool(_kNotifEvents, v);
  Future<void> setNotifyFleet(bool v) => _p.setBool(_kNotifFleet, v);
  Future<void> setNotifySystem(bool v) => _p.setBool(_kNotifSystem, v);

  static const _kNotifPatients = 'notif_patients';
  bool get notifyPatients => _p.getBool(_kNotifPatients) ?? true;
  Future<void> setNotifyPatients(bool v) => _p.setBool(_kNotifPatients, v);

  String get apiBaseUrl => AppConfig.resolveApiBase(_p.getString(_kApiBase));

  Future<void> setApiBaseUrl(String v) => _p.setString(_kApiBase, v.trim());

  String get displayName => _p.getString(_kDemoUser) ?? 'مستخدم';
  Future<void> setDisplayName(String v) => _p.setString(_kDemoUser, v.trim());

  static const _kUserJson = 'msd_user_json';

  String? get userJson => _p.getString(_kUserJson);
  Future<void> setUserJson(String? v) async {
    if (v == null || v.isEmpty) {
      await _p.remove(_kUserJson);
    } else {
      await _p.setString(_kUserJson, v);
    }
  }
}
