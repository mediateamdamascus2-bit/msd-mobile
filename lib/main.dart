import 'dart:convert';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'post_login_home.dart';
import 'screens/native_login_screen.dart';
import 'services/notification_service.dart';
import 'services/settings_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsStore.instance.init();
  await NotificationService.instance.init();

  final api = ApiClient();
  await api.loadToken();

  Map<String, dynamic>? user;
  if (api.isLoggedIn) {
    try {
      user = await api.me();
      await SettingsStore.instance.setUserJson(jsonEncode(user));
      await SettingsStore.instance.setDisplayName(
        user['displayNameAr']?.toString() ?? user['username']?.toString() ?? 'مستخدم',
      );
    } catch (_) {
      // Server down → cached user; token rejected (logout already cleared it) → login.
      final cached = api.isLoggedIn ? SettingsStore.instance.userJson : null;
      if (!api.isLoggedIn) await SettingsStore.instance.setUserJson(null);
      if (cached != null) {
        try {
          user = jsonDecode(cached) as Map<String, dynamic>;
        } catch (_) {
          await api.logout();
          user = null;
        }
      } else {
        await api.logout();
      }
    }
  }

  runApp(MsdApp(api: api, initialUser: user));
}

class MsdApp extends StatefulWidget {
  const MsdApp({super.key, required this.api, required this.initialUser});

  final ApiClient api;
  final Map<String, dynamic>? initialUser;

  @override
  State<MsdApp> createState() => _MsdAppState();
}

class _MsdAppState extends State<MsdApp> {
  late ApiClient _api;
  Map<String, dynamic>? _user;
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _api = widget.api;
    _user = widget.initialUser;
    ApiClient.onSessionExpired = _onSessionExpired;
  }

  @override
  void dispose() {
    if (ApiClient.onSessionExpired == _onSessionExpired) ApiClient.onSessionExpired = null;
    super.dispose();
  }

  /// Several in-flight requests can hit 401 together — only the first one acts.
  void _onSessionExpired(String message) {
    if (!mounted || _user == null) return;
    SettingsStore.instance.setUserJson(null);
    _navigatorKey.currentState?.popUntil((r) => r.isFirst);
    setState(() => _user = null);
    final text = message == ApiClient.accountDisabledMessage
        ? message
        : 'انتهت الجلسة — سجّل الدخول من جديد';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    });
  }

  Future<void> _onLoggedIn(Map<String, dynamic> payload) async {
    final user = payload['user'];
    final map = user is Map<String, dynamic>
        ? user
        : Map<String, dynamic>.from(user as Map);
    await SettingsStore.instance.setUserJson(jsonEncode(map));
    await SettingsStore.instance.setDisplayName(
      map['displayNameAr']?.toString() ?? map['username']?.toString() ?? 'مستخدم',
    );
    if (!mounted) return;
    setState(() => _user = map);
  }

  Future<void> _logout() async {
    await _api.logout();
    await SettingsStore.instance.setUserJson(null);
    if (!mounted) return;
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      title: 'إدارة الخدمات الطبية',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: _user == null
          ? NativeLoginScreen(api: _api, onLoggedIn: _onLoggedIn)
          : buildPostLoginHome(api: _api, user: _user!, onLogout: _logout),
    );
  }
}
