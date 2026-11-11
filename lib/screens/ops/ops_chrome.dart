import 'package:flutter/material.dart';

import '../../theme/cmd_icon.dart';
import '../../theme/tokens.dart';

/// Teal COMMAND SITREP palette. Values come from [MsdTokens].
class OpsColors {
  static const ink = MsdTokens.ink;
  static const sub = MsdTokens.sub;
  static const faint = MsdTokens.faint;
  static const line = MsdTokens.line;
  static const lineSoft = MsdTokens.lineSoft;
  static const paper = MsdTokens.paper;
  static const page = MsdTokens.page;
  static const cyan = MsdTokens.cyan;
  static const teal = MsdTokens.teal;
  static const blue = MsdTokens.blue;
  static const green = MsdTokens.successFill;
  static const amber = MsdTokens.amberText;
  static const red = MsdTokens.danger;
  static const surface = MsdTokens.surface;
}

TextStyle opsText(
  double size, {
  FontWeight w = FontWeight.w600,
  Color color = OpsColors.ink,
  double? height,
}) =>
    TextStyle(
      fontFamily: 'Tajawal',
      fontSize: size < 12 ? 12 : size,
      fontWeight: w,
      color: color,
      height: height,
    );

// ───────────────────────── data models (read-only mock) ─────────────────────────

const kNoData = 'لا توجد بيانات';

class OpsPill {
  const OpsPill(this.label, this.color);
  final String label;
  final Color color;
}

class OpsStep {
  const OpsStep(this.t, this.label, this.done);
  final String t;
  final String label;
  final bool done;
}

class OpsGauge {
  const OpsGauge(this.label, this.pct, this.color);
  final String label;
  final int pct;
  final Color color;
}

class OpsKpi {
  const OpsKpi(this.label, this.value, this.icon, this.color, {this.hint, this.hintColor});
  final String label;
  final String value;
  final String icon;
  final Color color;
  final String? hint;
  final Color? hintColor;
}

class OpsFilterOption {
  const OpsFilterOption(this.label, [this.color]);
  final String label;
  final Color? color;
}

class OpsTransfer {
  const OpsTransfer({required this.kind, required this.from, required this.to});
  final String kind;
  final String from;
  final String to;
}

class OpsItem {
  OpsItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    this.filterValue,
    this.group,
    this.pills = const [],
    this.metricValue,
    this.metricLabel,
    this.barPct,
    this.barColor,
    this.bannerTitle,
    this.bannerSub,
    this.gauges = const [],
    this.info = const [],
    this.tags = const [],
    this.tagsTitle = 'الخدمات المتوفرة',
    this.steps = const [],
    this.stepsTitle = 'TIMELINE',
    this.transfer,
    this.badge,
    this.badgeColor,
    this.actionLabel,
    this.onAction,
  });

  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final Color tone;

  /// Primary filter chip value (e.g. severity / status).
  final String? filterValue;

  /// Secondary filter value (e.g. type).
  final String? group;
  final List<OpsPill> pills;
  final String? metricValue;
  final String? metricLabel;
  final int? barPct;
  final Color? barColor;
  final String? bannerTitle;
  final String? bannerSub;
  final List<OpsGauge> gauges;
  final List<(String, String)> info;
  final List<String> tags;
  final String tagsTitle;
  final List<OpsStep> steps;
  final String stepsTitle;
  final OpsTransfer? transfer;
  final String? badge;
  final Color? badgeColor;

  /// Navigation-only action (deep-dive into an existing screen). Never a form.
  final String? actionLabel;
  final VoidCallback? onAction;
}

// ───────────────────────── scaffold ─────────────────────────

class OpsScaffold extends StatelessWidget {
  const OpsScaffold({
    super.key,
    required this.title,
    required this.eyebrow,
    required this.children,
    this.controller,
    this.onRefresh,
  });

  final String title;
  final String eyebrow;
  final List<Widget> children;
  final ScrollController? controller;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OpsColors.page,
      appBar: AppBar(
        backgroundColor: OpsColors.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: OpsColors.ink,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: opsText(16, w: FontWeight.w800)),
            Text(eyebrow, style: opsText(12, w: FontWeight.w700, color: OpsColors.faint)),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: _withRefresh(
          ListView(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _withRefresh(Widget list) {
    final r = onRefresh;
    if (r == null) return list;
    return RefreshIndicator(color: OpsColors.cyan, onRefresh: r, child: list);
  }
}

// ───────────────────────── building blocks ─────────────────────────

class OpsCard extends StatelessWidget {
  const OpsCard({
    super.key,
    required this.tone,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
  });

  final Color tone;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OpsColors.line),
        boxShadow: const [BoxShadow(color: MsdTokens.deepWash, blurRadius: 20, offset: Offset(0, 10))],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border(top: BorderSide(color: tone, width: 3)),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: body),
    );
  }
}

class OpsSectionTitle extends StatelessWidget {
  const OpsSectionTitle({super.key, required this.no, required this.title});
  final String no;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: OpsColors.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(no, style: opsText(12, w: FontWeight.w800, color: OpsColors.cyan)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: opsText(14, w: FontWeight.w800))),
        ],
      ),
    );
  }
}

class OpsPillTag extends StatelessWidget {
  const OpsPillTag(this.label, this.color, {super.key});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: opsText(12, w: FontWeight.w800, color: color)),
    );
  }
}

class OpsBar extends StatelessWidget {
  const OpsBar({super.key, required this.fraction, required this.color, this.height = 7});
  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: MsdTokens.lineSoft,
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          child: Container(color: color),
        ),
      ),
    );
  }
}

class OpsKpiRow extends StatelessWidget {
  const OpsKpiRow({super.key, required this.kpis});
  final List<OpsKpi> kpis;

  static const _spark = [0.38, 0.62, 0.48, 0.78, 0.55, 0.88, 0.70];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OpsColors.line),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [MsdTokens.white, MsdTokens.paper],
        ),
        boxShadow: [
          BoxShadow(color: MsdTokens.deep.withValues(alpha: 0.12), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, box) {
          final cols = kpis.length >= 4 ? 2 : (kpis.length == 3 ? 3 : 2);
          final rows = <Widget>[];
          for (var i = 0; i < kpis.length; i += cols) {
            final slice = kpis.skip(i).take(cols).toList();
            rows.add(
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < slice.length; j++) ...[
                      if (j > 0) Container(width: 1, color: OpsColors.line.withValues(alpha: 0.45)),
                      Expanded(child: _kpiCell(slice[j])),
                    ],
                  ],
                ),
              ),
            );
            if (i + cols < kpis.length) {
              rows.add(Container(height: 1, color: OpsColors.line.withValues(alpha: 0.45)));
            }
          }
          return Column(children: rows);
        },
      ),
    );
  }

  Widget _kpiCell(OpsKpi k) {
    final live = k.hint == 'مباشر';
    final deltaColor = k.hintColor ?? k.color;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.85, -0.9),
          radius: 1.15,
          colors: [k.color.withValues(alpha: 0.12), Colors.transparent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [k.color.withValues(alpha: 0.18), k.color.withValues(alpha: 0.08)],
                  ),
                  border: Border.all(color: k.color.withValues(alpha: 0.28)),
                  boxShadow: [BoxShadow(color: k.color.withValues(alpha: 0.22), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                alignment: Alignment.center,
                child: CmdIcon(k.icon, size: 16, color: k.color),
              ),
              const Spacer(),
              if (k.hint != null)
                Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(
                    color: deltaColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: deltaColor.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (live) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: MsdTokens.successFill, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(k.hint!, style: opsText(12, w: FontWeight.w800, color: deltaColor)),
                    ],
                  ),
                )
              else
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [k.color, k.color.withValues(alpha: 0.35)],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (k.value == kNoData)
            SizedBox(
              height: 24,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(kNoData, style: opsText(13, w: FontWeight.w700, color: OpsColors.faint)),
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(k.value, style: opsText(24, w: FontWeight.w800, height: 1)),
            ),
          const SizedBox(height: 4),
          Text(
            k.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: opsText(12, color: OpsColors.sub),
          ),
          const SizedBox(height: 10),
          if (k.value != kNoData) SizedBox(
            height: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final h in _spark)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: FractionallySizedBox(
                        heightFactor: h,
                        alignment: Alignment.bottomCenter,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: k.color.withValues(alpha: 0.5),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OpsFilterChips extends StatelessWidget {
  const OpsFilterChips({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<OpsFilterOption> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: OpsColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OpsColors.lineSoft),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 2),
        itemBuilder: (context, i) {
          final o = options[i];
          final on = o.label == value;
          final c = o.color ?? OpsColors.cyan;
          return GestureDetector(
            onTap: () => onChanged(o.label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: on ? c.withValues(alpha: 0.45) : Colors.transparent),
                boxShadow: on
                    ? [
                        BoxShadow(
                          color: c.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (o.color != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: o.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: o.color!.withValues(alpha: 0.28), blurRadius: 4, spreadRadius: 1),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    o.label,
                    style: opsText(12.5, w: on ? FontWeight.w800 : FontWeight.w600, color: on ? c : OpsColors.sub),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class OpsSearchField extends StatelessWidget {
  const OpsSearchField({super.key, required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OpsColors.line),
      ),
      child: Row(
        children: [
          const CmdIcon('search', size: 18, color: OpsColors.faint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: opsText(13.5),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: opsText(13, color: OpsColors.faint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OpsInfoGrid extends StatelessWidget {
  const OpsInfoGrid({super.key, required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 8.0;
        final w = (box.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final r in rows)
              SizedBox(
                width: w,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: OpsColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: OpsColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.$1, style: opsText(12, color: OpsColors.faint)),
                      const SizedBox(height: 2),
                      Text(r.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: opsText(13, w: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class OpsTimeline extends StatelessWidget {
  const OpsTimeline({super.key, required this.steps});
  final List<OpsStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 18,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          color: steps[i].done ? OpsColors.cyan : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: steps[i].done ? OpsColors.cyan : OpsColors.faint, width: 2),
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: steps[i].done ? OpsColors.cyan : OpsColors.line,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].label,
                          style: opsText(13, w: FontWeight.w700, color: steps[i].done ? OpsColors.ink : OpsColors.faint),
                        ),
                        Text(steps[i].t, style: opsText(12, color: OpsColors.faint)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Horizontal bar distribution card (e.g. events by type).
class OpsDistributionCard extends StatelessWidget {
  const OpsDistributionCard({
    super.key,
    required this.no,
    required this.title,
    required this.rows,
    this.tone = OpsColors.cyan,
  });

  final String no;
  final String title;
  final List<(String, num, Color)> rows;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final max = rows.fold<num>(1, (m, r) => r.$2 > m ? r.$2 : m);
    return OpsCard(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OpsSectionTitle(no: no, title: title),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(r.$1, style: opsText(12, w: FontWeight.w700))),
                      Text('${r.$2}', style: opsText(12, w: FontWeight.w800, color: OpsColors.faint)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  OpsBar(fraction: r.$2 / max, color: r.$3, height: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class OpsEmpty extends StatelessWidget {
  const OpsEmpty(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(child: Text(message, style: opsText(13, color: OpsColors.faint))),
      );
}

// ───────────────────────── list + detail monitor ─────────────────────────

/// Read-only monitoring screen: KPI row, filters, list of cards, bottom-sheet detail.
class OpsMonitorScreen extends StatefulWidget {
  const OpsMonitorScreen({
    super.key,
    required this.title,
    required this.eyebrow,
    required this.kpis,
    required this.items,
    this.filters = const [],
    this.groups = const [],
    this.searchHint = 'بحث...',
    this.unit = 'عنصر',
    this.kindLabel = 'ITEM',
    this.extras = const [],
    this.openDetail = true,
    this.onRefresh,
    this.emptyMessage = 'لا توجد بيانات لعرضها',
  });

  final Future<void> Function()? onRefresh;
  final String emptyMessage;
  final String title;
  final String eyebrow;
  final List<OpsKpi> kpis;
  final List<OpsItem> items;
  final List<OpsFilterOption> filters;
  final List<OpsFilterOption> groups;
  final String searchHint;
  final String unit;
  final String kindLabel;
  final List<Widget> extras;
  /// When false, list is monitor-only (no case detail sheet).
  final bool openDetail;

  @override
  State<OpsMonitorScreen> createState() => _OpsMonitorScreenState();
}

class _OpsMonitorScreenState extends State<OpsMonitorScreen> {
  static const _all = 'الكل';
  var _filter = _all;
  var _group = _all;
  var _query = '';

  List<OpsItem> get _filtered {
    final q = _query.trim();
    return widget.items.where((e) {
      final okF = _filter == _all || e.filterValue == _filter;
      final okG = _group == _all || e.group == _group;
      final okQ = q.isEmpty || e.id.contains(q) || e.title.contains(q) || e.subtitle.contains(q);
      return okF && okG && okQ;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return OpsScaffold(
      title: widget.title,
      eyebrow: widget.eyebrow,
      onRefresh: widget.onRefresh,
      children: [
        OpsKpiRow(kpis: widget.kpis),
        const SizedBox(height: 12),
        OpsSearchField(hint: widget.searchHint, onChanged: (v) => setState(() => _query = v)),
        if (widget.filters.isNotEmpty || widget.groups.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OpsColors.line),
              boxShadow: [
                BoxShadow(
                  color: MsdTokens.deep.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                if (widget.filters.isNotEmpty)
                  OpsFilterChips(
                    options: [const OpsFilterOption(_all), ...widget.filters],
                    value: _filter,
                    onChanged: (v) => setState(() => _filter = v),
                  ),
                if (widget.filters.isNotEmpty && widget.groups.isNotEmpty) const SizedBox(height: 8),
                if (widget.groups.isNotEmpty)
                  OpsFilterChips(
                    options: [const OpsFilterOption(_all), ...widget.groups],
                    value: _group,
                    onChanged: (v) => setState(() => _group = v),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'عرض ${rows.length} من ${widget.items.length} ${widget.unit}',
            style: opsText(12, w: FontWeight.w700, color: OpsColors.faint),
          ),
        ),
        if (widget.items.isEmpty)
          OpsEmpty(widget.emptyMessage)
        else if (rows.isEmpty)
          const OpsEmpty('لا توجد نتائج مطابقة'),
        for (final item in rows) ...[
          _OpsItemCard(
            item: item,
            onTap: widget.openDetail
                ? () => showOpsDetail(context, item, kindLabel: widget.kindLabel)
                : null,
          ),
          const SizedBox(height: 10),
        ],
        for (final e in widget.extras) ...[
          const SizedBox(height: 4),
          e,
        ],
      ],
    );
  }
}

class _OpsItemCard extends StatelessWidget {
  const _OpsItemCard({required this.item, this.onTap});
  final OpsItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OpsCard(
      tone: item.tone,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CmdIconTile(name: item.icon, tone: item.tone, size: 40, iconSize: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: opsText(14, w: FontWeight.w800),
                          ),
                        ),
                        if (item.badge != null) ...[
                          const SizedBox(width: 6),
                          _Badge(item.badge!, item.badgeColor ?? OpsColors.blue),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: opsText(12, color: OpsColors.faint),
                    ),
                  ],
                ),
              ),
              if (item.metricValue != null) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(item.metricValue!, style: opsText(16, w: FontWeight.w900, height: 1)),
                    if (item.metricLabel != null)
                      Text(item.metricLabel!, style: opsText(12, color: OpsColors.faint)),
                  ],
                ),
              ],
            ],
          ),
          if (item.barPct != null) ...[
            const SizedBox(height: 10),
            OpsBar(fraction: item.barPct! / 100, color: item.barColor ?? item.tone, height: 6),
          ],
          if (item.pills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final p in item.pills) OpsPillTag(p.label, p.color)],
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: opsText(12, w: FontWeight.w900, color: color)),
    );
  }
}

Future<void> showOpsDetail(BuildContext context, OpsItem item, {String kindLabel = 'ITEM'}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: OpsColors.line, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$kindLabel · ${item.id}', style: opsText(12, w: FontWeight.w800, color: OpsColors.cyan)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(child: Text(item.title, style: opsText(18, w: FontWeight.w900))),
                          if (item.badge != null) ...[
                            const SizedBox(width: 8),
                            _Badge(item.badge!, item.badgeColor ?? OpsColors.blue),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item.pills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final p in item.pills) OpsPillTag(p.label, p.color)],
              ),
            ],
            if (item.bannerTitle != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.tone.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: item.tone.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    CmdIconTile(name: item.icon, tone: item.tone, size: 40, iconSize: 19),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.bannerTitle!, style: opsText(13.5, w: FontWeight.w800)),
                          if (item.bannerSub != null)
                            Text(item.bannerSub!, style: opsText(12, color: OpsColors.faint)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (item.gauges.isNotEmpty) ...[
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, box) {
                  final cols = item.gauges.length == 1 ? 1 : 2;
                  final w = (box.maxWidth - 8 * (cols - 1)) / cols;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final g in item.gauges) SizedBox(width: w, child: _GaugeBox(g))],
                  );
                },
              ),
            ],
            if (item.info.isNotEmpty) ...[
              const SizedBox(height: 12),
              OpsInfoGrid(rows: item.info),
            ],
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(item.tagsTitle, style: opsText(12, w: FontWeight.w800, color: OpsColors.faint)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in item.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: OpsColors.cyan.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: OpsColors.cyan.withValues(alpha: 0.25)),
                      ),
                      child: Text(t, style: opsText(12, w: FontWeight.w700, color: OpsColors.teal)),
                    ),
                ],
              ),
            ],
            if (item.transfer != null) ...[
              const SizedBox(height: 14),
              _TransferBox(item.transfer!),
            ],
            if (item.steps.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(item.stepsTitle, style: opsText(12, w: FontWeight.w800, color: OpsColors.faint)),
              const SizedBox(height: 8),
              OpsTimeline(steps: item.steps),
            ],
            if (item.actionLabel != null && item.onAction != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: OpsColors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    item.onAction!();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CmdIcon('arrowL', size: 18, color: Colors.white, stroke: 2),
                      const SizedBox(width: 8),
                      Text(item.actionLabel!, style: opsText(14, w: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _GaugeBox extends StatelessWidget {
  const _GaugeBox(this.g);
  final OpsGauge g;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: OpsColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OpsColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(g.label, style: opsText(12, color: OpsColors.faint))),
              Text('${g.pct}٪', style: opsText(12, w: FontWeight.w900, color: g.color)),
            ],
          ),
          const SizedBox(height: 6),
          OpsBar(fraction: g.pct / 100, color: g.color, height: 8),
        ],
      ),
    );
  }
}

class _TransferBox extends StatelessWidget {
  const _TransferBox(this.t);
  final OpsTransfer t;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String value, {bool strong = false}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: strong ? OpsColors.blue.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: strong ? OpsColors.blue.withValues(alpha: 0.35) : OpsColors.line),
            ),
            child: Column(
              children: [
                Text(label, style: opsText(12, color: OpsColors.faint)),
                const SizedBox(height: 2),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: opsText(12, w: FontWeight.w800, color: strong ? OpsColors.blue : OpsColors.ink),
                ),
              ],
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OpsColors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OpsColors.blue.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CmdIcon('sync', size: 15, color: OpsColors.blue, stroke: 2),
              const SizedBox(width: 6),
              Text('تحويل — ${t.kind}', style: opsText(12, w: FontWeight.w800, color: OpsColors.blue)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              cell('من', t.from),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: CmdIcon('arrowL', size: 18, color: OpsColors.blue, stroke: 2),
              ),
              cell('إلى', t.to, strong: true),
            ],
          ),
        ],
      ),
    );
  }
}
