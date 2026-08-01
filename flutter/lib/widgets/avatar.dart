// Ported from src/components/Avatar.tsx.
import 'package:flutter/material.dart';
import '../theme/echo_theme.dart';
import 'type.dart';

/// The ring encodes hop distance, so reachability reads before the name does.
class Avatar extends StatelessWidget {
  final String initials;
  final int? hops;
  final double size;

  const Avatar({super.key, required this.initials, required this.hops, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final ring = hops == null ? null : hops == 0 ? c.direct : c.relay;
    return Opacity(
      opacity: hops == null ? 0.45 : 1,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.sunk,
          shape: BoxShape.circle,
          border: ring != null ? Border.all(color: ring, width: 2) : null,
        ),
        child: DisplayText(initials, size: size * 0.39, dim: Dim.two),
      ),
    );
  }
}
