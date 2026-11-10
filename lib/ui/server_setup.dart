import 'package:flutter/material.dart';

import '../config.dart';
import 'msd_notify.dart';

/// Release builds hide «إعداد الخادم» unless the user enters the build-time code.
abstract final class ServerSetup {
  static Future<bool> unlock(BuildContext context) async {
    if (!AppConfig.serverSetupLocked) return true;
    if (!AppConfig.serverSetupAvailable) return false;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعداد الخادم'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'رمز الإعداد'),
          onSubmitted: (_) => Navigator.of(ctx).pop(ctrl.text == AppConfig.serverSetupCode),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text == AppConfig.serverSetupCode),
            child: const Text('فتح'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (ok == true) return true;
    if (ok == false && context.mounted) await MsdNotify.error(context, 'رمز الإعداد غير صحيح');
    return false;
  }

  /// Returns an error message, or null when the URL is acceptable for this build.
  static String? validate(String url) {
    final u = url.trim();
    final parsed = Uri.tryParse(u);
    if (u.isEmpty || parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return 'أدخل عنوان خادم صالحاً';
    }
    if (!AppConfig.isAllowedBase(u)) {
      return AppConfig.serverSetupLocked
          ? 'يجب أن يبدأ عنوان الخادم بـ https:// في نسخة الإصدار'
          : 'في وضع التطوير يُسمح بـ HTTP لعناوين الشبكة المحلية فقط';
    }
    return null;
  }
}
