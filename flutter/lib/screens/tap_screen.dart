// Stub port of src/screens/TapScreen.tsx. Replaced with the full port
// (NFC/QR pairing, camera preview) by a later task.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/theme_store.dart';

class TapScreen extends StatelessWidget {
  const TapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    return ColoredBox(
      color: c.paper,
      child: Center(
        child: Text('Meet', style: TextStyle(color: c.ink, fontSize: 21)),
      ),
    );
  }
}
