// Who can I get to right now — answered before the list answers "who said
// what". Ported from src/features/messaging/components/ReachMap.tsx.
//
// Positions are geometry, not decoration: a direct peer sits inside your
// radio ring, a relayed one sits outside it but hangs off the peer that
// carries it, and an unreachable one sits beyond everything with no line at
// all. Reading the picture should tell you the same thing as reading the hop
// count.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/echo_theme.dart';
import 'type.dart';

const _h = 178.0;
const _r1 = 52.0; // direct BLE reach
const _r2 = 86.0; // edge of the mesh, one hop out

class MapNode {
  final String id;
  final String name;
  final int? hops;
  const MapNode({required this.id, required this.name, required this.hops});
}

class ReachMap extends StatelessWidget {
  final List<MapNode> nodes;
  const ReachMap({super.key, required this.nodes});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;

    return SizedBox(
      height: _h,
      width: double.infinity,
      child: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w <= 0) return const SizedBox.shrink();

        final cx = w / 2;
        final you = Offset(cx, _h - 46);

        final direct = nodes.where((n) => n.hops == 0).toList();
        final relayed = nodes.where((n) => n.hops != null && n.hops! > 0).toList();
        final gone = nodes.where((n) => n.hops == null).toList();

        Offset place(int i, int count, double radius) {
          const spread = math.pi * 0.62;
          final a = count == 1 ? -math.pi / 2 : -math.pi / 2 - spread / 2 + (spread * i) / (count - 1);
          return Offset(you.dx + math.cos(a) * radius, you.dy + math.sin(a) * radius);
        }

        final directAt = [for (var i = 0; i < direct.length; i++) place(i, direct.length, _r1 - 6)];
        // Each relayed peer hangs off a direct one — the phone actually carrying it.
        final relayedAt = [
          for (var i = 0; i < relayed.length; i++)
            () {
              final anchor = directAt.isNotEmpty ? directAt[i % directAt.length] : you;
              final dx = anchor.dx - you.dx;
              final x = (anchor.dx + (dx >= 0 ? 74 : -74)).clamp(28.0, w - 28.0);
              final y = math.max(20.0, anchor.dy - 34);
              return Offset(x, y);
            }(),
        ];

        String label(String name) => name.split(' ')[0].toUpperCase().substring(0, math.min(8, name.split(' ')[0].length));

        Widget dashedRing(Offset at, double r) => Positioned(
              left: at.dx - r,
              top: at.dy - r,
              width: r * 2,
              height: r * 2,
              child: CustomPaint(painter: _DashedCirclePainter(color: c.hair)),
            );

        Widget line(Offset a, Offset b, Color color) {
          final len = (b - a).distance;
          final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
          const width = 3.0;
          return Positioned(
            left: a.dx,
            top: a.dy - width / 2,
            child: Transform.rotate(
              angle: angle,
              alignment: const Alignment(-1, 0),
              child: Container(
                width: len,
                height: width,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(width / 2)),
              ),
            ),
          );
        }

        Widget station(Offset at, Color color, {Color? fill, double r = 5.5}) => Positioned(
              left: at.dx - r,
              top: at.dy - r,
              width: r * 2,
              height: r * 2,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill ?? color,
                  border: fill != null ? Border.all(color: color, width: 3) : null,
                ),
              ),
            );

        Widget nodeLabel(Offset at, String text, {bool faint = false}) => Positioned(
              left: at.dx - 40,
              top: at.dy,
              width: 80,
              child: Opacity(
                opacity: faint ? 0.55 : 1,
                child: Center(child: MonoText(text, size: 8)),
              ),
            );

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            dashedRing(you, _r1),
            dashedRing(you, _r2),
            for (final p in directAt) line(you, p, c.direct),
            for (var i = 0; i < relayedAt.length; i++)
              line(directAt.isNotEmpty ? directAt[i % directAt.length] : you, relayedAt[i], c.relay),
            for (final p in directAt) station(p, c.direct, fill: c.paper),
            for (final p in relayedAt) station(p, c.relay, fill: c.paper),
            for (var i = 0; i < gone.length; i++)
              station(Offset(math.min(w - 24, you.dx + 118 + i * 22), you.dy - 4), c.dim, r: 5),
            station(you, c.ink, r: 7),
            nodeLabel(Offset(you.dx, you.dy + 11), 'YOU'),
            for (var i = 0; i < directAt.length; i++) nodeLabel(Offset(directAt[i].dx, directAt[i].dy - 21), label(direct[i].name)),
            for (var i = 0; i < relayedAt.length; i++) nodeLabel(Offset(relayedAt[i].dx, relayedAt[i].dy - 21), label(relayed[i].name)),
            for (var i = 0; i < gone.length; i++)
              nodeLabel(Offset(math.min(w - 24, you.dx + 118 + i * 22), you.dy + 10), label(gone[i].name), faint: true),
          ],
        );
      }),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    const dashLength = 4.0;
    const gapLength = 3.0;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();
    final anglePerDash = 2 * math.pi / dashCount;
    final dashAngle = anglePerDash * (dashLength / (dashLength + gapLength));

    for (var i = 0; i < dashCount; i++) {
      final start = i * anglePerDash;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, dashAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) => oldDelegate.color != color;
}
