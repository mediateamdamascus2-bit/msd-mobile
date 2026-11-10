import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:msd_mobile/api_client.dart';
import 'package:msd_mobile/main.dart';
import 'package:msd_mobile/services/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsStore.instance.init();
  });

  testWidgets('shows API login', (tester) async {
    await tester.pumpWidget(MsdApp(api: ApiClient(), initialUser: null));
    await tester.pump();
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });
}
