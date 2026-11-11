import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../data/command_data.dart';
import '../../theme/cmd_icon.dart';
import 'ops_chrome.dart';
import 'ops_live.dart';
import '../../theme/tokens.dart';

enum _Layer { event, ambulance, hospital, prison, point, warehouse }

class _LayerMeta {
  const _LayerMeta(this.label, this.icon, this.color);
  final String label;
  final String icon;
  final Color color;
}

const _layers = <_Layer, _LayerMeta>{
  _Layer.event: _LayerMeta('أحداث نشطة', 'pulse', OpsColors.red),
  _Layer.ambulance: _LayerMeta('إسعاف', 'ambulance', OpsColors.blue),
  _Layer.hospital: _LayerMeta('مشافي', 'hospital', OpsColors.green),
  _Layer.prison: _LayerMeta('سجون', 'prison', OpsColors.teal),
  _Layer.point: _LayerMeta('نقاط طبية', 'kit', OpsColors.cyan),
  _Layer.warehouse: _LayerMeta('مستودعات', 'box', OpsColors.amber),
};

class _Asset {
  const _Asset(this.id, this.layer, this.label, this.sub, this.province, this.status, this.tone, this.lat, this.lng,
      {this.critical = false});
  final String id;
  final _Layer layer;
  final String label;
  final String sub;
  final String province;
  final String status;
  final Color tone;
  final double lat;
  final double lng;
  final bool critical;
}

double? _coord(Object? value) => value is num ? value.toDouble() : null;

(double, double)? _pair(JsonRow row) {
  final pos = row['pos'];
  if (pos is List && pos.length >= 2) {
    final lat = _coord(pos[0]);
    final lng = _coord(pos[1]);
    if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180) return (lat, lng);
  }
  final lat = _coord(row['lat'] ?? row['latitude']);
  final lng = _coord(row['lng'] ?? row['lon'] ?? row['longitude']);
  if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) return null;
  return (lat, lng);
}

List<_Asset> _assetsFrom(CommandData d) {
  if (d.boardMarkers.isNotEmpty) {
    final pinned = <_Asset>[];
    for (final m in d.boardMarkers) {
      final pos = m['pos'];
      if (pos is! List || pos.length < 2 || pos[0] is! num || pos[1] is! num) continue;
      final type = m['type']?.toString();
      final layer = switch (type) {
        'event' => _Layer.event,
        'ambulance' => _Layer.ambulance,
        'hospital' => _Layer.hospital,
        'prison' => _Layer.prison,
        'warehouse' => _Layer.warehouse,
        _ => _Layer.point,
      };
      pinned.add(_Asset(
        m['id']?.toString() ?? '',
        layer,
        m['label']?.toString() ?? '',
        m['sub']?.toString() ?? '',
        m['province']?.toString() ?? '',
        m['status']?.toString() ?? '',
        layer == _Layer.event ? OpsColors.red : OpsColors.cyan,
        (pos[0] as num).toDouble(),
        (pos[1] as num).toDouble(),
        critical: m['critical'] == true,
      ));
    }
    if (pinned.isNotEmpty) return pinned;
  }

  final out = <_Asset>[];
  for (final f in d.facilities) {
    final at = _pair(f);
    if (at == null) continue;
    final id = f['id']?.toString() ?? '';
    final province = f['provinceAr']?.toString() ?? '';
    final layer = switch (f['type']) {
      CommandData.hospital => _Layer.hospital,
      CommandData.prison => _Layer.prison,
      CommandData.warehouse => _Layer.warehouse,
      _ => _Layer.point,
    };
    final active = f['isActive'] != false;
    final open = d.events[id]?.where(CommandData.isOpen).length;
    out.add(_Asset(
      id,
      layer,
      f['nameAr']?.toString() ?? id,
      open == null ? (f['typeAr']?.toString() ?? '') : '$open حدث مفتوح',
      province,
      active ? 'فعّالة' : 'غير فعّالة',
      active ? OpsColors.green : OpsColors.red,
      at.$1,
      at.$2,
      critical: !active,
    ));
  }
  for (final rows in d.fleet.values) {
    for (final v in rows ?? const <JsonRow>[]) {
      if (v['status'] != 'OnMission') continue;
      final at = _pair(v);
      if (at == null) continue;
      out.add(_Asset(
        v['code']?.toString() ?? '',
        _Layer.ambulance,
        v['code']?.toString() ?? 'مركبة',
        (v['missionNote']?.toString().isNotEmpty ?? false) ? v['missionNote'].toString() : 'في مهمة',
        v['province']?.toString() ?? '',
        v['statusAr']?.toString() ?? 'في مهمة',
        OpsColors.blue,
        at.$1,
        at.$2,
      ));
    }
  }
  return out;
}

/// الخريطة التفاعلية — facilities, open events and vehicles on mission, placed by province.
class OpsMapScreen extends StatefulWidget {
  const OpsMapScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<OpsMapScreen> createState() => _OpsMapScreenState();
}

class _OpsMapScreenState extends State<OpsMapScreen> {
  final Set<_Layer> _on = {..._Layer.values};
  String? _selected;

  static const _latMin = 32.6, _latMax = 36.6, _lngMin = 35.6, _lngMax = 38.4;

  Offset _pos(_Asset a) {
    final x = ((a.lng - _lngMin) / (_lngMax - _lngMin)).clamp(0.04, 0.96);
    final y = ((_latMax - a.lat) / (_latMax - _latMin)).clamp(0.05, 0.95);
    return Offset(x, y);
  }

  OpsItem _toItem(_Asset a) {
    final m = _layers[a.layer]!;
    return OpsItem(
      id: a.id,
      title: a.label,
      subtitle: '${a.sub} · ${a.province}',
      icon: m.icon,
      tone: a.tone,
      pills: [OpsPill(a.status, a.tone), OpsPill(m.label, m.color)],
      bannerTitle: a.sub,
      bannerSub: '${a.province} · ${a.lat.toStringAsFixed(3)}, ${a.lng.toStringAsFixed(3)}',
      info: [
        ('الطبقة', m.label),
        ('المحافظة', a.province),
        ('الحالة', a.status),
        ('الإحداثيات', '${a.lat.toStringAsFixed(2)}, ${a.lng.toStringAsFixed(2)}'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => OpsLive(
        api: widget.api,
        title: 'الخريطة التفاعلية',
        eyebrow: 'MAP · LIVE ASSETS',
        builder: (context, d, eyebrow, refresh) {
          final assets = _assetsFrom(d);
          if (assets.isEmpty) {
            return OpsScaffold(
              title: 'الخريطة التفاعلية',
              eyebrow: eyebrow,
              onRefresh: refresh,
              children: const [OpsEmpty('لا توجد بيانات مواقع من الخادم')],
            );
          }
          return _body(assets, eyebrow, refresh);
        },
      );

  Widget _body(List<_Asset> assets, String eyebrow, Future<void> Function() refresh) {
    final visible = assets.where((a) => _on.contains(a.layer)).toList();
    final critical = visible.where((a) => a.critical).length;

    return OpsScaffold(
      title: 'الخريطة التفاعلية',
      eyebrow: eyebrow,
      onRefresh: refresh,
      children: [
        OpsKpiRow(
          kpis: [
            OpsKpi('أصول معروضة', '${visible.length}', 'pin', OpsColors.cyan),
            OpsKpi('حالات حرجة', '$critical', 'warn', OpsColors.red),
            OpsKpi('طبقات فعّالة', '${_on.length}/${_layers.length}', 'grid', OpsColors.blue),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _layers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final layer = _layers.keys.elementAt(i);
              final m = _layers[layer]!;
              final on = _on.contains(layer);
              return GestureDetector(
                onTap: () => setState(() {
                  if (on) {
                    _on.remove(layer);
                  } else {
                    _on.add(layer);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: on ? m.color.withValues(alpha: 0.14) : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: on ? m.color.withValues(alpha: 0.6) : OpsColors.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CmdIcon(m.icon, size: 15, color: on ? m.color : OpsColors.faint),
                      const SizedBox(width: 6),
                      Text(m.label, style: opsText(12, w: on ? FontWeight.w800 : FontWeight.w600, color: on ? m.color : OpsColors.sub)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _mapCanvas(visible),
        const SizedBox(height: 14),
        const OpsSectionTitle(no: '02', title: 'الأصول على الخريطة'),
        if (visible.isEmpty) const OpsEmpty('لا توجد طبقات مفعّلة'),
        for (final a in visible) ...[
          _assetRow(a),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _mapCanvas(List<_Asset> visible) {
    return OpsCard(
      tone: OpsColors.cyan,
      padding: const EdgeInsets.all(6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 1.05,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              const pad = 18.0;
              return Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _GridPainter())),
                  // HQ marker (دمشق).
                  Positioned(
                    left: w * 0.27 - 15,
                    top: h * 0.76 - 15,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [OpsColors.teal, OpsColors.ink]),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: const CmdIcon('shield', size: 15, color: Colors.white, stroke: 2),
                    ),
                  ),
                  for (final label in const [
                    ('حلب', 0.62, 0.06),
                    ('اللاذقية', 0.05, 0.22),
                    ('حمص', 0.34, 0.5),
                    ('دمشق', 0.2, 0.84),
                  ])
                    Positioned(
                      left: w * label.$2,
                      top: h * label.$3,
                      child: Text(label.$1, style: opsText(12, w: FontWeight.w700, color: OpsColors.faint)),
                    ),
                  for (final a in visible)
                    () {
                      final p = _pos(a);
                      final on = _selected == a.id;
                      final m = _layers[a.layer]!;
                      final size = on ? 34.0 : 26.0;
                      return Positioned(
                        left: (w - pad) * p.dx - size / 2 + pad / 2,
                        top: (h - pad) * p.dy - size / 2 + pad / 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selected = a.id);
                            showOpsDetail(context, _toItem(a), kindLabel: m.label);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              color: m.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: a.critical ? OpsColors.red : Colors.white, width: a.critical ? 3 : 2),
                              boxShadow: [BoxShadow(color: m.color.withValues(alpha: 0.45), blurRadius: on ? 14 : 8)],
                            ),
                            alignment: Alignment.center,
                            child: CmdIcon(m.icon, size: on ? 16 : 13, color: Colors.white, stroke: 2),
                          ),
                        ),
                      );
                    }(),
                  Positioned(
                    bottom: 8,
                    right: 10,
                    child: Text('MAP PLACEHOLDER', style: opsText(12, w: FontWeight.w800, color: OpsColors.faint)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _assetRow(_Asset a) {
    final m = _layers[a.layer]!;
    final on = _selected == a.id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() => _selected = a.id);
          showOpsDetail(context, _toItem(a), kindLabel: m.label);
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: on ? OpsColors.cyan.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? OpsColors.cyan.withValues(alpha: 0.5) : OpsColors.line),
          ),
          child: Row(
            children: [
              CmdIconTile(name: m.icon, tone: m.color, size: 36, iconSize: 17),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: opsText(13, w: FontWeight.w800)),
                    Text('${a.id} · ${a.sub} · ${a.province}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: opsText(12, color: OpsColors.faint)),
                  ],
                ),
              ),
              OpsPillTag(a.status, a.tone),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [MsdTokens.mist, MsdTokens.mist],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);
    final line = Paint()
      ..color = MsdTokens.line
      ..strokeWidth = 1;
    const step = 36.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    // Soft land blob (decorative placeholder).
    final land = Paint()..color = MsdTokens.cyanWash;
    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.2)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.02, size.width * 0.92, size.height * 0.12)
      ..quadraticBezierTo(size.width * 0.98, size.height * 0.55, size.width * 0.8, size.height * 0.92)
      ..quadraticBezierTo(size.width * 0.4, size.height * 1.0, size.width * 0.1, size.height * 0.85)
      ..quadraticBezierTo(size.width * 0.02, size.height * 0.5, size.width * 0.12, size.height * 0.2)
      ..close();
    canvas.drawPath(path, land);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
