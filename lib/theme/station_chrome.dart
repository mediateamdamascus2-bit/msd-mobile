import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Soft medical mist + subtle geometric lattice (not a flat grey fill).
class StationBackdrop extends StatelessWidget {
  const StationBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            MsdTokens.mintWash,
            MsdTokens.paper,
            MsdTokens.mist,
          ],
        ),
      ),
      child: CustomPaint(
        painter: const _LatticePainter(),
        child: child,
      ),
    );
  }
}

class _LatticePainter extends CustomPainter {
  const _LatticePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MsdTokens.cyanWash
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const step = 28.0;
    for (double x = 0; x < size.width + step; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x - size.height * 0.35, size.height), paint);
    }
    for (double y = -size.width; y < size.height + step; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + size.width * 0.35), paint);
    }

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          MsdTokens.cyanWash,
          MsdTokens.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.85, 40), radius: 160));
    canvas.drawCircle(Offset(size.width * 0.85, 40), 160, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StationSection extends StatelessWidget {
  const StationSection({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MsdColors.line),
        boxShadow: const [
          BoxShadow(
            color: MsdTokens.lineSoft,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        color: MsdColors.cyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: MsdColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Hospital mark — letter H (replaces medical cross glyphs).
class MedicalMark extends StatelessWidget {
  const MedicalMark({super.key, this.size = 56, this.filled = true});

  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (!filled) {
      return SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.22),
            border: Border.all(color: MsdColors.cyan, width: size * 0.07),
          ),
          child: Center(
            child: Text(
              'H',
              style: TextStyle(
                color: MsdColors.cyan,
                fontSize: size * 0.52,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MsdTokens.cyan, MsdTokens.cyan, MsdTokens.teal],
          ),
          boxShadow: const [
            BoxShadow(
              color: MsdTokens.deepWash,
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Center(
          child: Text(
            'H',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.96),
              fontSize: size * 0.48,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class StationHero extends StatelessWidget {
  const StationHero({
    super.key,
    required this.brand,
    required this.headline,
    required this.subtitle,
    this.onLogout,
  });

  final String brand;
  final String headline;
  final String subtitle;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [MsdTokens.deep, MsdTokens.cyan, MsdTokens.deep],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -8,
            top: -18,
            child: Opacity(
              opacity: 0.22,
              child: Transform.rotate(
                angle: -math.pi / 10,
                child: const MedicalMark(size: 110),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MedicalMark(size: 54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      brand,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                  ),
                  if (onLogout != null)
                    IconButton(
                      onPressed: onLogout,
                      tooltip: 'خروج',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                headline,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: MsdTokens.mintWash,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: MsdTokens.mintWash,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StationTabs extends StatelessWidget {
  const StationTabs({
    super.key,
    required this.newSelected,
    required this.listCount,
    required this.onNew,
    required this.onList,
  });

  final bool newSelected;
  final int listCount;
  final VoidCallback onNew;
  final VoidCallback onList;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MsdColors.line),
      ),
      child: Row(
        children: [
          Expanded(child: _TabBtn(label: 'حجز جديد', selected: newSelected, onTap: onNew)),
          Expanded(
            child: _TabBtn(
              label: 'حجوزات الإدارة ($listCount)',
              selected: !newSelected,
              onTap: onList,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? MsdColors.cyan : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? Colors.white : MsdColors.sub,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SuccessBanner extends StatelessWidget {
  const SuccessBanner({
    super.key,
    required this.message,
    required this.codes,
  });

  final String message;
  final List<Map<String, dynamic>> codes;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MsdTokens.successWash,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MsdTokens.successWash),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: MsdColors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: MsdColors.green,
                    ),
                  ),
                ),
              ],
            ),
            ...codes.map((b) {
              final code = '${b['code'] ?? ''}';
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${b['patientName']} · ${b['slot']}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: MsdColors.ink,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: MsdColors.deepMid,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        code,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: MsdTokens.mintWash,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
