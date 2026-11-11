import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:msd_mobile/api_client.dart';
import 'package:msd_mobile/l10n/arabic_digits.dart';
import 'package:msd_mobile/main.dart';
import 'package:msd_mobile/screens/splash_screen.dart';
import 'package:msd_mobile/services/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsStore.instance.init();
  });

  testWidgets('shows API login after the splash', (tester) async {
    await tester.pumpWidget(MsdApp(api: ApiClient()));
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('تسجيل الدخول'), findsOneWidget);

    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pump();
    expect(find.text('أدخل اسم المستخدم'), findsOneWidget);
    expect(find.text('أدخل كلمة المرور'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
  });

  test('date and number formats keep latin digits', () async {
    final loc = await const ArabicLatinMaterialLocalizationsDelegate().load(const Locale('ar'));
    final digits = loc.formatDecimal(2026);
    expect(RegExp(r'[٠-٩]').hasMatch(digits), isFalse);
    expect(digits, contains('026'));
    final stamp = loc.formatCompactDate(DateTime(2026, 11, 10));
    expect(RegExp(r'[٠-٩]').hasMatch(stamp), isFalse);
    expect(stamp, contains('2026'));
    final hour = loc.formatHour(const TimeOfDay(hour: 9, minute: 5));
    expect(RegExp(r'[٠-٩]').hasMatch(hour), isFalse);
    expect(hour, contains('9'));
  });
}
