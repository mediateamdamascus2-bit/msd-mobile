import 'package:flutter/material.dart';

import '../api_client.dart';
import '../config.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../ui/msd_notify.dart';
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

  @override
  void initState() {
    super.initState();
    _apiUrl.text = SettingsStore.instance.apiBaseUrl;
  }

  Future<void> _toggleServer() async {
    if (!_showServer && !await ServerSetup.unlock(context)) return;
    if (!mounted) return;
    setState(() => _showServer = !_showServer);
  }

  Future<void> _enter() async {
    if (_showServer) {
      final err = ServerSetup.validate(_apiUrl.text);
      if (err != null) {
        await MsdNotify.error(context, err);
        return;
      }
    }
    setState(() => _busy = true);
    try {
      if (_showServer) await SettingsStore.instance.setApiBaseUrl(_apiUrl.text.trim());
      final payload = await widget.api.login(_user.text.trim(), _pass.text);
      await widget.onLoggedIn(payload);
    } catch (e) {
      if (!mounted) return;
      await MsdNotify.error(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: MsdColors.deepMid,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.health_and_safety, color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'إدارة الخدمات الطبية',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'الدخول باسم المستخدم وكلمة المرور',
                    style: TextStyle(color: MsdColors.sub),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MsdTextField(
                            controller: _user,
                            labelText: 'اسم المستخدم',
                            prefixIcon: const Icon(Icons.person_outline),
                            textInputAction: TextInputAction.next,
                            forceLtr: true,
                          ),
                          const SizedBox(height: 12),
                          MsdTextField(
                            controller: _pass,
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline),
                            obscureText: true,
                            forceLtr: true,
                            onSubmitted: (_) => _enter(),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy ? null : _enter,
                            child: _busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('تسجيل الدخول'),
                          ),
                          if (AppConfig.serverSetupAvailable) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _toggleServer,
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
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
