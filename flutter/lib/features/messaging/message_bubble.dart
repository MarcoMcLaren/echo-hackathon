// A single chat message: text, or money as a first-class message rather than
// an attachment. Port of src/features/messaging/components/MessageBubble.tsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/type.dart';
import '../../components/route_strip.dart';
import '../../store/mock.dart' as mock;
import '../../store/theme_store.dart';
import '../../styles/theme.dart' as tokens;

/// Outgoing only. Incoming messages get a route strip instead.
String _stateLine(mock.Msg m) {
  if (m.state == mock.MsgState.queued) return 'QUEUED · NO ROUTE YET';
  // hops counts relays, so 0 relays is a direct hand-off and saying "1 HOP"
  // about it just reads as noise.
  final via = (m.hops != null && m.hops! > 0) ? ' · ${m.hops! + 1} HOPS' : '';
  final state = (m.state?.name ?? 'sent').toUpperCase();
  return '$state$via · ${m.at}';
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.msg, this.senderName, this.animate = false});

  final mock.Msg msg;
  final String? senderName;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final mine = msg.from == 'me';
    final crossAxis = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final Widget footer = mine
        ? Mono(_stateLine(msg), size: 8.5)
        : RouteStrip(
            hops: msg.hops,
            via: msg.via,
            animate: animate,
            label: (msg.hops != null && msg.hops! > 0)
                ? 'VIA ${msg.via?.toUpperCase()} · ${msg.at}'
                : 'DIRECT · ${msg.at}',
          );

    Widget content;
    if (msg.coin != null) {
      final relayed = msg.hops != null && msg.hops! > 0;
      content = Container(
        constraints: const BoxConstraints(minWidth: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: c.coin, width: 1.5),
          color: c.coin.withAlpha(0x12),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(tokens.AppRadius.bubble),
            topRight: const Radius.circular(tokens.AppRadius.bubble),
            bottomLeft: Radius.circular(mine ? tokens.AppRadius.bubble : tokens.AppRadius.tail),
            bottomRight: Radius.circular(mine ? tokens.AppRadius.tail : tokens.AppRadius.bubble),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Mono(mine ? 'SENT' : 'RECEIVED', size: 9, color: c.coin),
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CoinMark(size: 22, color: c.coin),
                  const SizedBox(width: 7),
                  Display(msg.coin!.toStringAsFixed(2), size: 27, color: c.coin),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Opacity(
                opacity: 0.8,
                child: Mono(
                  relayed
                      ? 'SIGNED ON DEVICE · RELAYED VIA ${msg.via?.toUpperCase()}'
                      : 'SIGNED ON DEVICE · DIRECT',
                  size: 8.5,
                  color: c.coin,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? c.bubbleOut : c.bubbleIn,
          border: mine ? null : Border.all(color: c.hair2),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(tokens.AppRadius.bubble),
            topRight: const Radius.circular(tokens.AppRadius.bubble),
            bottomLeft: Radius.circular(mine ? tokens.AppRadius.bubble : tokens.AppRadius.tail),
            bottomRight: Radius.circular(mine ? tokens.AppRadius.tail : tokens.AppRadius.bubble),
          ),
        ),
        child: Opacity(
          opacity: msg.state == mock.MsgState.queued ? 0.55 : 1,
          child: Body(msg.text ?? '', size: 12.5, color: mine ? c.bubbleOutInk : c.ink),
        ),
      );
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Column(
            crossAxisAlignment: crossAxis,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (senderName != null && !mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Mono(senderName!.toUpperCase(), size: 9),
                ),
              content,
              Padding(padding: const EdgeInsets.only(top: 4), child: footer),
            ],
          ),
        ),
      ),
    );
  }
}
