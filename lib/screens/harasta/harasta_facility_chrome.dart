import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Facility tabs share Harasta hub / drawer palette.
abstract final class Hp {
  static const ink = MsdColors.ink;
  static const sub = MsdColors.sub;
  static const faint = MsdColors.faint;
  static const line = MsdColors.line;
  static const drawerDeep = Color(0xFF0F2F36);
  static const drawerMid = Color(0xFF16464F);
  static const drawerAccent = Color(0xFF0E8A82);
  static const mint = Color(0xFF5EE0C4);
  /// App bar + selected chips — same family as drawer / hero gradient.
  static const appBar = drawerDeep;
  static const teal = drawerMid;
  static const data = drawerAccent;
  static const cyan = MsdColors.cyan;
  static const amber = MsdColors.amber;
  static const ok = MsdColors.green;
  static const surface = MsdColors.mist;
  static const page = MsdColors.mist;
}

class HpPage extends StatelessWidget {
  const HpPage({super.key, required this.children, this.onRefresh});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    );
    return ColoredBox(
      color: Hp.page,
      child: onRefresh == null
          ? list
          : RefreshIndicator(color: Hp.teal, onRefresh: onRefresh!, child: list),
    );
  }
}

/// Gradient intro — same family as Harasta side-drawer header.
/// Title is omitted: AppBar already names the tab.
class HpIntro extends StatelessWidget {
  const HpIntro({
    super.key,
    required this.eyebrow,
    required this.lead,
    this.actions = const [],
  });

  final String eyebrow;
  final String lead;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Hp.drawerDeep, Hp.drawerMid, Color(0xFF0B6F6A)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x660F2F36), blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.center,
                  colors: [Hp.drawerAccent.withValues(alpha: 0.22), Colors.transparent],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: GoogleFonts.tajawal(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.55,
                  color: const Color(0xFF9FD8CF),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lead,
                style: GoogleFonts.tajawal(
                  fontSize: 15,
                  height: 1.5,
                  color: const Color(0xFFF2F9F6),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class HpPanel extends StatelessWidget {
  const HpPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33A8D4E6)),
        boxShadow: const [BoxShadow(color: Color(0x1A1A6B8A), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class HpSectionHead extends StatelessWidget {
  const HpSectionHead({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800, color: Hp.ink)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: GoogleFonts.tajawal(fontSize: 12.5, color: Hp.sub, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class HpChips extends StatelessWidget {
  const HpChips({super.key, required this.value, required this.options, required this.onChanged});
  final String? value;
  final List<(String? id, String label)> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final o in options)
          GestureDetector(
            onTap: () => onChanged(o.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: value == o.$1 ? Hp.teal : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: value == o.$1 ? Hp.teal : const Color(0x33A8D4E6)),
              ),
              child: Text(
                o.$2,
                style: GoogleFonts.tajawal(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: value == o.$1 ? Colors.white : Hp.sub,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class HpUnitRow extends StatelessWidget {
  const HpUnitRow({super.key, required this.title, required this.subtitle, this.badge});
  final String title;
  final String subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Hp.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33A8D4E6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 14, color: Hp.ink)),
                const SizedBox(height: 3),
                Text(subtitle, style: GoogleFonts.tajawal(fontSize: 12.5, color: Hp.sub, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Hp.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Hp.teal.withValues(alpha: 0.28)),
              ),
              child: Text(badge!, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w800, color: Hp.teal)),
            ),
        ],
      ),
    );
  }
}

class HpFloorCard extends StatelessWidget {
  const HpFloorCard({
    super.key,
    required this.floor,
    required this.side,
    required this.unit,
    required this.note,
  });

  final String floor;
  final String side;
  final String unit;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33A8D4E6)),
        boxShadow: const [BoxShadow(color: Color(0x1A1A6B8A), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Hp.drawerMid, Hp.drawerDeep],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(floor, style: GoogleFonts.tajawal(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white)),
                if (side.isNotEmpty)
                  Text(side, style: GoogleFonts.tajawal(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFBFE6E2))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(unit, style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 15, color: Hp.ink)),
                const SizedBox(height: 3),
                Text(note, style: GoogleFonts.tajawal(fontSize: 12.5, color: Hp.sub, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HpStaffCard extends StatelessWidget {
  const HpStaffCard({super.key, required this.label, required this.value, required this.bar});
  final String label;
  final int value;
  final double bar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33A8D4E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.tajawal(fontSize: 12.5, fontWeight: FontWeight.w700, color: Hp.sub)),
          const SizedBox(height: 4),
          Text('$value', style: GoogleFonts.tajawal(fontSize: 26, fontWeight: FontWeight.w900, color: Hp.ink)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: bar.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0x331A6B8A),
              color: Hp.teal,
            ),
          ),
        ],
      ),
    );
  }
}

class HpOpsCard extends StatelessWidget {
  const HpOpsCard({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.tone,
  });
  final String label;
  final String value;
  final String? detail;
  /// Optional accent: emergency | special | calm | null
  final String? tone;

  Color get _valueColor => switch (tone) {
        'emergency' => const Color(0xFFCF5A52),
        'special' => Hp.amber,
        'calm' => Hp.data,
        _ => Hp.ink,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33A8D4E6)),
        boxShadow: const [BoxShadow(color: Color(0x140F2F36), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.tajawal(fontSize: 11.5, color: Hp.faint, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w900, color: _valueColor, height: 1.05)),
          if (detail != null) ...[
            const SizedBox(height: 3),
            Text(detail!, style: GoogleFonts.tajawal(fontSize: 11, color: Hp.cyan, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

class HpPill extends StatelessWidget {
  const HpPill({super.key, required this.label, this.tone = 'neutral'});
  final String label;
  final String tone; // neutral | emergency | special | ok | muted

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color border) = switch (tone) {
      'emergency' => (const Color(0x1ACF5A52), const Color(0xFFB42318), const Color(0x40CF5A52)),
      'special' => (const Color(0x1AC0913A), const Color(0xFF8A6A28), const Color(0x40C0913A)),
      'ok' => (const Color(0x1A0E8A82), Hp.data, const Color(0x400E8A82)),
      'muted' => (const Color(0x1416464F), Hp.sub, const Color(0x2216464F)),
      _ => (const Color(0x1416464F), Hp.teal, const Color(0x3316464F)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(label, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

/// Patient-file row for follow-up boards (scan: id → name → status → place).
class HpFileCard extends StatelessWidget {
  const HpFileCard({
    super.key,
    required this.caseNumber,
    required this.patientName,
    required this.entryType,
    required this.status,
    required this.location,
  });

  final String caseNumber;
  final String patientName;
  final String entryType;
  final String status;
  final String location;

  String get _kindTone {
    final t = entryType;
    if (t.contains('إسعاف')) return 'emergency';
    if (t.contains('خاص')) return 'special';
    if (t.contains('حجز')) return 'ok';
    return 'neutral';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33A8D4E6)),
        boxShadow: const [BoxShadow(color: Color(0x120F2F36), blurRadius: 16, offset: Offset(0, 7))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Hp.drawerDeep,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  caseNumber.isEmpty ? '—' : caseNumber,
                  style: GoogleFonts.tajawal(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFFF2F9F6), letterSpacing: 0.2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  patientName.isEmpty ? 'بدون اسم' : patientName,
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 15, color: Hp.ink, height: 1.25),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (entryType.isNotEmpty) HpPill(label: entryType, tone: _kindTone),
            ],
          ),
          if (status.isNotEmpty || location.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (status.isNotEmpty) ...[
                  Icon(Icons.circle, size: 7, color: Hp.data),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      status,
                      style: GoogleFonts.tajawal(fontSize: 12.5, fontWeight: FontWeight.w700, color: Hp.sub, height: 1.35),
                    ),
                  ),
                ],
                if (status.isNotEmpty && location.isNotEmpty) const SizedBox(width: 10),
                if (location.isNotEmpty)
                  Flexible(
                    child: Text(
                      location,
                      textAlign: TextAlign.end,
                      style: GoogleFonts.tajawal(fontSize: 12.5, fontWeight: FontWeight.w600, color: Hp.faint, height: 1.35),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class HpListTile extends StatelessWidget {
  const HpListTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.accent = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent ? const Color(0x14C0913A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent ? const Color(0x59C0913A) : const Color(0x33A8D4E6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 14, color: Hp.ink)),
                const SizedBox(height: 3),
                Text(subtitle, style: GoogleFonts.tajawal(fontSize: 12.5, height: 1.4, color: Hp.sub, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: child),
    );
  }
}
