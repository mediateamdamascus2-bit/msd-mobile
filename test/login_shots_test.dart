import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:msd_mobile/api_client.dart';
import 'package:msd_mobile/main.dart';
import 'package:msd_mobile/services/settings_store.dart';

class _ShotApi extends ApiClient {
  @override
  Future<bool> serverReachable() async => false;

  @override
  Future<Map<String, dynamic>> login(String username, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    throw Exception('تعذّر الاتصال بالخادم');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsStore.instance.init();
    final loader = FontLoader('Tajawal');
    for (final file in const [
      'assets/fonts/Tajawal-Regular.ttf',
      'assets/fonts/Tajawal-Medium.ttf',
      'assets/fonts/Tajawal-Bold.ttf',
      'assets/fonts/Tajawal-ExtraBold.ttf',
    ]) {
      loader.addFont(rootBundle.load(file));
    }
    await loader.load();
  });

  testWidgets('login frames at 360x640 and text scale 1.3', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(MsdApp(api: _ShotApi()));
    await tester.pump();
    await tester.runAsync(
      () => precacheImage(const AssetImage('assets/logo.png'), tester.element(find.byType(MsdApp))),
    );
    await tester.pump();
    await expectLater(find.byType(MsdApp), matchesGoldenFile('goldens/splash.png'));

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('وزارة الداخلية'), findsOneWidget);
    expect(find.text('نسيت كلمة المرور؟ راجع مسؤول النظام'), findsOneWidget);
    expect(find.text('الخادم غير متاح'), findsOneWidget);
    await expectLater(find.byType(MsdApp), matchesGoldenFile('goldens/login_empty.png'));

    await tester.enterText(find.byType(TextField).at(0), 'user');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pump();
    await expectLater(find.byType(MsdApp), matchesGoldenFile('goldens/login_loading.png'));

    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('تعذّر الاتصال بالخادم'), findsWidgets);
    await expectLater(find.byType(MsdApp), matchesGoldenFile('goldens/login_error.png'));
  });
}
