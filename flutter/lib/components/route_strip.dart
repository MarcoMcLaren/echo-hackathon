// THE SIGNATURE COMPONENT.
//
// A three-dot transit line showing the path a message actually took. Chat
// apps hide delivery behind a tick; here the path is the point, so the path
// is on screen. Must match the RN version pixel for pixel — dot sizes,
// segment length and hop colour. Port of src/components/RouteStrip.tsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/theme_store.dart';
import '../styles/theme.dart' as tokens;
import 'type.dart';

class RouteStrip extends StatefulWidget {
  const RouteStrip({
    super.key,
    required this.hops,
    this.via,
    this.label,
    this.animate = false,
    this.big = false,
  });

  /// 0 = direct, >0 = hop count via a relay, null = no route.
  final int? hops;
  final String? via;
  final String? label;

  /// Draws itself left to right once, for a message that just landed.
  final bool animate;
  final bool big;

  @override
  State<RouteStrip> createState() => _RouteStripState();
}

class _RouteStripState extends State<RouteStrip>
    with SingleTickerProviderStateMixin {
  static const _curve = Cubic(0.65, 0, 0.35, 1);

  late final AnimationController _controller;
  late final Animation<double> _grow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: tokens.AppMotion.routeDraw,
      value: widget.animate ? 0 : 1,
    );
    _grow = CurvedAnimation(parent: _controller, curve: _curve);
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);

    final d = widget.big ? 11.0 : 6.0;
    final seg = widget.big ? 34.0 : 14.0;
    final w = widget.big ? 2.5 : 1.5;

    final unreachable = widget.hops == null;
    final line = unreachable ? c.dim : (widget.hops == 0 ? c.direct : c.relay);
    final relayed = widget.hops != null && widget.hops! > 0;

    Widget dot(Color fill, {bool hollow = false}) => Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hollow ? c.paper : fill,
        border: hollow ? Border.all(color: fill, width: w) : null,
      ),
    );

    Widget segment() => Container(width: seg, height: w, color: line);

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // sender ... relay ... you
        dot(unreachable ? c.dim : c.direct),
        segment(),
        if (relayed) ...[dot(c.relay, hollow: true), segment()],
        dot(unreachable ? c.dim : c.ink),
        if (widget.label != null || widget.via != null)
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: Mono(
              widget.label ?? 'VIA ${widget.via!.toUpperCase()}',
              size: widget.big ? 10 : 8.5,
            ),
          ),
      ],
    );

    final opacity = unreachable ? 0.45 : 1.0;

    if (!widget.animate) {
      return Opacity(opacity: opacity, child: row);
    }

    return AnimatedBuilder(
      animation: _grow,
      builder: (context, child) => Opacity(
        opacity: opacity,
        child: Transform(
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..scaleByDouble(_grow.value, 1.0, 1.0, 1.0),
          child: child,
        ),
      ),
      child: row,
    );
  }
}
