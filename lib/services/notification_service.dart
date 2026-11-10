import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'settings_store.dart';

/// Local notifications now; FCM/API push will plug in later.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  int _id = 1000;

  Future<void> init() async {
    if (kIsWeb) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'msd_ops',
        'تنبيهات العمليات',
        description: 'أحداث طبية، أسطول، وتنبيهات النظام',
        importance: Importance.high,
      ),
    );

    _ready = true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  Future<void> showDemo({
    required String title,
    required String body,
  }) async {
    final settings = SettingsStore.instance;
    if (!settings.notifySystem && !settings.notifyEvents) return;
    await _show(title, body);
  }

  /// New medical events found by a periodic refresh («أحداث طبية عاجلة» setting).
  Future<void> newEvents(List<String> titles, {String? where}) async {
    if (titles.isEmpty || !SettingsStore.instance.notifyEvents) return;
    final body = titles.length == 1 ? titles.first : '${titles.length} أحداث جديدة: ${titles.take(3).join('، ')}';
    await _show(where == null ? 'حدث طبي جديد' : 'حدث طبي جديد · $where', body);
  }

  /// New patients in a queue («مرضى جدد في الطابور» setting).
  Future<void> newPatients(List<String> names, {required String where}) async {
    if (names.isEmpty || !SettingsStore.instance.notifyPatients) return;
    final body = names.length == 1 ? names.first : '${names.length} مرضى جدد: ${names.take(3).join('، ')}';
    await _show('مريض جديد · $where', body);
  }

  Future<void> _show(String title, String body) async {
    if (!_ready || kIsWeb) return;
    await _plugin.show(
      _id++,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'msd_ops',
          'تنبيهات العمليات',
          channelDescription: 'أحداث طبية، أسطول، وتنبيهات النظام',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
