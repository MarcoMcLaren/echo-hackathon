// Stub port of src/screens/SendCoinScreen.tsx. Replaced with the full port
// (keypad, route strip) by a later task.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/theme_store.dart';

class SendCoinScreen extends StatelessWidget {
  const SendCoinScreen({
    super.key,
    required this.contactId,
    required this.onBack,
  });

  final String contactId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    return ColoredBox(
      color: c.paper,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Send to $contactId',
              style: TextStyle(color: c.ink, fontSize: 21),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onBack, child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}
