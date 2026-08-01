// The ring encodes hop distance, so reachability reads before the name does.
// Port of src/components/Avatar.tsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/theme_store.dart';
import 'type.dart';

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.initials,
    required this.hops,
    this.size = 36,
  });

  final String initials;

  /// 0 = direct, >0 = hop count via a relay, null = no route.
  final int? hops;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final ring = hops == null ? null : (hops == 0 ? c.direct : c.relay);
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
        child: Display(initials, size: size * 0.39, dim: 2),
      ),
    );
  }
}
