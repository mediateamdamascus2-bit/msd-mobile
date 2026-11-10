import 'package:flutter/material.dart';

import '../api_client.dart';
import '../config.dart';
import '../services/notification_service.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../ui/msd_notify.dart';
import '../ui/server_setup.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
  });

  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiCtrl = TextEditingController();
  late bool _events;
  late bool _fleet;
  late bool _system;
  late bool _patients;
  var _busy = false;
  var _serverUnlocked = !AppConfig.serverSetupLocked;
  String? _health;

  @override
  void initState() {
    super.initState();
    final s = SettingsStore.instance;
    _events = s.notifyEvents;
    _fleet = s.notifyFleet;
    _system = s.notifySystem;
    _patients = s.notifyPatients;
    _apiCtrl.text = s.apiBaseUrl;
    _checkHealth();
  }

  @override
  void dispose() {
    _apiCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkHealth() async {
    try {
      await widget.api.pingHealth();
      if (!mounted) return;
      setState(() => _health = 'الخادم متصل');
    } catch (e) {
      if (!mounted) return;
      setState(() => _health = 'غير متصل: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _saveApi() async {
    final err = ServerSetup.validate(_apiCtrl.text);
    if (err != null) {
      await MsdNotify.error(context, err);
      return;
    }
    setState(() => _busy = true);
    await SettingsStore.instance.setApiBaseUrl(_apiCtrl.text);
    await _checkHealth();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ عنوان الخادم')),
    );
  }

  Future<void> _testNotif() async {
    final ok = await NotificationService.instance.requestPermission();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يلزم السماح بالإشعارات من إعدادات الجهاز')),
      );
      return;
    }
    await NotificationService.instance.showDemo(
      title: 'إدارة الخدمات الطبية',
      body: 'إشعار تجريبي من التطبيق المرتبط بالـ API',
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['displayNameAr']?.toString() ?? widget.user['username']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(name),
              subtitle: Text(widget.user['username']?.toString() ?? ''),
              trailing: TextButton(onPressed: widget.onLogout, child: const Text('خروج')),
            ),
          ),
          const SizedBox(height: 18),
          Text('الخادم (API)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_health != null) ...[
            Text(_health!, style: TextStyle(color: MsdColors.sub, fontSize: 13)),
            const SizedBox(height: 8),
          ],
          if (!_serverUnlocked && AppConfig.serverSetupAvailable)
            OutlinedButton.icon(
              onPressed: () async {
                if (await ServerSetup.unlock(context) && mounted) setState(() => _serverUnlocked = true);
              },
              icon: const Icon(Icons.lock_outline),
              label: const Text('إعداد الخادم (مقفل)'),
            ),
          if (_serverUnlocked) ...[
          TextField(
            controller: _apiCtrl,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'API Base URL',
              hintText: AppConfig.serverSetupLocked ? 'https://…' : 'http://10.0.2.2:5148',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _saveApi,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('حفظ وفحص'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _checkHealth,
                  child: const Text('فحص الاتصال'),
                ),
              ),
            ],
          ),
          ],
          const SizedBox(height: 24),
          Text('الإشعارات', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('أحداث طبية عاجلة'),
                  value: _events,
                  onChanged: (v) async {
                    setState(() => _events = v);
                    await SettingsStore.instance.setNotifyEvents(v);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('مرضى جدد في الطابور'),
                  value: _patients,
                  onChanged: (v) async {
                    setState(() => _patients = v);
                    await SettingsStore.instance.setNotifyPatients(v);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('حركة الأسطول'),
                  value: _fleet,
                  onChanged: (v) async {
                    setState(() => _fleet = v);
                    await SettingsStore.instance.setNotifyFleet(v);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('تنبيهات النظام'),
                  value: _system,
                  onChanged: (v) async {
                    setState(() => _system = v);
                    await SettingsStore.instance.setNotifySystem(v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _testNotif,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('تجربة إشعار محلي'),
          ),
          const SizedBox(height: 24),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('إدارة الخدمات الطبية'),
              subtitle: Text('تطبيق Flutter · مرتبط بـ API الموقع\nإصدار 1.0.0 (2)'),
            ),
          ),
        ],
      ),
    );
  }
}