// The data model. No seed data — everything in the app now comes from real
// mesh activity, so an empty screen means "nothing has happened yet" rather
// than "the demo set is showing".
//
// Port of src/store/types.ts.
import '../features/messaging/events.dart' show MeshEvent;

/// Hop count to reach someone: 0 (direct), 1 or 2 hops, or no route at all.
typedef Hops = int?;

enum MsgState { delivered, queued, sent }

class Msg {
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

  final String id;

  /// 'me' or a contact id.
  final String from;

  /// Sender's display name, carried with the message — a relayed sender is
  /// not a peer here and cannot be looked up.
  final String? fromName;
  final String? text;
  final double? coin;

  /// A photo, as a data URI. Travels in chunks; see utils/relay.
  final String? image;

  /// A calendar event someone shared. Saving it is a separate, explicit act.
  final MeshEvent? event;
  final String at;
  final Hops hops;
  final String? via;
  final MsgState? state;

  /// Held locally during the cancel window — not on the air yet.
  final bool pending;

  /// Sent, then taken back. The row stays visible; money that vanishes
  /// silently is worse than money you can see was returned.
  final bool reverted;

  Msg withReverted(bool reverted) => Msg(
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
    pending: pending,
    reverted: reverted,
  );
}

class Thread {
  const Thread({
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

  final String id;
  final String title;
  final String initials;
  final bool group;
  final List<String>? members;
  final String preview;
  final String at;
  final Hops hops;
  final String? via;
  final List<Msg> messages;

  /// Arrived since you last opened the thread. Drives the summary offer.
  final int unread;
}

/// One line in the wallet. Derived from coin messages, never stored twice.
class Entry {
  const Entry({
    required this.id,
    required this.amount,
    required this.who,
    required this.hops,
    this.via,
    required this.note,
    this.reverted = false,
  });

  final String id;
  final double amount;
  final String who;
  final Hops hops;
  final String? via;
  final String note;
  final bool reverted;
}
