import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum MsdButtonKind { primary, secondary, danger }

class MsdButton extends StatelessWidget {
  const MsdButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = MsdButtonKind.primary,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final MsdButtonKind kind;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bg = switch (kind) {
      MsdButtonKind.primary => MsdTokens.teal,
      MsdButtonKind.secondary => MsdTokens.white,
      MsdButtonKind.danger => MsdTokens.danger,
    };
    final fg = kind == MsdButtonKind.secondary ? MsdTokens.teal : MsdTokens.white;
    final child = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Text(label);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    if (kind == MsdButtonKind.secondary) {
      return OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          disabledForegroundColor: fg,
          minimumSize: const Size(48, 52),
          side: const BorderSide(color: MsdTokens.cyan),
          shape: shape,
          textStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800, fontSize: 15),
        ),
        child: child,
      );
    }
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg,
        disabledForegroundColor: fg,
        minimumSize: const Size(48, 52),
        shape: shape,
        textStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800, fontSize: 15),
      ),
      child: child,
    );
  }
}

class MsdCard extends StatelessWidget {
  const MsdCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MsdTokens.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MsdTokens.line),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class MsdEmptyState extends StatelessWidget {
  const MsdEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: MsdTokens.faint),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: MsdTokens.sub, height: 1.4),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class MsdErrorState extends StatelessWidget {
  const MsdErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MsdEmptyState(
      icon: Icons.cloud_off_outlined,
      title: message,
      action: onRetry == null
          ? null
          : MsdButton(label: 'إعادة المحاولة', onPressed: onRetry),
    );
  }
}

/// Quiet placeholder blocks used while a screen is loading.
class MsdLoading extends StatefulWidget {
  const MsdLoading({super.key, this.rows = 4});

  final int rows;

  @override
  State<MsdLoading> createState() => _MsdLoadingState();
}

class _MsdLoadingState extends State<MsdLoading> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_pulse),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            for (var i = 0; i < widget.rows; i++) ...[
              Container(
                height: 64,
                decoration: BoxDecoration(
                  color: MsdTokens.pageDeep,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class MsdStatusChip extends StatelessWidget {
  const MsdStatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
