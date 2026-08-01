// Ported from src/features/messaging/components/MessageBubble.tsx.
import 'package:flutter/material.dart';
import '../models/mock.dart' as mock;
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import 'route_strip.dart';
import 'type.dart';

/// Outgoing only. Incoming messages get a route strip instead.
String _stateLine(mock.Msg m) {
  if (m.state == 'queued') return 'QUEUED · NO ROUTE YET';
  // hops counts relays, so 0 relays is a direct hand-off and saying "1 HOP"
  // about it just reads as noise.
  final via = (m.hops != null && m.hops! > 0) ? ' · ${m.hops! + 1} HOPS' : '';
  return '${(m.state ?? 'sent').toUpperCase()}$via · ${m.at}';
}

class MessageBubble extends StatelessWidget {
  final mock.Msg msg;
  final String? senderName;
  final bool animate;

  const MessageBubble({super.key, required this.msg, this.senderName, this.animate = false});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final mine = msg.from == 'me';

    Widget routeOrState() => mine
        ? MonoText(_stateLine(msg), size: 8.5)
        : RouteStrip(
            hops: msg.hops,
            via: msg.via,
            animate: animate,
            label: (msg.hops != null && msg.hops! > 0)
                ? 'VIA ${msg.via?.toUpperCase()} · ${msg.at}'
                : 'DIRECT · ${msg.at}',
          );

    // Money is a first-class message, not an attachment.
    if (msg.coin != null) {
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.86),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Column(
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.coin, width: 1.5),
                    color: c.coin.withAlpha(0x12),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(EchoRadius.bubble),
                      topRight: const Radius.circular(EchoRadius.bubble),
                      bottomLeft: Radius.circular(mine ? EchoRadius.bubble : EchoRadius.tail),
                      bottomRight: Radius.circular(mine ? EchoRadius.tail : EchoRadius.bubble),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonoText(mine ? 'SENT' : 'RECEIVED', size: 9, color: c.coin),
                      const SizedBox(height: 7),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CoinMark(size: 22, color: c.coin),
                          const SizedBox(width: 7),
                          DisplayText(msg.coin!.toStringAsFixed(2), size: 27, color: c.coin),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Opacity(
                        opacity: 0.8,
                        child: MonoText(
                          (msg.hops != null && msg.hops! > 0)
                              ? 'SIGNED ON DEVICE · RELAYED VIA ${msg.via?.toUpperCase()}'
                              : 'SIGNED ON DEVICE · DIRECT',
                          size: 8.5,
                          color: c.coin,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                routeOrState(),
              ],
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.86),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (senderName != null && !mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: MonoText(senderName!.toUpperCase(), size: 9),
                ),
              Opacity(
                opacity: msg.state == 'queued' ? 0.55 : 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: mine ? c.bubbleOut : c.bubbleIn,
                    border: mine ? null : Border.all(color: c.hair2),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(EchoRadius.bubble),
                      topRight: const Radius.circular(EchoRadius.bubble),
                      bottomLeft: Radius.circular(mine ? EchoRadius.bubble : EchoRadius.tail),
                      bottomRight: Radius.circular(mine ? EchoRadius.tail : EchoRadius.bubble),
                    ),
                  ),
                  child: BodyText(msg.text ?? '', size: 12.5, color: mine ? c.bubbleOutInk : c.ink),
                ),
              ),
              const SizedBox(height: 4),
              routeOrState(),
            ],
          ),
        ),
      ),
    );
  }
}
