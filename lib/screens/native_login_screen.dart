import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api_client.dart';
import '../config.dart';
import '../services/settings_store.dart';
import '../theme/tokens.dart';
import '../ui/msd_components.dart';
import '../ui/msd_text_field.dart';
import '../ui/server_setup.dart';

class NativeLoginScreen extends StatefulWidget {
  const NativeLoginScreen({
    super.key,
    required this.api,
    required this.onLoggedIn,
  });

  final ApiClient api;
  final Future<void> Function(Map<String, dynamic> payload) onLoggedIn;

  @override
  State<NativeLoginScreen> createState() => _NativeLoginScreenState();
}

class _NativeLoginScreenState extends State<NativeLoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _apiUrl = TextEditingController();
  var _busy = false;
  var _showServer = false;
  var _hidePass = true;
  String? _userError;
  String? _passError;
  String? _banner;
  bool? _serverUp;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _apiUrl.text = SettingsStore.instance.apiBaseUrl;
    unawaited(_loadVersion());
    unawaited(_checkServer());
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {}
  }

  Future<void> _checkServer() async {
    final up = await widget.api.serverReachable();
    if (mounted) setState(() => _serverUp = up);
  }

  Future<void> _toggleServer() async {
    if (!_showServer && !await ServerSetup.unlock(context)) return;
    if (!mounted) return;
    setState(() => _showServer = !_showServer);
  }

  Future<void> _enter() async {
    if (_busy) return;
    final username = _user.text.trim();
    final password = _pass.text;
    final userError = username.isEmpty ? 'أدخل اسم المستخدم' : null;
    final passError = password.isEmpty ? 'أدخل كلمة المرور' : null;
    if (userError != null || passError != null) {
      setState(() {
        _userError = userError;
        _passError = passError;
        _banner = null;
      });
      return;
    }
    if (_showServer) {
      final err = ServerSetup.validate(_apiUrl.text);
      if (err != null) {
        setState(() => _banner = err);
        return;
      }
    }
    setState(() {
      _busy = true;
      _banner = null;
      _userError = null;
      _passError = null;
    });
    try {
      if (_showServer) await SettingsStore.instance.setApiBaseUrl(_apiUrl.text.trim());
      final payload = await widget.api.login(username, password);
      TextInput.finishAutofillContext(shouldSave: true);
      await widget.onLoggedIn(payload);
    } catch (e) {
      if (!mounted) return;
      setState(() => _banner = _bannerText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _bannerText(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('مقفل') || text.contains('429') || text.contains('423')) {
      return 'الحساب مقفل مؤقتًا بعد محاولات كثيرة';
    }
    if (text.contains('معطّل')) return 'الحساب معطّل. راجع مسؤول النظام.';
    if (text.contains('غير صحيحة') || text.contains('401') || text.contains('خاطئة')) {
      return 'بيانات خاطئة';
    }
    return 'تعذّر الاتصال بالخادم';
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _apiUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = _serverUp == null
        ? MsdTokens.faint
        : _serverUp! ? MsdTokens.success : MsdTokens.danger;
    final dotLabel = _serverUp == null
        ? 'جارٍ فحص الخادم'
        : _serverUp! ? 'الخادم متاح' : 'الخادم غير متاح';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Semantics(
                          label: 'شعار إدارة الخدمات الطبية',
                          image: true,
                          child: Image.asset(
                            'assets/logo.png',
                            width: 96,
                            height: 96,
                            excludeFromSemantics: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'إدارة الخدمات الطبية',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'وزارة الداخلية',
                          style: TextStyle(fontSize: 15, color: MsdTokens.sub),
                        ),
                        const SizedBox(height: 18),
                        MsdCard(
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_banner != null) ...[
                                  _ErrorBanner(text: _banner!),
                                  const SizedBox(height: 12),
                                ],
                                MsdTextField(
                                  controller: _user,
                                  labelText: 'اسم المستخدم',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  textInputAction: TextInputAction.next,
                                  forceLtr: true,
                                  enabled: !_busy,
                                  errorText: _userError,
                                  autofillHints: const [AutofillHints.username],
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  textCapitalization: TextCapitalization.none,
                                  keyboardType: TextInputType.text,
                                  scrollPadding: const EdgeInsets.only(bottom: 140),
                                  onChanged: (_) {
                                    if (_userError != null) setState(() => _userError = null);
                                  },
                                ),
                                const SizedBox(height: 12),
                                MsdTextField(
                                  controller: _pass,
                                  labelText: 'كلمة المرور',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  obscureText: _hidePass,
                                  forceLtr: true,
                                  enabled: !_busy,
                                  errorText: _passError,
                                  autofillHints: const [AutofillHints.password],
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  textInputAction: TextInputAction.done,
                                  scrollPadding: const EdgeInsets.only(bottom: 140),
                                  onChanged: (_) {
                                    if (_passError != null) setState(() => _passError = null);
                                  },
                                  onSubmitted: (_) => _enter(),
                                  suffixIcon: IconButton(
                                    tooltip: _hidePass ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                                    onPressed: _busy ? null : () => setState(() => _hidePass = !_hidePass),
                                    icon: Icon(_hidePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                MsdButton(
                                  label: 'تسجيل الدخول',
                                  loading: _busy,
                                  onPressed: _enter,
                                ),
                                if (AppConfig.serverSetupAvailable) ...[
                                  const SizedBox(height: 4),
                                  TextButton(
                                    onPressed: _busy ? null : _toggleServer,
                                    child: Text(_showServer ? 'إخفاء إعداد الخادم' : 'إعداد الخادم (متقدم)'),
                                  ),
                                ],
                                if (_showServer) ...[
                                  const SizedBox(height: 8),
                                  MsdTextField(
                                    controller: _apiUrl,
                                    labelText: 'عنوان الخادم (API)',
                                    hintText: AppConfig.serverSetupLocked ? 'https://…' : 'http://10.0.2.2:5148',
                                    prefixIcon: const Icon(Icons.dns_outlined),
                                    forceLtr: true,
                                    enabled: !_busy,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'نسيت كلمة المرور؟ راجع مسؤول النظام',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: MsdTokens.sub),
                        ),
                        const SizedBox(height: 8),
                        if (_version.isNotEmpty)
                          Text(
                            'الإصدار $_version',
                            style: const TextStyle(fontSize: 12, color: MsdTokens.faint),
                          ),
                        const SizedBox(height: 8),
                        Semantics(
                          label: dotLabel,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(dotLabel, style: const TextStyle(fontSize: 12, color: MsdTokens.faint)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MsdTokens.dangerSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MsdTokens.danger.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: MsdTokens.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.35, color: MsdTokens.danger),
            ),
          ),
        ],
      ),
    );
  }
}
