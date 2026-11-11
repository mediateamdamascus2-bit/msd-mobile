import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../ui/msd_components.dart';

/// First frame after the native splash. Does not call the network itself.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = message != null;
    return Scaffold(
      backgroundColor: MsdTokens.page,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'شعار إدارة الخدمات الطبية',
                  image: true,
                  child: Image.asset(
                    'assets/logo.png',
                    width: 96,
                    height: 96,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'إدارة الخدمات الطبية',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 28),
                if (!failed)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: MsdTokens.teal),
                  )
                else ...[
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, height: 1.4, color: MsdTokens.danger),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 16),
                    MsdButton(label: 'إعادة المحاولة', onPressed: onRetry),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
