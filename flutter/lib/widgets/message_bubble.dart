// Ported from src/features/messaging/components/MessageBubble.tsx.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../features/messaging/events.dart';
import '../models/types.dart' as types;
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import 'route_strip.dart';
import 'type.dart';

/// Outgoing only. Incoming messages get a route strip instead.
String _stateLine(types.Msg m) {
  if (m.state == 'queued') return 'QUEUED · NO ROUTE YET';
  // hops counts relays, so 0 relays is a direct hand-off and saying "1 HOP"
  // about it just reads as noise.
  final via = (m.hops != null && m.hops! > 0) ? ' · ${m.hops! + 1} HOPS' : '';
  return '${(m.state ?? 'sent').toUpperCase()}$via · ${m.at}';
}

class MessageBubble extends StatelessWidget {
  final types.Msg msg;
  final String? senderName;
  final bool animate;
  /// Called when "Add to calendar" is tapped on an event message — wired to
  /// the real saveToCalendar() by the screen that owns the thread.
  final ValueChanged<MeshEvent>? onSaveEvent;

  const MessageBubble({super.key, required this.msg, this.senderName, this.animate = false, this.onSaveEvent});

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
      final tone = msg.reverted ? c.ink3 : c.coin;
      final label = msg.reverted
          ? 'TAKEN BACK'
          : msg.pending
              ? 'SENDING'
              : msg.state == 'queued'
                  ? 'WAITING FOR A ROUTE'
                  : mine
                      ? 'SENT'
                      : 'RECEIVED';
      final footer = msg.reverted
          ? 'RETURNED · THE OTHER PHONE IS TOLD WHEN A ROUTE OPENS'
          : (msg.hops != null && msg.hops! > 0)
              ? 'SIGNED ON DEVICE · RELAYED VIA ${msg.via?.toUpperCase()}'
              : 'SIGNED ON DEVICE · DIRECT';

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
                    // RN dashes this border when reverted; Flutter's BoxDecoration
                    // has no dashed border without a custom painter, so the muted
                    // tone + strikethrough carry the "taken back" signal instead.
                    border: Border.all(color: tone, width: 1.5),
                    color: msg.reverted ? Colors.transparent : c.coin.withAlpha(0x12),
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
                      MonoText(label, size: 9, color: tone),
                      const SizedBox(height: 7),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CoinMark(size: 22, color: tone),
                          const SizedBox(width: 7),
                          DisplayText(
                            msg.coin!.toStringAsFixed(2),
                            size: 27,
                            color: tone,
                            style: msg.reverted ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Opacity(
                        opacity: 0.8,
                        child: MonoText(footer, size: 8.5, color: tone),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                if (!msg.pending) routeOrState(),
              ],
            ),
          ),
        ),
      );
    }

    // A photo message: no bubble chrome, just the image itself.
    if (msg.image != null) {
      Uint8List? bytes;
      try {
        final comma = msg.image!.indexOf(',');
        bytes = base64Decode(comma >= 0 ? msg.image!.substring(comma + 1) : msg.image!);
      } catch (_) {
        bytes = null;
      }

      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
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
              ClipRRect(
                borderRadius: BorderRadius.circular(EchoRadius.bubble),
                child: bytes != null
                    ? Image.memory(bytes, width: 220, height: 220, fit: BoxFit.cover)
                    : Container(
                        width: 220,
                        height: 220,
                        color: c.sunk,
                        alignment: Alignment.center,
                        child: const MonoText('COULD NOT LOAD PHOTO', size: 9),
                      ),
              ),
              const SizedBox(height: 4),
              routeOrState(),
            ],
          ),
        ),
      );
    }

    // A calendar event, offered up as its own real thing rather than a link.
    if (msg.event != null) {
      final event = msg.event!;
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
                Container(
                  constraints: const BoxConstraints(minWidth: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.hair2, width: 1.5),
                    color: c.card,
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
                      const MonoText('EVENT', size: 9),
                      const SizedBox(height: 5),
                      DisplayText(event.title, size: 19),
                      const SizedBox(height: 3),
                      MonoText(formatWhen(event).toUpperCase(), size: 9),
                      if (event.location != null && event.location!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        BodyText(event.location!, size: 12, dim: Dim.two),
                      ],
                      const SizedBox(height: 9),
                      GestureDetector(
                        onTap: onSaveEvent == null ? null : () => onSaveEvent!(event),
                        child: Semantics(
                          button: true,
                          label: 'Add to calendar',
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 36),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              border: Border.all(color: c.hair, width: 1.5),
                              borderRadius: BorderRadius.circular(EchoRadius.pill),
                            ),
                            child: const DisplayText('Add to calendar', size: 13),
                          ),
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
