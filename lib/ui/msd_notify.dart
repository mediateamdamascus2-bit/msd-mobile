import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Popup notifications for errors / success (replaces inline alert strips).
abstract final class MsdNotify {
  static Future<void> error(BuildContext context, String message) {
    return _show(
      context,
      title: 'تنبيه',
      message: message,
      color: MsdColors.danger,
      icon: Icons.error_outline,
    );
  }

  static Future<void> success(BuildContext context, String message) {
    return _show(
      context,
      title: 'تم',
      message: message,
      color: MsdColors.green,
      icon: Icons.check_circle_outline,
    );
  }

  static Future<void> _show(
    BuildContext context, {
    required String title,
    required String message,
    required Color color,
    required IconData icon,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: MsdColors.ink),
              ),
            ),
          ],
        ),
        content: Text(
          message.replaceFirst('Exception: ', ''),
          style: GoogleFonts.tajawal(height: 1.45, color: MsdColors.sub, fontWeight: FontWeight.w600),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(backgroundColor: color),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}
