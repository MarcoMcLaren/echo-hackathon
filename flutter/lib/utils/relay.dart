// Message relay: the app-layer hop logic that turns Nearby's one-room P2P
// clustering into something that reaches past a single radio range.
//
// Pure functions only — no native calls, no store access — so the hop rules can
// be reasoned about and tested on their own. This is the part that decides
// whether A -> B -> C works, so it stays boring and inspectable.
//
// Port of src/utils/relay.ts.
import 'dart:convert';

/// What actually travels between phones. Kept small; Nearby sends it as text.
enum EnvelopeKind {
  msg,
  coin;

  String get wire => name;

  static EnvelopeKind fromWire(String value) =>
      value == 'coin' ? EnvelopeKind.coin : EnvelopeKind.msg;
}

const int defaultTtl = 3;

class Envelope {
  /// Unique per original message. Dedupe key — survives every hop unchanged.
  final String id;

  /// Device id of whoever composed it. Never rewritten by a relay.
  final String from;

  /// Device id of the intended reader, or a thread id for a group.
  final String to;

  final EnvelopeKind kind;

  /// Opaque to relays. Ciphertext once the vault lands.
  final String body;

  /// Hops remaining. A relay forwards only while this is above zero.
  final int ttl;

  /// Device ids this has already passed through, in order. Builds the route strip.
  final List<String> path;

  /// Composed-at, from the sender's clock. Display only — never trusted for ordering.
  final int at;

  const Envelope({
    required this.id,
    required this.from,
    required this.to,
    required this.kind,
    required this.body,
    required this.at,
    this.ttl = defaultTtl,
    this.path = const [],
  });

  Envelope copyWith({int? ttl, List<String>? path}) => Envelope(
    id: id,
    from: from,
    to: to,
    kind: kind,
    body: body,
    at: at,
    ttl: ttl ?? this.ttl,
    path: path ?? this.path,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': from,
    'to': to,
    'kind': kind.wire,
    'body': body,
    'ttl': ttl,
    'path': path,
    'at': at,
  };
}

Envelope newEnvelope({
  required String id,
  required String from,
  required String to,
  required EnvelopeKind kind,
  required String body,
  required int at,
  int? ttl,
}) => Envelope(
  id: id,
  from: from,
  to: to,
  kind: kind,
  body: body,
  at: at,
  ttl: ttl ?? defaultTtl,
);

/// Hops taken so far. 0 means it arrived directly from the sender.
int hopsTaken(Envelope e) => e.path.length;

/// The device that handed it to us, if anyone relayed it.
String? relayedBy(Envelope e) => e.path.isEmpty ? null : e.path.last;

/// Fixed-size ring of message ids we've already handled. A plain Set would grow
/// without bound over a long demo; this forgets the oldest instead.
class SeenCache {
  SeenCache([this.limit = 512]);

  final int limit;
  final List<String> _order = [];
  final Set<String> _ids = {};

  /// True if this id was already seen. Records it either way.
  bool check(String id) {
    if (_ids.contains(id)) return true;
    _ids.add(id);
    _order.add(id);
    if (_order.length > limit) {
      final oldest = _order.removeAt(0);
      _ids.remove(oldest);
    }
    return false;
  }

  int get size => _ids.length;
}

sealed class Decision {
  const Decision();
}

class DropDecision extends Decision {
  const DropDecision(this.why);

  /// 'duplicate' | 'expired' | 'loop'
  final String why;
}

class DeliverDecision extends Decision {
  const DeliverDecision(this.envelope);

  final Envelope envelope;
}

class RelayDecision extends Decision {
  const RelayDecision(this.envelope, {this.excludePeer});

  final Envelope envelope;
  final String? excludePeer;
}

/// The whole hop rule, in one place.
///
/// `me` is this device's id, `fromPeer` the peer that handed it over (null if we
/// composed it). Returns what to do — the caller performs the side effects.
Decision route(Envelope envelope, String me, SeenCache seen, {String? fromPeer}) {
  if (seen.check(envelope.id)) return const DropDecision('duplicate');

  // Our own id already in the path means it came back around to us.
  if (envelope.path.contains(me)) return const DropDecision('loop');

  if (envelope.to == me) return DeliverDecision(envelope);

  if (envelope.ttl <= 0) return const DropDecision('expired');

  // Carry it on: burn a hop and record that we touched it, so the recipient can
  // see the route it took.
  return RelayDecision(
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
        e['ttl'] is! num ||
        e['path'] is! List ||
        (e['path'] as List).any((p) => p is! String)) {
      return null;
    }
    return Envelope(
      id: e['id'] as String,
      from: e['from'] as String,
      to: e['to'] as String,
      kind: EnvelopeKind.fromWire(e['kind'] as String? ?? 'msg'),
      body: e['body'] as String,
      ttl: (e['ttl'] as num).toInt(),
      path: List<String>.from(e['path'] as List),
      at: (e['at'] as num?)?.toInt() ?? 0,
    );
  } catch (_) {
    return null;
  }
}
