// Theme scope — ported from styles/theme.ts's ThemeContext. Follows the
// system brightness by default; ReachScreen's header control can override it,
// same as RN's.
import 'package:flutter/material.dart';
import 'palette.dart';

enum ThemeMode { system, light, dark }

class EchoTheme extends InheritedWidget {
  final Palette c;
  final bool isDark;
  final ThemeMode mode;
  final VoidCallback cycle;

  const EchoTheme({
    super.key,
    required this.c,
    required this.isDark,
    required this.mode,
    required this.cycle,
    required super.child,
  });

  static EchoTheme of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<EchoTheme>();
    assert(theme != null, 'No EchoTheme found in context');
    return theme!;
  }

  @override
  bool updateShouldNotify(EchoTheme oldWidget) => oldWidget.c != c || oldWidget.isDark != isDark || oldWidget.mode != mode;
}

/// Wraps [child] with an [EchoTheme]. Follows the system brightness by
/// default; the header control on ReachScreen calls [EchoTheme.cycle] to
/// override it, same as RN's ThemeContext.
class EchoThemeScope extends StatefulWidget {
  final Widget child;
  const EchoThemeScope({super.key, required this.child});

  @override
  State<EchoThemeScope> createState() => _EchoThemeScopeState();
}

class _EchoThemeScopeState extends State<EchoThemeScope> {
  ThemeMode mode = ThemeMode.system;

  void _cycle() {
    setState(() {
      mode = switch (mode) {
        ThemeMode.system => ThemeMode.light,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark = mode == ThemeMode.system ? system : mode == ThemeMode.dark;
    return EchoTheme(c: isDark ? dark : light, isDark: isDark, mode: mode, cycle: _cycle, child: widget.child);
  }
}
