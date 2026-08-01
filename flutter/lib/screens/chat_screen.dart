// Stub port of src/screens/ChatScreen.tsx. Replaced with the full port
// (message bubbles, mesh transport, catch-me-up sheet) by a later task.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/theme_store.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.threadId,
    required this.onBack,
    required this.onSendCoin,
  });

  final String threadId;
  final VoidCallback onBack;
  final ValueChanged<String> onSendCoin;

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
              'Chat · $threadId',
              style: TextStyle(color: c.ink, fontSize: 21),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => onSendCoin(threadId),
              child: const Text('Send coin'),
            ),
            TextButton(onPressed: onBack, child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}
