// Who can I get to right now — answered before the list answers "who said
// what". Drawn with plain Positioned boxes rather than an SVG/canvas package,
// so this adds no new dependency: a line is a thin rotated container.
// Port of src/features/messaging/components/ReachMap.tsx.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/type.dart';
import '../../store/theme_store.dart';

class _P {
  const _P(this.x, this.y);
  final double x;
  final double y;
}

class MapNode {
  const MapNode({required this.id, required this.name, required this.hops, this.stranger = false});

  final String id;
  final String name;

  /// 0 = direct, >0 = hop count via a relay, null = no route.
  final int? hops;

  /// A phone in range you have never met. It relays; it is not a contact.
  final bool stranger;
}

const double _h = 178;
const double _r1 = 52; // direct BLE reach
const double _r2 = 86; // edge of the mesh, one hop out

String _label(String name) {
  final first = name.split(' ').first.toUpperCase();
  return first.length > 8 ? first.substring(0, 8) : first;
}

Widget _line(_P a, _P b, Color color, {double w = 3}) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final len = sqrt(dx * dx + dy * dy);
  final angle = atan2(dy, dx);
  return Positioned(
    left: a.x,
    top: a.y - w / 2,
    child: Transform(
      alignment: Alignment.centerLeft,
      transform: Matrix4.identity()..rotateZ(angle),
      child: Container(
        width: len,
        height: w,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(w / 2)),
      ),
    ),
  );
}

Widget _station(_P at, Color color, {Color? fill, double r = 5.5}) {
  return Positioned(
    left: at.x - r,
    top: at.y - r,
    child: Container(
      width: r * 2,
      height: r * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill ?? color,
        border: fill != null ? Border.all(color: color, width: 3) : null,
      ),
    ),
  );
}

Widget _labelAt(_P at, String text, {bool faint = false}) {
  return Positioned(
    left: at.x - 40,
    top: at.y,
    width: 80,
    child: Center(
      child: Opacity(opacity: faint ? 0.55 : 1, child: Mono(text, size: 8)),
    ),
  );
}

Widget _ring(_P at, double r, Color color) {
  return Positioned(
    left: at.x - r,
    top: at.y - r,
    child: Container(
      width: r * 2,
      height: r * 2,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 1)),
    ),
  );
}

/// Positions are geometry, not decoration: a direct peer sits inside your
/// radio ring, a relayed one sits outside it but hangs off the peer that
/// carries it, and an unreachable one sits beyond everything with no line at
/// all. Reading the picture should tell you the same thing as reading the hop
/// count.
class ReachMap extends StatelessWidget {
  const ReachMap({super.key, required this.nodes});

  final List<MapNode> nodes;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);

    final direct = nodes.where((n) => n.hops == 0).toList();
    final relayed = nodes.where((n) => n.hops != null && n.hops! > 0).toList();
    final gone = nodes.where((n) => n.hops == null).toList();

    return SizedBox(
      height: _h,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          if (w <= 0) return const SizedBox.shrink();
          final cx = w / 2;
          final you = _P(cx, _h - 46);

          _P place(int i, int count, double radius) {
            const spread = pi * 0.62;
            final a = count == 1
                ? -pi / 2
                : -pi / 2 - spread / 2 + (spread * i) / (count - 1);
            return _P(you.x + cos(a) * radius, you.y + sin(a) * radius);
          }

          final directAt = [for (var i = 0; i < direct.length; i++) place(i, direct.length, _r1 - 6)];
          final relayedAt = [
            for (var i = 0; i < relayed.length; i++)
              () {
                final anchor = directAt.isNotEmpty ? directAt[i % directAt.length] : you;
                final dx = anchor.x - you.x;
                return _P(
                  (anchor.x + (dx >= 0 ? 74 : -74)).clamp(28, w - 28),
                  max(20, anchor.y - 34),
                );
              }(),
          ];

          return ClipRect(
            child: Stack(
              children: [
                _ring(you, _r1, c.hair),
                _ring(you, _r2, c.hair2),
                for (var i = 0; i < directAt.length; i++)
                  _line(you, directAt[i], direct[i].stranger ? c.hair : c.direct),
                for (var i = 0; i < relayedAt.length; i++)
                  _line(directAt.isNotEmpty ? directAt[i % directAt.length] : you, relayedAt[i], c.relay),
                for (var i = 0; i < directAt.length; i++)
                  // A stranger is drawn hollow and grey: present, carrying
                  // traffic, but not someone you know.
                  _station(directAt[i], direct[i].stranger ? c.dim : c.direct, fill: c.paper),
                for (final p in relayedAt) _station(p, c.relay, fill: c.paper),
                for (var i = 0; i < gone.length; i++)
                  _station(_P(min(w - 24, you.x + 118 + i * 22), you.y - 4), c.dim, r: 5),
                _station(you, c.ink, r: 7),
                _labelAt(_P(you.x, you.y + 11), 'YOU'),
                for (var i = 0; i < directAt.length; i++)
                  // Strangers are not named. You have not met them, and
                  // showing a device model would imply you had.
                  _labelAt(
                    _P(directAt[i].x, directAt[i].y - 21),
                    direct[i].stranger ? 'NODE' : _label(direct[i].name),
                    faint: direct[i].stranger,
                  ),
                for (var i = 0; i < relayedAt.length; i++)
                  _labelAt(_P(relayedAt[i].x, relayedAt[i].y - 21), _label(relayed[i].name)),
                for (var i = 0; i < gone.length; i++)
                  _labelAt(
                    _P(min(w - 24, you.x + 118 + i * 22), you.y + 10),
                    _label(gone[i].name),
                    faint: true,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
