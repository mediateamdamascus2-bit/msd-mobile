import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../api_client.dart';
import '../../data/harasta_catalog.dart';
import '../../theme/app_theme.dart';
import '../../ui/msd_notify.dart';

/// Follow-up boards — same Harasta hub / drawer palette as facility tabs.
abstract final class _Sv {
  static const ink = MsdColors.ink;
  static const sub = MsdColors.sub;
  static const faint = MsdColors.faint;
  static const line = MsdColors.line;
  static const drawerDeep = Color(0xFF0F2F36);
  static const drawerMid = Color(0xFF16464F);
  static const drawerAccent = Color(0xFF0E8A82);
  static const data = drawerMid;
  static const cyan = MsdColors.cyan;
  static const ok = MsdColors.green;
  static const mid = MsdColors.amber;
  static const high = Color(0xFFCF5A52);
  static const crit = MsdColors.danger;
  static const mist = MsdColors.mist;
  static const page = MsdColors.mist;
}

enum _Level { ok, mid, high, critical }

_Level _levelOf(int n) {
  if (n >= 5) return _Level.critical;
  if (n >= 3) return _Level.high;
  if (n > 0) return _Level.mid;
  return _Level.ok;
}

String _levelLabel(_Level l) => switch (l) {
      _Level.ok => 'مستقر',
      _Level.mid => 'متوسط',
      _Level.high => 'مرتفع',
      _Level.critical => 'حرج',
    };

Color _levelColor(_Level l) => switch (l) {
      _Level.ok => _Sv.ok,
      _Level.mid => _Sv.mid,
      _Level.high => _Sv.high,
      _Level.critical => _Sv.crit,
    };

// ─── Shared chrome matching web sv-* ─────────────────────────────────────────

/// Status hero — AppBar already carries the tab name (no repeated title).
class _SvHero extends StatelessWidget {
  const _SvHero({
    required this.lead,
    required this.note,
    required this.onRefresh,
    required this.busy,
    this.actions = const [],
  });

  final String lead;
  final String note;
  final VoidCallback onRefresh;
  final bool busy;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_Sv.drawerDeep, _Sv.drawerMid, Color(0xFF0B6F6A)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x990F2F36), blurRadius: 28, offset: Offset(0, 14))],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.center,
                  colors: [_Sv.drawerAccent.withValues(alpha: 0.22), Colors.transparent],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('متابعة المسؤول · بدون إدخال', style: GoogleFonts.tajawal(color: const Color(0xFF9FD8CF), fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(lead, style: GoogleFonts.tajawal(color: const Color(0xFFF2F9F6), fontSize: 16, height: 1.45, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(note, style: GoogleFonts.tajawal(color: const Color(0xE09FD8CF), fontSize: 12.5, height: 1.45, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SvBtn(
                    label: 'تحديث الآن',
                    ghost: true,
                    busy: busy,
                    onTap: busy ? null : onRefresh,
                  ),
                  ...actions,
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SvBtn extends StatelessWidget {
  const _SvBtn({required this.label, this.onTap, this.ghost = false, this.busy = false});
  final String label;
  final VoidCallback? onTap;
  final bool ghost;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ghost ? Colors.white.withValues(alpha: 0.10) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ghost ? Colors.white.withValues(alpha: 0.22) : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: ghost ? const Color(0xFFEEF5F3) : _Sv.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SvKpi extends StatelessWidget {
  const _SvKpi({required this.label, required this.value, required this.hint, this.kind});
  final String label;
  final String value;
  final String hint;
  final String? kind; // accent | alert | calm

  @override
  Widget build(BuildContext context) {
    final valueColor = switch (kind) {
      'accent' => _Sv.data,
      'alert' => _Sv.crit,
      'calm' => _Sv.ok,
      _ => _Sv.ink,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _Sv.line),
        boxShadow: const [BoxShadow(color: Color(0x331A6B8A), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.tajawal(fontSize: 11.5, fontWeight: FontWeight.w600, color: _Sv.faint)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.tajawal(fontSize: 26, fontWeight: FontWeight.w800, color: valueColor, height: 1.1)),
          const SizedBox(height: 2),
          Text(hint, style: GoogleFonts.tajawal(fontSize: 11, fontWeight: FontWeight.w600, color: _Sv.sub)),
        ],
      ),
    );
  }
}

class _SvChips extends StatelessWidget {
  const _SvChips({required this.value, required this.options, required this.onChanged});
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

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
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: value == o.$1 ? _Sv.drawerMid : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: value == o.$1 ? _Sv.drawerMid : const Color(0x33A8D4E6)),
              ),
              child: Text(
                o.$2,
                style: GoogleFonts.tajawal(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: value == o.$1 ? Colors.white : _Sv.sub,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SvPanel extends StatelessWidget {
  const _SvPanel({required this.label, required this.title, required this.child});
  final String label;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Sv.line),
        boxShadow: const [BoxShadow(color: Color(0x141A6B8A), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.tajawal(fontSize: 11.5, fontWeight: FontWeight.w600, color: _Sv.faint)),
                    const SizedBox(height: 2),
                    Text(title, style: GoogleFonts.tajawal(fontSize: 16.5, fontWeight: FontWeight.w800, color: _Sv.ink)),
                  ],
                ),
              ),
              Text('يتحدّث كل 30 ثانية', style: GoogleFonts.tajawal(fontSize: 11.5, color: _Sv.faint, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SvBadge extends StatelessWidget {
  const _SvBadge({required this.level});
  final _Level level;

  @override
  Widget build(BuildContext context) {
    final c = _levelColor(level);
    final bg = level == _Level.critical ? _Sv.crit : c.withValues(alpha: 0.12);
    final fg = level == _Level.critical ? Colors.white : c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(_levelLabel(level), style: GoogleFonts.tajawal(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

class _SvPressureCard extends StatelessWidget {
  const _SvPressureCard({
    required this.title,
    required this.level,
    required this.metrics,
    required this.selected,
    required this.onTap,
    this.bar,
  });

  final String title;
  final _Level level;
  final List<({String value, String label, bool hot})> metrics;
  final bool selected;
  final VoidCallback onTap;
  final double? bar;

  @override
  Widget build(BuildContext context) {
    final edge = _levelColor(level);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: selected ? const Color(0x731A6B8A) : _Sv.line),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: selected ? const [Color(0xFFF0F9FC), Colors.white] : const [Colors.white, Color(0xFFF7FBFD)],
              ),
              boxShadow: selected
                  ? const [BoxShadow(color: Color(0x401A6B8A), blurRadius: 22, offset: Offset(0, 10))]
                  : const [],
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(width: 3, decoration: BoxDecoration(color: edge, borderRadius: const BorderRadius.horizontal(right: Radius.circular(17)))),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(title, style: GoogleFonts.tajawal(fontSize: 14.5, fontWeight: FontWeight.w800, color: _Sv.ink, height: 1.3))),
                              _SvBadge(level: level),
                            ],
                          ),
                          const SizedBox(height: 10),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 2.6,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 6,
                            children: [
                              for (final m in metrics)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.value, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w800, color: m.hot ? _Sv.high : _Sv.ink)),
                                    Text(m.label, style: GoogleFonts.tajawal(fontSize: 10.5, fontWeight: FontWeight.w600, color: _Sv.faint)),
                                  ],
                                ),
                            ],
                          ),
                          if (bar != null) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: bar!.clamp(0.0, 1.0),
                                minHeight: 5,
                                backgroundColor: const Color(0x1A1A6B8A),
                                color: level == _Level.high || level == _Level.critical ? _Sv.high : _Sv.data,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SvPatient extends StatelessWidget {
  const _SvPatient({required this.rank, required this.title, required this.subtitle, required this.meta});
  final int rank;
  final String title;
  final String subtitle;
  final List<String> meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Sv.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _Sv.cyan.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text('$rank', style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 12, color: _Sv.data)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 14, color: _Sv.ink)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.tajawal(fontSize: 12, color: _Sv.sub, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final m in meta.where((e) => e.trim().isNotEmpty))
                      Text(m, style: GoogleFonts.tajawal(fontSize: 11, color: _Sv.faint, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SvEmpty extends StatelessWidget {
  const _SvEmpty({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Sv.mist,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Sv.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 14.5, color: _Sv.ink)),
          const SizedBox(height: 4),
          Text(body, style: GoogleFonts.tajawal(fontSize: 12.5, height: 1.45, color: _Sv.sub, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SvDetail extends StatelessWidget {
  const _SvDetail({required this.label, required this.title, required this.big, required this.evals, required this.hint});
  final String label;
  final String title;
  final String big;
  final List<(String, String)> evals;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Sv.line),
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
                    Text(label, style: GoogleFonts.tajawal(fontSize: 11.5, fontWeight: FontWeight.w600, color: _Sv.faint)),
                    Text(title, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800, color: _Sv.ink)),
                  ],
                ),
              ),
              Text(big, style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800, color: _Sv.data)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              for (final e in evals)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xB3EAF6FB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _Sv.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.$1, style: GoogleFonts.tajawal(fontSize: 10.5, fontWeight: FontWeight.w600, color: _Sv.faint)),
                      Text(e.$2, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w800, color: _Sv.ink)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _Sv.mist,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _Sv.line),
            ),
            child: Text(hint, style: GoogleFonts.tajawal(fontSize: 12, height: 1.4, fontWeight: FontWeight.w600, color: _Sv.sub)),
          ),
        ],
      ),
    );
  }
}

class _SvPage extends StatelessWidget {
  const _SvPage({required this.onRefresh, required this.children});
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _Sv.page,
      child: RefreshIndicator(
        color: _Sv.data,
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Reception ───────────────────────────────────────────────────────────────

class HarastaReceptionBoardPage extends StatefulWidget {
  const HarastaReceptionBoardPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<HarastaReceptionBoardPage> createState() => _HarastaReceptionBoardPageState();
}

class _HarastaReceptionBoardPageState extends State<HarastaReceptionBoardPage> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> _pending = [];
  bool _busy = false;
  bool _loading = true;
  String _panel = 'queue';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    setState(() => _busy = true);
    try {
      final s = await widget.api.receptionDayStats(HarastaCatalog.facilityId);
      var queue = <Map<String, dynamic>>[];
      var pending = <Map<String, dynamic>>[];
      try {
        queue = (await widget.api.receptionQueue(HarastaCatalog.facilityId)).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
      try {
        pending = (await widget.api.pendingReceptionBookings(HarastaCatalog.facilityId)).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _stats = s;
        _queue = queue;
        _pending = pending;
      });
    } catch (e) {
      if (mounted && !silent) await MsdNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() {
        _loading = false;
        _busy = false;
      });
    }
  }

  String get _lead {
    final atRx = _queue.length;
    final today = DateTime.now();
    final t = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final pendingToday = _pending.where((b) => '${b['appointmentDate'] ?? ''}'.startsWith(t)).length;
    if (atRx == 0 && pendingToday == 0) return 'الاستقبال هادئ حالياً — لا حجوزات بانتظار الحضور ولا حالات للتوجيه.';
    if (atRx >= 3) return '$atRx حالات بالاستقبال بانتظار التوجيه · راقب الضغط قبل أن يطول الانتظار.';
    if (pendingToday > 0) return '$pendingToday حجزاً بانتظار الحضور · $atRx بالاستقبال الآن.';
    return '$atRx بالاستقبال بانتظار التوجيه.';
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    final atRx = int.tryParse('${s?['atReceptionNow'] ?? _queue.length}') ?? _queue.length;
    final pendingN = int.tryParse('${s?['pendingBookings'] ?? _pending.length}') ?? _pending.length;
    final dest = (s?['destinations'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const <Map<String, dynamic>>[];
    final panelTitle = switch (_panel) {
      'bookings' => 'حجوزات بانتظار الحضور',
      'dest' => 'إلى أين وُجّه مراجعو اليوم؟',
      _ => 'الحالات بالاستقبال الآن',
    };

    return _SvPage(
      onRefresh: _load,
      children: [
        _SvHero(
          lead: _lead,
          note: 'فتح الإضبارة وتسجيل الوصول والتوجيه يتمّان من محطة الاستقبال المستقلة.',
          onRefresh: () => _load(),
          busy: _busy,
        ),
        if (_loading && s == null)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: _Sv.data)))
        else ...[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              _SvKpi(label: 'دخلوا اليوم', value: '${s?['enteredToday'] ?? 0}', hint: 'أضابير فُتحت'),
              _SvKpi(label: 'وُجّهوا اليوم', value: '${s?['directedToday'] ?? 0}', hint: 'إلى عيادة أو قسم', kind: 'accent'),
              _SvKpi(label: 'بالاستقبال الآن', value: '$atRx', hint: 'بانتظار التوجيه', kind: atRx >= 3 ? 'alert' : null),
              _SvKpi(label: 'حجوزات بانتظار الحضور', value: '$pendingN', hint: 'لم يُسجَّل وصولها', kind: pendingN > 0 ? 'alert' : 'calm'),
              _SvKpi(label: 'إسعافي اليوم', value: '${s?['emergencyToday'] ?? 0}', hint: 'تحويل مباشر'),
              _SvKpi(label: 'أُعيد للاستقبال', value: '${s?['returnedToday'] ?? 0}', hint: 'اليوم'),
            ],
          ),
          _SvChips(
            value: _panel,
            options: const [
              ('queue', 'طابور الاستقبال'),
              ('bookings', 'حجوزات بانتظار الحضور'),
              ('dest', 'وجهات التوجيه'),
            ],
            onChanged: (v) => setState(() => _panel = v),
          ),
          _SvPanel(
            label: 'متابعة حية',
            title: panelTitle,
            child: switch (_panel) {
              'bookings' => _pending.isEmpty
                  ? const _SvEmpty(title: 'لا حجوزات بانتظار الحضور', body: 'عند وصول مراجع محجوز يظهر هنا للمسؤول — التسجيل من محطة الاستقبال.')
                  : Column(
                      children: [
                        for (var i = 0; i < _pending.length; i++)
                          _SvPatient(
                            rank: i + 1,
                            title: '${_pending[i]['patientName'] ?? '—'}',
                            subtitle: '${_pending[i]['code'] ?? ''} · عيادة ${_pending[i]['clinic'] ?? ''} · ${_pending[i]['nationalId'] ?? 'بدون هوية'}',
                            meta: [
                              '${_pending[i]['appointmentDate'] ?? ''} · ${_pending[i]['slot'] ?? ''}',
                              if ('${_pending[i]['specialType'] ?? ''}'.isNotEmpty) '${_pending[i]['specialType']}',
                            ],
                          ),
                      ],
                    ),
              'dest' => dest.isEmpty
                  ? const _SvEmpty(title: 'لا توجيهات بعد اليوم', body: 'عند تحويل الحالات من محطة الاستقبال تظهر الوجهات هنا.')
                  : Column(
                      children: [
                        for (final d in dest)
                          _SvPressureCard(
                            title: '${d['destination']}' == 'الإسعاف' ? 'الإسعاف' : 'عيادة ${d['destination']}',
                            level: _Level.ok,
                            metrics: [
                              (value: '${d['count']}', label: 'مراجع', hot: false),
                              (value: '${d['percent']}%', label: 'من التوجيهات', hot: false),
                            ],
                            selected: false,
                            onTap: () {},
                            bar: (double.tryParse('${d['percent']}') ?? 0) / 100,
                          ),
                      ],
                    ),
              _ => _queue.isEmpty
                  ? const _SvEmpty(title: 'لا حالات بالاستقبال', body: 'الطابور فارغ حالياً.')
                  : Column(
                      children: [
                        for (var i = 0; i < _queue.length; i++)
                          _SvPatient(
                            rank: i + 1,
                            title: '${_queue[i]['patientName'] ?? '—'}',
                            subtitle: '${_queue[i]['caseNumber'] ?? ''} · ${_queue[i]['age'] ?? '—'} سنة · ${_queue[i]['entryType'] ?? ''}',
                            meta: [
                              '${_queue[i]['statusLabel'] ?? _queue[i]['status'] ?? ''}',
                              if ('${_queue[i]['bookedClinic'] ?? ''}'.isNotEmpty) 'محجوز: ${_queue[i]['bookedClinic']}',
                            ],
                          ),
                      ],
                    ),
            },
          ),
          _SvDetail(
            label: 'ملخص اليوم',
            title: 'تقييم الاستقبال',
            big: '${s?['directedToday'] ?? 0}',
            evals: [
              ('وصول من حجز', '${s?['bookingArrivalsToday'] ?? 0}'),
              ('بالاستقبال الآن', '$atRx'),
              ('حجوزات معلّقة', '$pendingN'),
              ('ضغط الطابور', atRx >= 5 ? 'حرج' : atRx >= 3 ? 'مرتفع' : atRx > 0 ? 'متوسط' : 'مستقر'),
            ],
            hint: 'للإدخال والتوجيه: محطة الاستقبال المستقلة — مستخدم reception',
          ),
        ],
      ],
    );
  }
}

// ─── Clinics ─────────────────────────────────────────────────────────────────

class HarastaClinicsBoardPage extends StatefulWidget {
  const HarastaClinicsBoardPage({super.key, required this.api, this.onOpenLive});
  final ApiClient api;
  final VoidCallback? onOpenLive;

  @override
  State<HarastaClinicsBoardPage> createState() => _HarastaClinicsBoardPageState();
}

class _HarastaClinicsBoardPageState extends State<HarastaClinicsBoardPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _busy = false;
  bool _loading = true;
  String _view = 'all';
  String? _clinic;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _w(Map<String, dynamic> r) => int.tryParse('${r['waiting'] ?? 0}') ?? 0;

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    setState(() => _busy = true);
    try {
      final live = await widget.api.clinicLive(HarastaCatalog.facilityId);
      if (!mounted) return;
      setState(() => _rows = live.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      if (mounted && !silent) await MsdNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() {
        _loading = false;
        _busy = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visible {
    final sorted = [..._rows]..sort((a, b) => _w(b).compareTo(_w(a)));
    return switch (_view) {
      'hot' => sorted.where((r) => _w(r) >= 3).toList(),
      'busy' => sorted.where((r) => _w(r) > 0).toList(),
      'clear' => sorted.where((r) => _w(r) == 0).toList(),
      _ => sorted,
    };
  }

  String get _lead {
    final waiting = _rows.fold<int>(0, (a, r) => a + _w(r));
    final hot = _rows.where((r) => _w(r) >= 3).length;
    final busy = _rows.where((r) => _w(r) > 0).length;
    if (waiting == 0) return 'لا طابور ظاهر حالياً — الشبكة هادئة.';
    if (hot > 0) return '$waiting بالانتظار · $hot عيادات بضغط مرتفع تحتاج متابعة.';
    return '$waiting بالانتظار موزّعون على $busy عيادة.';
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _rows.fold<int>(0, (a, r) => a + _w(r));
    final hot = _rows.where((r) => _w(r) >= 3).length;
    final clear = _rows.where((r) => _w(r) == 0).length;
    final busyN = _rows.where((r) => _w(r) > 0).length;
    final selected = _rows.cast<Map<String, dynamic>?>().firstWhere((r) => '${r?['clinic']}' == _clinic, orElse: () => null);

    return _SvPage(
      onRefresh: _load,
      children: [
        _SvHero(
          lead: _lead,
          note: 'الإدخال والاستدعاء يتمّان من محطة كل عيادة. هذه الشاشة للرؤية والتقييم فقط.',
          onRefresh: () => _load(),
          busy: _busy,
          actions: [
            if (widget.onOpenLive != null) _SvBtn(label: 'إحصائيات اليوم', onTap: widget.onOpenLive),
          ],
        ),
        if (_loading && _rows.isEmpty)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: _Sv.data)))
        else ...[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              _SvKpi(label: 'عيادات عليها انتظار', value: '$busyN', hint: 'من ${_rows.length}'),
              _SvKpi(label: 'إجمالي الانتظار', value: '$waiting', hint: 'مرضى في الطوابير الآن', kind: 'accent'),
              _SvKpi(label: 'ضغط مرتفع', value: '$hot', hint: '3 فأكثر بالانتظار', kind: hot > 0 ? 'alert' : null),
              _SvKpi(label: 'بلا انتظار', value: '$clear', hint: 'عيادات هادئة', kind: 'calm'),
            ],
          ),
          _SvChips(
            value: _view,
            options: const [('all', 'الكل'), ('hot', 'ضغط مرتفع'), ('busy', 'فيها انتظار'), ('clear', 'هادئة')],
            onChanged: (v) => setState(() => _view = v),
          ),
          _SvPanel(
            label: 'خريطة العيادات',
            title: 'تقييم الحمل الحالي',
            child: _visible.isEmpty
                ? const _SvEmpty(title: 'لا عيادات في هذا التصفية', body: 'جرّب تصفية أخرى أو حدّث اللوحة.')
                : Column(
                    children: [
                      for (final r in _visible)
                        _SvPressureCard(
                          title: '${r['clinic']}' == 'الإسعاف' ? 'الإسعاف' : 'عيادة ${r['clinic']}',
                          level: _levelOf(_w(r)),
                          metrics: [
                            (value: '${r['waiting'] ?? 0}', label: 'بالانتظار', hot: _w(r) > 0),
                            (value: '${r['todayReferrals'] ?? 0}', label: 'توجيهات اليوم', hot: false),
                            (value: '${r['avgWaitLabel'] ?? '—'}', label: 'متوسط الانتظار', hot: false),
                            (value: '${r['maxWaitLabel'] ?? '—'}', label: 'أقصى انتظار', hot: false),
                          ],
                          selected: _clinic == '${r['clinic']}',
                          onTap: () => setState(() => _clinic = '${r['clinic']}'),
                          bar: (_w(r) / 8).clamp(0.05, 1.0),
                        ),
                    ],
                  ),
          ),
          if (selected != null)
            _SvDetail(
              label: 'تفاصيل العيادة',
              title: '${selected['clinic']}' == 'الإسعاف' ? 'الإسعاف' : 'عيادة ${selected['clinic']}',
              big: '${selected['waiting'] ?? 0}',
              evals: [
                ('بالانتظار', '${selected['waiting'] ?? 0}'),
                ('توجيهات اليوم', '${selected['todayReferrals'] ?? 0}'),
                ('متوسط الانتظار', '${selected['avgWaitLabel'] ?? '—'}'),
                ('أقصى انتظار', '${selected['maxWaitLabel'] ?? '—'}'),
              ],
              hint: 'للنداء وإنهاء الحالة: محطة العيادة المستقلة (مستخدم clinic-…).',
            ),
        ],
      ],
    );
  }
}

// ─── Departments ─────────────────────────────────────────────────────────────

class HarastaDeptsBoardPage extends StatefulWidget {
  const HarastaDeptsBoardPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<HarastaDeptsBoardPage> createState() => _HarastaDeptsBoardPageState();
}

class _HarastaDeptsBoardPageState extends State<HarastaDeptsBoardPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _busy = false;
  bool _loading = true;
  String _view = 'all';
  String? _dept;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _loadScore(Map<String, dynamic> r) {
    final queued = int.tryParse('${r['queued'] ?? r['waiting'] ?? 0}') ?? 0;
    final present = int.tryParse('${r['present'] ?? r['occupied'] ?? 0}') ?? 0;
    return queued + present;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    setState(() => _busy = true);
    try {
      final live = await widget.api.departmentsLive(HarastaCatalog.facilityId);
      if (!mounted) return;
      var rows = live.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (rows.isEmpty) {
        rows = HarastaCatalog.departments.map((d) => {'name': d, 'queued': 0, 'present': 0, 'todayReferrals': 0}).toList();
      }
      setState(() => _rows = rows);
    } catch (e) {
      if (mounted && !silent) await MsdNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() {
        _loading = false;
        _busy = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visible {
    final sorted = [..._rows]..sort((a, b) => _loadScore(b).compareTo(_loadScore(a)));
    return switch (_view) {
      'hot' => sorted.where((r) => _loadScore(r) >= 3).toList(),
      'busy' => sorted.where((r) => _loadScore(r) > 0).toList(),
      'clear' => sorted.where((r) => _loadScore(r) == 0).toList(),
      _ => sorted,
    };
  }

  String get _lead {
    final present = _rows.fold<int>(0, (a, r) => a + _loadScore(r));
    final hot = _rows.where((r) => _loadScore(r) >= 3).length;
    final busy = _rows.where((r) => _loadScore(r) > 0).length;
    if (present == 0) return 'لا حالات ظاهرة في أقسام التحويل حالياً.';
    if (hot > 0) return '$present حالة قيد المتابعة · $hot أقسام بضغط مرتفع.';
    return '$present حالة موزّعة على $busy أقسام.';
  }

  @override
  Widget build(BuildContext context) {
    final present = _rows.fold<int>(0, (a, r) => a + _loadScore(r));
    final hot = _rows.where((r) => _loadScore(r) >= 3).length;
    final clear = _rows.where((r) => _loadScore(r) == 0).length;
    final busyN = _rows.where((r) => _loadScore(r) > 0).length;
    final selected = _rows.cast<Map<String, dynamic>?>().firstWhere((r) => '${r?['name']}' == _dept, orElse: () => null);

    return _SvPage(
      onRefresh: _load,
      children: [
        _SvHero(
          lead: _lead,
          note: 'المحوَّلون من العيادات: أسرّة، عناية، عمليات، مخبر، صيدلية، أشعة. الإنهاء يتم من محطة القسم.',
          onRefresh: () => _load(),
          busy: _busy,
        ),
        if (_loading && _rows.isEmpty)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: _Sv.data)))
        else ...[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              _SvKpi(label: 'أقسام عليها حالات', value: '$busyN', hint: 'من ${_rows.length}'),
              _SvKpi(label: 'إجمالي الحالات', value: '$present', hint: 'بانتظار أو قيد القسم', kind: 'accent'),
              _SvKpi(label: 'ضغط مرتفع', value: '$hot', hint: 'حسب الحمل والسعة', kind: hot > 0 ? 'alert' : null),
              _SvKpi(label: 'بلا حالات', value: '$clear', hint: 'أقسام هادئة', kind: 'calm'),
            ],
          ),
          _SvChips(
            value: _view,
            options: const [('all', 'الكل'), ('hot', 'ضغط مرتفع'), ('busy', 'فيها حالات'), ('clear', 'هادئة')],
            onChanged: (v) => setState(() => _view = v),
          ),
          _SvPanel(
            label: 'خريطة الأقسام',
            title: 'تقييم الحمل الحالي',
            child: _visible.isEmpty
                ? const _SvEmpty(title: 'لا أقسام في هذا التصفية', body: 'جرّب تصفية أخرى أو حدّث اللوحة.')
                : Column(
                    children: [
                      for (final r in _visible)
                        _SvPressureCard(
                          title: '${r['name'] ?? ''}',
                          level: _levelOf(_loadScore(r)),
                          metrics: r['capacity'] != null
                              ? [
                                  (value: '${r['capacity']}', label: 'السعة', hot: false),
                                  (value: '${r['occupied'] ?? r['present'] ?? 0}', label: 'مشغول', hot: _loadScore(r) > 0),
                                  (value: '${r['free'] ?? ((int.tryParse('${r['capacity']}') ?? 0) - (int.tryParse('${r['occupied'] ?? r['present'] ?? 0}') ?? 0))}', label: 'فارغ', hot: false),
                                  (value: '${r['todayReferrals'] ?? 0}', label: 'توجيهات اليوم', hot: false),
                                ]
                              : [
                                  (value: '${r['present'] ?? 0}', label: 'حالات الآن', hot: (int.tryParse('${r['present'] ?? 0}') ?? 0) > 0),
                                  (value: '${r['queued'] ?? 0}', label: 'بالدور', hot: false),
                                  (value: '${r['avgWaitLabel'] ?? '—'}', label: 'متوسط الانتظار', hot: false),
                                  (value: '${r['maxWaitLabel'] ?? '—'}', label: 'أقصى انتظار', hot: false),
                                ],
                          selected: _dept == '${r['name']}',
                          onTap: () => setState(() => _dept = '${r['name']}'),
                          bar: (_loadScore(r) / 8).clamp(0.05, 1.0),
                        ),
                    ],
                  ),
          ),
          if (selected != null)
            _SvDetail(
              label: 'تفاصيل القسم',
              title: '${selected['name']}',
              big: '${_loadScore(selected)}',
              evals: [
                ('الطابور', '${selected['queued'] ?? selected['waiting'] ?? 0}'),
                ('حاضر', '${selected['present'] ?? selected['occupied'] ?? 0}'),
                ('تحويلات اليوم', '${selected['todayReferrals'] ?? 0}'),
                ('الحالة', _levelLabel(_levelOf(_loadScore(selected)))),
              ],
              hint: 'لتشغيل القسم: سجّل الدخول بمحطة القسم المستقلة.',
            ),
        ],
      ],
    );
  }
}

// ─── Booking follow-up (station remains booking user) ────────────────────────

class HarastaBookingBoardPage extends StatefulWidget {
  const HarastaBookingBoardPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<HarastaBookingBoardPage> createState() => _HarastaBookingBoardPageState();
}

class _HarastaBookingBoardPageState extends State<HarastaBookingBoardPage> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _pending = [];
  bool _busy = false;
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    setState(() => _busy = true);
    try {
      final s = await widget.api.receptionDayStats(HarastaCatalog.facilityId);
      var pending = <Map<String, dynamic>>[];
      try {
        pending = (await widget.api.pendingReceptionBookings(HarastaCatalog.facilityId)).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _stats = s;
        _pending = pending;
      });
    } catch (e) {
      if (mounted && !silent) await MsdNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() {
        _loading = false;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = int.tryParse('${_stats?['pendingBookings'] ?? _pending.length}') ?? _pending.length;
    final arrivals = int.tryParse('${_stats?['bookingArrivalsToday'] ?? 0}') ?? 0;

    return _SvPage(
      onRefresh: _load,
      children: [
        _SvHero(
          lead: pending == 0
              ? 'لا حجوزات بانتظار الحضور حالياً.'
              : '$pending حجزاً بانتظار الحضور · $arrivals وصلوا اليوم من حجز.',
          note: 'إنشاء وتعديل وإلغاء الحجوزات من واجهة الحجز المستقلة بمستخدم booking فقط.',
          onRefresh: () => _load(),
          busy: _busy,
        ),
        if (_loading && _stats == null)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: _Sv.data)))
        else ...[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              _SvKpi(label: 'بانتظار الحضور', value: '$pending', hint: 'لم يُسجَّل وصول', kind: pending > 0 ? 'alert' : 'calm'),
              _SvKpi(label: 'حضور اليوم', value: '$arrivals', hint: 'من حجز مسبق', kind: 'accent'),
            ],
          ),
          _SvPanel(
            label: 'متابعة حية',
            title: 'حجوزات معلّقة',
            child: _pending.isEmpty
                ? const _SvEmpty(
                    title: 'لا حجوزات معلّقة',
                    body: 'عند إنشاء حجز من محطة الحجز يظهر هنا حتى يُسجَّل الحضور في الاستقبال.',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < _pending.length; i++)
                        _SvPatient(
                          rank: i + 1,
                          title: '${_pending[i]['patientName'] ?? '—'}',
                          subtitle: '${_pending[i]['code'] ?? ''} · عيادة ${_pending[i]['clinic'] ?? ''} · ${_pending[i]['adminUnit'] ?? ''}',
                          meta: [
                            '${_pending[i]['appointmentDate'] ?? ''} · ${_pending[i]['slot'] ?? ''}',
                            if ('${_pending[i]['specialType'] ?? ''}'.isNotEmpty) '${_pending[i]['specialType']}',
                          ],
                        ),
                    ],
                  ),
          ),
          _SvDetail(
            label: 'واجهة مستقلة',
            title: 'محطة الحجز',
            big: '$pending',
            evals: [
              ('المستخدم', 'booking'),
              ('الدور', 'موظف حجز الإدارات'),
              ('المسار', '/stations/harasta/booking'),
              ('الصلاحية', 'إنشاء · تعديل · إلغاء'),
            ],
            hint: 'سجّل الخروج من حساب المدير ثم ادخل بمستخدم booking لفتح واجهة الحجز الكاملة.',
          ),
        ],
      ],
    );
  }
}
