import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

class MsdPill extends StatelessWidget {
  const MsdPill({
    super.key,
    required this.label,
    this.tone = MsdPillTone.sky,
  });

  final String label;
  final MsdPillTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      MsdPillTone.sky => (const Color(0x294BA3C7), MsdColors.teal),
      MsdPillTone.amber => (const Color(0x33C0913A), const Color(0xFF8A6420)),
      MsdPillTone.green => (const Color(0x292E9E6C), MsdColors.green),
      MsdPillTone.danger => (const Color(0x29B42318), MsdColors.danger),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.tajawal(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

enum MsdPillTone { sky, amber, green, danger }

class MsdSegmented extends StatelessWidget {
  const MsdSegmented({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftSelected,
    required this.onLeft,
    required this.onRight,
  });

  final String leftLabel;
  final String rightLabel;
  final bool leftSelected;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x147EC8E3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x334BA3C7)),
      ),
      child: Row(
        children: [
          Expanded(child: _seg(leftLabel, leftSelected, onLeft)),
          Expanded(child: _seg(rightLabel, !leftSelected, onRight)),
        ],
      ),
    );
  }

  Widget _seg(String label, bool on, VoidCallback tap) {
    return Material(
      color: on ? MsdColors.teal : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: on ? Colors.white : MsdColors.sub,
            ),
          ),
        ),
      ),
    );
  }
}

class MsdFieldShell extends StatelessWidget {
  const MsdFieldShell({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 6),
          child: Text(
            label,
            style: GoogleFonts.tajawal(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MsdColors.teal,
              letterSpacing: 0.1,
            ),
          ),
        ),
        child,
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: GoogleFonts.tajawal(fontSize: 11, color: MsdColors.faint),
          ),
        ],
      ],
    );
  }
}

InputDecoration msdInputDecoration({
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool enabled = true,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: Color(0x334BA3C7)),
  );
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: enabled ? Colors.white : const Color(0x66EAF6FB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border,
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: MsdColors.cyan, width: 1.8),
    ),
    hintStyle: GoogleFonts.tajawal(color: MsdColors.faint, fontSize: 13),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
  );
}

class MsdPrimaryButton extends StatelessWidget {
  const MsdPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.tone = MsdPrimaryTone.teal,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final MsdPrimaryTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      MsdPrimaryTone.teal => MsdColors.teal,
      MsdPrimaryTone.amber => MsdColors.amber,
      MsdPrimaryTone.danger => MsdColors.danger,
      MsdPrimaryTone.cyan => MsdColors.cyan,
    };

    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          shadowColor: color.withValues(alpha: 0.35),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

enum MsdPrimaryTone { teal, amber, danger, cyan }

/// Outlined H mark used instead of hospital/cross icons in form fields.
class MsdHIcon extends StatelessWidget {
  const MsdHIcon({super.key, this.size = 22, this.color = MsdColors.cyan});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
          border: Border.all(color: color, width: size * 0.08),
        ),
        child: Center(
          child: Text(
            'H',
            style: TextStyle(
              color: color,
              fontSize: size * 0.58,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
