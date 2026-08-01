// Message relay — ported from src/utils/relay.ts. The app-layer hop logic
// that turns a one-room P2P cluster into something that reaches past a
// single radio range.
//
// Pure functions only — no store access — so the hop rules can be reasoned
// about and tested on their own.
import 'dart:convert';

/// What actually travels between phones.
class Envelope {
  /// Unique per original message. Dedupe key — survives every hop unchanged.
  final String id;

  /// Device id of whoever composed it. Never rewritten by a relay.
  final String from;

  /// Device id of the intended reader, or a thread id for a group.
  final String to;

  final String kind; // 'msg' | 'coin'

  /// Opaque to relays. Ciphertext once the vault lands.
  final String body;

  /// Hops remaining. A relay forwards only while this is above zero.
  final int ttl;

  /// Device ids this has already passed through, in order.
  final List<String> path;

  /// Composed-at, from the sender's clock. Display only.
  final int at;

  const Envelope({
    required this.id,
    required this.from,
    required this.to,
    required this.kind,
    required this.body,
    required this.ttl,
    required this.path,
    required this.at,
  });

  Envelope copyWith({int? ttl, List<String>? path}) => Envelope(
        id: id,
        from: from,
        to: to,
        kind: kind,
        body: body,
        ttl: ttl ?? this.ttl,
        path: path ?? this.path,
        at: at,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'to': to,
        'kind': kind,
        'body': body,
        'ttl': ttl,
        'path': path,
        'at': at,
      };
}

const defaultTtl = 3;

Envelope newEnvelope({
  required String id,
  required String from,
  required String to,
  required String kind,
  required String body,
  required int at,
  int ttl = defaultTtl,
}) =>
    Envelope(id: id, from: from, to: to, kind: kind, body: body, ttl: ttl, path: const [], at: at);

/// Hops taken so far. 0 means it arrived directly from the sender.
int hopsTaken(Envelope e) => e.path.length;

/// The device that handed it to us, if anyone relayed it.
String? relayedBy(Envelope e) => e.path.isEmpty ? null : e.path.last;

/// Fixed-size ring of message ids we've already handled. A plain Set would
/// grow without bound over a long demo; this forgets the oldest instead.
class SeenCache {
  final int limit;
  final List<String> _order = [];
  final Set<String> _set = {};

  SeenCache({this.limit = 512});

  /// True if this id was already seen. Records it either way.
  bool check(String id) {
    if (_set.contains(id)) return true;
    _set.add(id);
    _order.add(id);
    if (_order.length > limit) {
      final oldest = _order.removeAt(0);
      _set.remove(oldest);
    }
    return false;
  }

  int get size => _set.length;
}

enum RelayAction { drop, deliver, relay }

class Decision {
  final RelayAction action;
  final String? why; // 'duplicate' | 'expired' | 'loop', when action == drop
  final Envelope? envelope; // set when action == deliver | relay
  final String? excludePeer; // set when action == relay

  const Decision._(this.action, {this.why, this.envelope, this.excludePeer});

  factory Decision.drop(String why) => Decision._(RelayAction.drop, why: why);
  factory Decision.deliver(Envelope envelope) => Decision._(RelayAction.deliver, envelope: envelope);
  factory Decision.relay(Envelope envelope, {String? excludePeer}) =>
      Decision._(RelayAction.relay, envelope: envelope, excludePeer: excludePeer);
}

/// The whole hop rule, in one place.
///
/// [me] is this device's id, [fromPeer] the peer that handed it over (null if
/// we composed it). Returns what to do — the caller performs the side effects.
Decision route(Envelope envelope, String me, SeenCache seen, {String? fromPeer}) {
  if (seen.check(envelope.id)) return Decision.drop('duplicate');

  // Our own id already in the path means it came back around to us.
  if (envelope.path.contains(me)) return Decision.drop('loop');

  if (envelope.to == me) return Decision.deliver(envelope);

  if (envelope.ttl <= 0) return Decision.drop('expired');

  // Carry it on: burn a hop and record that we touched it, so the recipient
  // can see the route it took.
  return Decision.relay(
    envelope.copyWith(ttl: envelope.ttl - 1, path: [...envelope.path, me]),
    excludePeer: fromPeer,
  );
}

/// Group messages are delivered to everyone AND relayed onward.
bool isGroup(String to) => to.startsWith('g:');

String encode(Envelope e) => jsonEncode(e.toJson());

/// Never throws — a malformed payload from another build must not crash the app.
Envelope? decode(String text) {
  try {
    final e = jsonDecode(text);
    if (e is! Map ||
        e['id'] is! String ||
        e['from'] is! String ||
        e['to'] is! String ||
        e['body'] is! String ||
        e['ttl'] is! int ||
        e['path'] is! List) {
      return null;
    }
    return Envelope(
      id: e['id'],
      from: e['from'],
      to: e['to'],
      kind: e['kind'] is String ? e['kind'] : 'msg',
      body: e['body'],
      ttl: e['ttl'],
      path: List<String>.from(e['path']),
      at: e['at'] is int ? e['at'] : 0,
    );
  } catch (_) {
    return null;
  }
}
