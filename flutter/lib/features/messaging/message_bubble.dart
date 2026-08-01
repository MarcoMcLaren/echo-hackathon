// A single chat message: text, a photo, a calendar event, or money as a
// first-class message rather than an attachment. Port of
// src/features/messaging/components/MessageBubble.tsx.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/type.dart';
import '../../components/route_strip.dart';
import '../../store/mock.dart' as mock;
import '../../store/theme_store.dart';
import '../../styles/theme.dart' as tokens;
import 'events.dart' show MeshEvent, formatWhen;

/// The data URI's payload, or null if it isn't one this device can decode —
/// a photo from a build this one doesn't understand must not crash the thread.
Uint8List? _photoBytes(String dataUri) {
  final comma = dataUri.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(dataUri.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

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
  const MessageBubble({
    super.key,
    required this.msg,
    this.senderName,
    this.animate = false,
    this.onSaveEvent,
  });

  final mock.Msg msg;
  final String? senderName;
  final bool animate;
  final ValueChanged<MeshEvent>? onSaveEvent;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final mine = msg.from == 'me';
    final crossAxis = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    // Sending is a transient placeholder — its own "SENDING" badge already
    // says everything the footer would.
    final Widget? footer = msg.pending
        ? null
        : mine
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
    // A photo carries its own frame; a bubble around it would be noise.
    if (msg.image != null) {
      final bytes = _photoBytes(msg.image!);
      content = Container(
        width: 220,
        height: 220,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.AppRadius.bubble),
          border: Border.all(color: c.hair2),
        ),
        child: Semantics(
          image: true,
          label: 'Photo',
          child: bytes == null
              ? ColoredBox(color: c.sunk)
              : Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => ColoredBox(color: c.sunk),
                ),
        ),
      );
    } else if (msg.event != null) {
      // An event you can act on. Saving it to the phone's calendar is a
      // separate tap — a received message should never write to someone's
      // calendar itself.
      final event = msg.event!;
      content = Container(
        constraints: const BoxConstraints(minWidth: 220),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          border: Border.all(color: c.hair, width: 1.5),
          borderRadius: BorderRadius.circular(tokens.AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Mono('EVENT', size: 9, dim: 3),
            Padding(padding: const EdgeInsets.only(top: 5), child: Display(event.title, size: 19)),
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Mono(formatWhen(event).toUpperCase(), size: 9, dim: 2),
            ),
            if (event.location != null)
              Padding(padding: const EdgeInsets.only(top: 5), child: Body(event.location!, size: 12, dim: 2)),
            Semantics(
              button: true,
              label: 'Add to calendar',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onSaveEvent == null ? null : () => onSaveEvent!(event),
                child: Container(
                  constraints: const BoxConstraints(minHeight: tokens.touchMin),
                  margin: const EdgeInsets.only(top: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: c.ink, width: 1.5),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Display('Add to calendar', size: 13),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (msg.coin != null) {
      final relayed = msg.hops != null && msg.hops! > 0;
      final tone = msg.reverted ? c.ink3 : c.coin;
      final String badge;
      if (msg.reverted) {
        badge = 'TAKEN BACK';
      } else if (msg.pending) {
        badge = 'SENDING';
      } else if (msg.state == mock.MsgState.queued) {
        badge = 'WAITING FOR A ROUTE';
      } else {
        badge = mine ? 'SENT' : 'RECEIVED';
      }
      final String caption;
      if (msg.reverted) {
        caption = 'RETURNED · THE OTHER PHONE IS TOLD WHEN A ROUTE OPENS';
      } else if (relayed) {
        caption = 'SIGNED ON DEVICE · RELAYED VIA ${msg.via?.toUpperCase()}';
      } else {
        caption = 'SIGNED ON DEVICE · DIRECT';
      }
      content = Container(
        constraints: const BoxConstraints(minWidth: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: tone, width: 1.5),
          color: msg.reverted ? Colors.transparent : tone.withAlpha(0x12),
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
            Mono(badge, size: 9, color: tone),
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CoinMark(size: 22, color: tone),
                  const SizedBox(width: 7),
                  Display(
                    msg.coin!.toStringAsFixed(2),
                    size: 27,
                    color: tone,
                    style: msg.reverted
                        ? const TextStyle(decoration: TextDecoration.lineThrough)
                        : null,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Opacity(
                opacity: 0.8,
                child: Mono(caption, size: 8.5, color: tone),
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
              if (footer != null) Padding(padding: const EdgeInsets.only(top: 4), child: footer),
            ],
          ),
        ),
      ),
    );
  }
}
