import 'package:flutter/material.dart';

/// Stroke icons matching site/src/components/Icon.tsx (COMMAND SITREP set).
class CmdIcon extends StatelessWidget {
  const CmdIcon(this.name, {super.key, this.size = 20, this.color = Colors.white, this.stroke = 1.8});

  final String name;
  final double size;
  final Color color;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CmdIconPainter(name: name, color: color, stroke: stroke),
      ),
    );
  }
}

class _CmdIconPainter extends CustomPainter {
  _CmdIconPainter({required this.name, required this.color, required this.stroke});

  final String name;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (name) {
      case 'pulse':
        _path(canvas, p, [
          const Offset(2, 12),
          const Offset(6, 12),
          const Offset(9, 5),
          const Offset(13, 19),
          const Offset(16, 12),
          const Offset(22, 12),
        ]);
      case 'home':
        final home = Path()
          ..moveTo(3, 11)
          ..lineTo(12, 4)
          ..lineTo(21, 11)
          ..lineTo(21, 20)
          ..quadraticBezierTo(21, 21, 20, 21)
          ..lineTo(15, 21)
          ..lineTo(15, 15)
          ..lineTo(9, 15)
          ..lineTo(9, 21)
          ..lineTo(4, 21)
          ..quadraticBezierTo(3, 21, 3, 20)
          ..close();
        canvas.drawPath(home, p);
      case 'truck':
        _drawTruck(canvas, p);
      case 'ambulance':
        _drawTruck(canvas, p);
        canvas.drawLine(const Offset(5.5, 9.5), const Offset(5.5, 13.5), p);
        canvas.drawLine(const Offset(9, 9.5), const Offset(9, 13.5), p);
        canvas.drawLine(const Offset(5.5, 11.5), const Offset(9, 11.5), p);
      case 'pin':
        final pin = Path()
          ..moveTo(12, 22)
          ..cubicTo(12, 22, 19, 15, 19, 10)
          ..arcToPoint(const Offset(5, 10), radius: const Radius.circular(7), largeArc: true, clockwise: false)
          ..cubicTo(5, 15, 12, 22, 12, 22)
          ..close();
        canvas.drawPath(pin, p);
        canvas.drawCircle(const Offset(12, 10), 2.5, p);
      case 'chart':
        canvas.drawLine(const Offset(4, 20), const Offset(4, 10), p);
        canvas.drawLine(const Offset(10, 20), const Offset(10, 4), p);
        canvas.drawLine(const Offset(16, 20), const Offset(16, 13), p);
        canvas.drawLine(const Offset(22, 20), const Offset(2, 20), p);
      case 'gear':
        canvas.drawCircle(const Offset(12, 12), 3, p);
        const spokes = [
          [Offset(12, 2), Offset(12, 5)],
          [Offset(12, 19), Offset(12, 22)],
          [Offset(4.2, 4.2), Offset(6.3, 6.3)],
          [Offset(17.7, 17.7), Offset(19.8, 19.8)],
          [Offset(2, 12), Offset(5, 12)],
          [Offset(19, 12), Offset(22, 12)],
          [Offset(4.2, 19.8), Offset(6.3, 17.7)],
          [Offset(17.7, 6.3), Offset(19.8, 4.2)],
        ];
        for (final s in spokes) {
          canvas.drawLine(s[0], s[1], p);
        }
      case 'user':
        canvas.drawCircle(const Offset(12, 8), 4, p);
        final body = Path()
          ..moveTo(4, 21)
          ..cubicTo(5.5, 17, 8.5, 15, 12, 15)
          ..cubicTo(15.5, 15, 18.5, 17, 20, 21);
        canvas.drawPath(body, p);
      case 'driver':
        canvas.drawCircle(const Offset(12, 8), 4, p);
        final shoulders = Path()
          ..moveTo(2, 20)
          ..cubicTo(2, 16, 6.5, 13, 12, 13)
          ..cubicTo(17.5, 13, 22, 16, 22, 20);
        canvas.drawPath(shoulders, p);
        canvas.drawLine(const Offset(12, 14), const Offset(12, 20), p);
        canvas.drawLine(const Offset(9, 17), const Offset(15, 17), p);
      case 'warn':
        final tri = Path()
          ..moveTo(12, 3)
          ..lineTo(22, 21)
          ..lineTo(2, 21)
          ..close();
        canvas.drawPath(tri, p);
        canvas.drawLine(const Offset(12, 10), const Offset(12, 15), p);
        canvas.drawLine(const Offset(12, 18), const Offset(12, 18.5), p);
      case 'check':
        _path(canvas, p, [const Offset(5, 12), const Offset(10, 17), const Offset(19, 7)]);
      case 'sync':
        final a1 = Path()
          ..moveTo(4, 12)
          ..arcToPoint(const Offset(18, 7), radius: const Radius.circular(8));
        canvas.drawPath(a1, p);
        final a2 = Path()
          ..moveTo(20, 12)
          ..arcToPoint(const Offset(6, 17), radius: const Radius.circular(8));
        canvas.drawPath(a2, p);
        _path(canvas, p, [const Offset(18, 3), const Offset(18, 7), const Offset(14, 7)]);
        _path(canvas, p, [const Offset(6, 21), const Offset(6, 17), const Offset(10, 17)]);
      case 'shield':
        final sh = Path()
          ..moveTo(12, 2)
          ..lineTo(20, 5)
          ..lineTo(20, 11)
          ..cubicTo(20, 16, 16.5, 20, 12, 22)
          ..cubicTo(7.5, 20, 4, 16, 4, 11)
          ..lineTo(4, 5)
          ..close();
        canvas.drawPath(sh, p);
        _path(canvas, p, [const Offset(9, 11.5), const Offset(11, 13.5), const Offset(15, 9)]);
      case 'search':
        canvas.drawCircle(const Offset(11, 11), 7, p);
        canvas.drawLine(const Offset(20, 20), const Offset(16, 16), p);
      case 'cal':
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3, 5, 18, 16), const Radius.circular(2)), p);
        canvas.drawLine(const Offset(3, 10), const Offset(21, 10), p);
        canvas.drawLine(const Offset(8, 3), const Offset(8, 7), p);
        canvas.drawLine(const Offset(16, 3), const Offset(16, 7), p);
      case 'clock':
        canvas.drawCircle(const Offset(12, 12), 9, p);
        _path(canvas, p, [const Offset(12, 7), const Offset(12, 12), const Offset(15, 14)]);
      case 'arrowL':
        canvas.drawLine(const Offset(19, 12), const Offset(5, 12), p);
        _path(canvas, p, [const Offset(11, 6), const Offset(5, 12), const Offset(11, 18)]);
      case 'clip':
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(4, 4, 16, 17), const Radius.circular(2)), p);
        _path(canvas, p, [const Offset(9, 2), const Offset(9, 6), const Offset(15, 6), const Offset(15, 2)]);
        canvas.drawLine(const Offset(8, 12), const Offset(16, 12), p);
        canvas.drawLine(const Offset(8, 16), const Offset(13, 16), p);
      case 'grid':
        for (final r in const [
          Rect.fromLTWH(3, 3, 8, 8),
          Rect.fromLTWH(13, 3, 8, 5),
          Rect.fromLTWH(13, 10, 8, 11),
          Rect.fromLTWH(3, 13, 8, 8),
        ]) {
          canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(1.5)), p);
        }
      case 'folder':
        final folder = Path()
          ..moveTo(4, 4)
          ..lineTo(10, 4)
          ..lineTo(12, 6)
          ..lineTo(20, 6)
          ..lineTo(20, 20)
          ..lineTo(4, 20)
          ..close();
        canvas.drawPath(folder, p);
      case 'prison':
        final roof = Path()
          ..moveTo(3, 9)
          ..lineTo(12, 4)
          ..lineTo(21, 9);
        canvas.drawPath(roof, p);
        for (final x in [5.0, 9.5, 14.5, 19.0]) {
          canvas.drawLine(Offset(x, 10), Offset(x, 18), p);
        }
        canvas.drawLine(const Offset(3, 20), const Offset(21, 20), p);
      case 'kit':
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3, 6, 18, 14), const Radius.circular(2)), p);
        canvas.drawLine(const Offset(9, 6), const Offset(9, 4), p);
        canvas.drawLine(const Offset(9, 4), const Offset(15, 4), p);
        canvas.drawLine(const Offset(15, 4), const Offset(15, 6), p);
        canvas.drawLine(const Offset(9, 10), const Offset(9, 16), p);
        canvas.drawLine(const Offset(15, 10), const Offset(15, 16), p);
        canvas.drawLine(const Offset(9, 13), const Offset(15, 13), p);
      case 'hospital':
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(5, 5, 14, 16), const Radius.circular(1.5)), p);
        canvas.drawLine(const Offset(3, 21), const Offset(21, 21), p);
        canvas.drawCircle(const Offset(12, 11), 3.4, p);
        canvas.drawLine(const Offset(10.6, 9.4), const Offset(10.6, 12.6), p);
        canvas.drawLine(const Offset(13.4, 9.4), const Offset(13.4, 12.6), p);
        canvas.drawLine(const Offset(10.6, 11), const Offset(13.4, 11), p);
        canvas.drawLine(const Offset(9.5, 21), const Offset(9.5, 17.6), p);
        canvas.drawLine(const Offset(9.5, 17.6), const Offset(14.5, 17.6), p);
        canvas.drawLine(const Offset(14.5, 17.6), const Offset(14.5, 21), p);
      case 'medcenter':
        final roof = Path()
          ..moveTo(3, 9.5)
          ..lineTo(12, 4)
          ..lineTo(21, 9.5);
        canvas.drawPath(roof, p);
        final body = Path()
          ..moveTo(5, 9)
          ..lineTo(5, 21)
          ..lineTo(19, 21)
          ..lineTo(19, 9);
        canvas.drawPath(body, p);
        canvas.drawLine(const Offset(3, 21), const Offset(21, 21), p);
        canvas.drawLine(const Offset(10, 13), const Offset(10, 17), p);
        canvas.drawLine(const Offset(14, 13), const Offset(14, 17), p);
        canvas.drawLine(const Offset(10, 15), const Offset(14, 15), p);
      case 'box':
        final outer = Path()
          ..moveTo(12, 2)
          ..lineTo(21, 7)
          ..lineTo(21, 17)
          ..lineTo(12, 22)
          ..lineTo(3, 17)
          ..lineTo(3, 7)
          ..close();
        canvas.drawPath(outer, p);
        canvas.drawLine(const Offset(3, 7), const Offset(12, 12), p);
        canvas.drawLine(const Offset(12, 12), const Offset(21, 7), p);
        canvas.drawLine(const Offset(12, 12), const Offset(12, 22), p);
      case 'cap':
        final top = Path()
          ..moveTo(2, 9)
          ..lineTo(12, 4)
          ..lineTo(22, 9)
          ..lineTo(12, 14)
          ..close();
        canvas.drawPath(top, p);
        final brim = Path()
          ..moveTo(6, 11)
          ..lineTo(6, 16)
          ..cubicTo(9, 18.5, 15, 18.5, 18, 16)
          ..lineTo(18, 11);
        canvas.drawPath(brim, p);
      default:
        canvas.drawCircle(const Offset(12, 12), 4, p);
    }
  }

  void _drawTruck(Canvas canvas, Paint p) {
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(1, 7, 13, 9), const Radius.circular(1)), p);
    final cabin = Path()
      ..moveTo(14, 10)
      ..lineTo(18, 10)
      ..lineTo(21, 13)
      ..lineTo(21, 16)
      ..lineTo(14, 16)
      ..close();
    canvas.drawPath(cabin, p);
    canvas.drawCircle(const Offset(6, 18), 2, p);
    canvas.drawCircle(const Offset(17, 18), 2, p);
  }

  void _path(Canvas canvas, Paint paint, List<Offset> pts) {
    if (pts.isEmpty) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CmdIconPainter oldDelegate) =>
      oldDelegate.name != name || oldDelegate.color != color || oldDelegate.stroke != stroke;
}

/// Colored rounded icon tile used on SITREP cards.
class CmdIconTile extends StatelessWidget {
  const CmdIconTile({
    super.key,
    required this.name,
    required this.tone,
    this.size = 42,
    this.iconSize = 20,
  });

  final String name;
  final Color tone;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.31),
        gradient: LinearGradient(colors: [tone, Color.lerp(tone, Colors.black, 0.18)!]),
        boxShadow: [BoxShadow(color: tone.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      alignment: Alignment.center,
      child: CmdIcon(name, size: iconSize, color: Colors.white, stroke: 1.85),
    );
  }
}
