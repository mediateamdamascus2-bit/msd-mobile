import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'l10n/arabic_digits.dart';
import 'post_login_home.dart';
import 'screens/native_login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/settings_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsStore.instance.init();
  await NotificationService.instance.init();

  final api = ApiClient();
  await api.loadToken();
  runApp(MsdApp(api: api));
}

enum _Gate { splash, offline, login, home }

class MsdApp extends StatefulWidget {
  const MsdApp({super.key, required this.api});

  final ApiClient api;

  @override
  State<MsdApp> createState() => _MsdAppState();
}

class _MsdAppState extends State<MsdApp> {
  late ApiClient _api;
  Map<String, dynamic>? _user;
  var _gate = _Gate.splash;
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _api = widget.api;
    ApiClient.onSessionExpired = _onSessionExpired;
    _boot();
  }

  @override
  void dispose() {
    if (ApiClient.onSessionExpired == _onSessionExpired) ApiClient.onSessionExpired = null;
    super.dispose();
  }

  /// Local token check is instant. A stored session waits on `me()` for at most 6 seconds.
  Future<void> _boot() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    if (!_api.isLoggedIn) {
      setState(() => _gate = _Gate.login);
      return;
    }
    try {
      final user = await _api.me().timeout(const Duration(seconds: 6));
      await SettingsStore.instance.setUserJson(jsonEncode(user));
      await SettingsStore.instance.setDisplayName(
        user['displayNameAr']?.toString() ?? user['username']?.toString() ?? 'مستخدم',
      );
      if (!mounted) return;
      setState(() {
        _user = user;
        _gate = _Gate.home;
      });
    } on TimeoutException {
      if (mounted) setState(() => _gate = _Gate.offline);
    } catch (_) {
      if (!mounted) return;
      if (!_api.isLoggedIn) {
        await SettingsStore.instance.setUserJson(null);
        if (!mounted) return;
        setState(() => _gate = _Gate.login);
        return;
      }
      setState(() => _gate = _Gate.offline);
    }
  }

  Future<void> _retry() async {
    setState(() => _gate = _Gate.splash);
    await _boot();
  }

  /// Several in-flight requests can hit 401 together — only the first one acts.
  void _onSessionExpired(String message) {
    if (!mounted || _user == null) return;
    SettingsStore.instance.setUserJson(null);
    _navigatorKey.currentState?.popUntil((r) => r.isFirst);
    setState(() {
      _user = null;
      _gate = _Gate.login;
    });
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
    setState(() {
      _user = map;
      _gate = _Gate.home;
    });
  }

  Future<void> _logout() async {
    await _api.logout();
    await SettingsStore.instance.setUserJson(null);
    if (!mounted) return;
    setState(() {
      _user = null;
      _gate = _Gate.login;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      title: 'إدارة الخدمات الطبية',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: msdLocalizationsDelegates,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.3,
        child: child ?? const SizedBox.shrink(),
      ),
      home: switch (_gate) {
        _Gate.splash => const SplashScreen(),
        _Gate.offline => SplashScreen(
            message: 'تعذّر الاتصال بالخادم',
            onRetry: _retry,
          ),
        _Gate.login => NativeLoginScreen(api: _api, onLoggedIn: _onLoggedIn),
        _Gate.home => buildPostLoginHome(api: _api, user: _user!, onLogout: _logout),
      },
    );
  }
}
