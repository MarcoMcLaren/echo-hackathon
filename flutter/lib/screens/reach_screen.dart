// Stub port of src/screens/ReachScreen.tsx. Replaced with the full port
// (mesh status, contact list, ReachMap) by a later task.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/theme_store.dart';

class ReachScreen extends StatelessWidget {
  const ReachScreen({super.key, required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    return ColoredBox(
      color: c.paper,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reach', style: TextStyle(color: c.ink, fontSize: 21)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => onOpen('naledi'),
              child: const Text('Open demo thread'),
            ),
          ],
        ),
      ),
    );
  }
}
