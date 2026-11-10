import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../settings_screen.dart';

/// الإعدادات — opens the existing [SettingsScreen] (pushed with its own AppBar/back).
class OpsSettingsScreen extends StatelessWidget {
  const OpsSettingsScreen({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
  });

  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) =>
      SettingsScreen(api: api, user: user, onLogout: onLogout);
}
