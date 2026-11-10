import 'dart:io';

import 'package:flutter/foundation.dart';

class AppConfig {
  /// Blazor / API host.
  /// Debug: Android emulator → 10.0.2.2 maps to the host PC; a physical phone
  /// can point at the PC LAN IP from «إعداد الخادم».
  /// Release: must be supplied with `--dart-define=API_BASE=https://…`.
  static String get defaultApiBaseUrl {
    if (kReleaseMode) return '';
    if (kIsWeb) return 'http://127.0.0.1:5148';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:5148';
    } catch (_) {}
    return 'http://127.0.0.1:5148';
  }

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: '', // empty → use defaultApiBaseUrl / Settings
  );

  /// Unlocks «إعداد الخادم» in release builds. Empty → the setting stays hidden.
  static const serverSetupCode = String.fromEnvironment('SERVER_SETUP_CODE');

  /// Server setup is always visible in debug; in release only behind [serverSetupCode].
  static bool get serverSetupLocked => kReleaseMode;
  static bool get serverSetupAvailable => !kReleaseMode || serverSetupCode.isNotEmpty;

  /// Release builds only talk to HTTPS hosts.
  /// Debug builds may use HTTP, and only for a local-network host.
  static bool isAllowedBase(String url) {
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null || parsed.host.isEmpty) return false;
    if (parsed.scheme == 'https') return true;
    if (parsed.scheme != 'http' || kReleaseMode) return false;
    return isLocalNetworkHost(parsed.host);
  }

  static bool isLocalNetworkHost(String host) {
    final name = host.trim().toLowerCase();
    if (name == 'localhost' || name == '::1' || name == '10.0.2.2' || name == '10.0.3.2') return true;
    final parts = name.split('.');
    if (parts.length != 4) return false;
    final numbers = <int>[];
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return false;
      numbers.add(n);
    }
    final a = numbers[0];
    final b = numbers[1];
    if (a == 10 || a == 127) return true;
    if (a == 192 && b == 168) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 169 && b == 254) return true;
    return false;
  }

  static String resolveApiBase(String? stored) {
    String clean(String v) => v.trim().replaceAll(RegExp(r'/+$'), '');
    final fromDefine = clean(apiBaseUrl);
    if (fromDefine.isNotEmpty && isAllowedBase(fromDefine)) return fromDefine;
    final fromStore = clean(stored ?? '');
    if (fromStore.isNotEmpty && isAllowedBase(fromStore)) return fromStore;
    return clean(defaultApiBaseUrl);
  }
}
