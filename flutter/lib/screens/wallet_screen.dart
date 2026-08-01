// Stub port of src/screens/WalletScreen.tsx. Replaced with the full port
// (balance, ledger, route strip) by a later task.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/theme_store.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, required this.onSend, required this.onTap});

  final VoidCallback onSend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    return ColoredBox(
      color: c.paper,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Wallet', style: TextStyle(color: c.ink, fontSize: 21)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onSend, child: const Text('Send')),
            TextButton(onPressed: onTap, child: const Text('Go to Meet')),
          ],
        ),
      ),
    );
  }
}
