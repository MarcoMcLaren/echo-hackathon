// App-wide theme mode (RN equivalent: ThemeContext in src/styles/theme.ts).
// Follows the system by default; cycle() overrides it so dark mode is always
// reachable on a demo phone whatever the OS is set to.
import 'package:flutter/material.dart';

import '../styles/theme.dart' as tokens;

class ThemeStore extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  void cycle() {
    _mode = switch (_mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    notifyListeners();
  }

  bool isDark(BuildContext context) {
    return switch (_mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
  }

  tokens.Palette colors(BuildContext context) =>
      isDark(context) ? tokens.dark : tokens.light;
}
