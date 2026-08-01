// Ported from src/store/types.ts. No seed data — everything in the app now
// comes from real contacts and real mesh activity, so an empty screen means
// "nothing has happened yet" rather than "the demo set is showing". Replaces
// the old models/mock.dart, which held both these types and four hardcoded
// people/conversations.
import '../features/messaging/events.dart';

class Msg {
  final String id;
  final String from; // 'me' or a device id
  /// Sender's display name, carried in the envelope — lets a message reached
  /// through a relay show a human name even though the sender was never a
  /// direct peer. Ported from `31da01b`.
  final String? fromName;
  final String? text;
  final double? coin;
  /// A photo message: the full `data:image/...;base64,...` URI. Money and
  /// photos and events are each their own field rather than one variant enum,
  /// mirroring RN's flat `Msg` shape.
  final String? image;
  final MeshEvent? event;
  final String at;
  final int? hops;
  final String? via;
  final String? state; // 'delivered' | 'queued' | 'sent'
  /// Held locally during the cancel window — not on the air yet.
  final bool pending;
  /// Sent, then taken back. The row stays visible; money that vanishes
  /// silently is worse than money you can see was returned.
  final bool reverted;

  const Msg({
    required this.id,
    required this.from,
    this.fromName,
    this.text,
    this.coin,
    this.image,
    this.event,
    required this.at,
    required this.hops,
    this.via,
    this.state,
    this.pending = false,
    this.reverted = false,
  });

  Msg copyWith({bool? pending, bool? reverted}) => Msg(
        id: id,
        from: from,
        fromName: fromName,
        text: text,
        coin: coin,
        image: image,
        event: event,
        at: at,
        hops: hops,
        via: via,
        state: state,
        pending: pending ?? this.pending,
        reverted: reverted ?? this.reverted,
      );
}

class Thread {
  final String id;
  String title;
  String initials;
  final bool group;
  final List<String>? members;
  String preview;
  String at;
  int? hops;
  String? via;
  final List<Msg> messages;
  /// Arrived since you last opened the thread. Drives the summary offer.
  int unread;

  Thread({
    required this.id,
    required this.title,
    required this.initials,
    this.group = false,
    this.members,
    required this.preview,
    required this.at,
    required this.hops,
    this.via,
    required this.messages,
    this.unread = 0,
  });
}

class Entry {
  final String id;
  final double amount;
  final String who;
  final int? hops;
  final String? via;
  final String note;
  final bool reverted;

  const Entry({
    required this.id,
    required this.amount,
    required this.who,
    required this.hops,
    this.via,
    required this.note,
    this.reverted = false,
  });
}

/// First-letter-of-first-two-words, or the first two characters of a single
/// word — used wherever a title needs initials without a `title.slice(0,2)`
/// hack. Ported from RN's `initialsOf`, added alongside the sender-name work.
String initialsOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '??';
  final words = trimmed.split(RegExp(r'\s+'));
  if (words.length > 1) {
    return (words[0][0] + words[1][0]).toUpperCase();
  }
  return trimmed.length >= 2 ? trimmed.substring(0, 2).toUpperCase() : trimmed.toUpperCase();
}
