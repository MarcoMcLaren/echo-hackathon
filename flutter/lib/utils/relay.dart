// Message relay — ported from src/utils/relay.ts. The app-layer hop logic
// that turns a one-room P2P cluster into something that reaches past a
// single radio range.
//
// Pure functions only — no store access — so the hop rules can be reasoned
// about and tested on their own.
import 'dart:convert';
import 'dart:math';

/// What actually travels between phones.
class Envelope {
  /// Unique per original message. Dedupe key — survives every hop unchanged.
  /// When chunked, each part gets its own suffixed id (`$id#$i`); `gid` is
  /// what ties the parts back together.
  final String id;

  /// Device id of whoever composed it. Never rewritten by a relay.
  final String from;

  /// Sender's display name, carried with the message — so a thread reached
  /// through a relay (2+ hops, never in the local peer list) can still show
  /// a human name instead of a raw device id. Ported from `31da01b`.
  final String? fromName;

  /// Device id of the intended reader, or a group address (`g:...`) for a group.
  final String to;

  final String kind; // 'msg' | 'coin' | 'revert' | 'image' | 'event' | 'invite'

  /// Opaque to relays. Ciphertext once the vault lands.
  final String body;

  /// Groups this part with the rest of the same original message, when the
  /// body had to be split across multiple envelopes. Absent on single-part
  /// messages (`part` absent too).
  final String? gid;

  /// This part's index and the total part count, present only when `body`
  /// is a chunk rather than the whole message.
  final PartInfo? part;

  /// Hops remaining. A relay forwards only while this is above zero.
  final int ttl;

  /// Device ids this has already passed through, in order.
  final List<String> path;

  /// Composed-at, from the sender's clock. Display only.
  final int at;

  const Envelope({
    required this.id,
    required this.from,
    this.fromName,
    required this.to,
    required this.kind,
    required this.body,
    this.gid,
    this.part,
    required this.ttl,
    required this.path,
    required this.at,
  });

  Envelope copyWith({int? ttl, List<String>? path}) => Envelope(
        id: id,
        from: from,
        fromName: fromName,
        to: to,
        kind: kind,
        body: body,
        gid: gid,
        part: part,
        ttl: ttl ?? this.ttl,
        path: path ?? this.path,
        at: at,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        if (fromName != null) 'fromName': fromName,
        'to': to,
        'kind': kind,
        'body': body,
        if (gid != null) 'gid': gid,
        if (part != null) 'part': part!.toJson(),
        'ttl': ttl,
        'path': path,
        'at': at,
      };
}

class PartInfo {
  final int i;
  final int n;
  const PartInfo({required this.i, required this.n});

  Map<String, dynamic> toJson() => {'i': i, 'n': n};
}

const defaultTtl = 3;

Envelope newEnvelope({
  required String id,
  required String from,
  String? fromName,
  required String to,
  required String kind,
  required String body,
  required int at,
  String? gid,
  PartInfo? part,
  int ttl = defaultTtl,
}) =>
    Envelope(
      id: id,
      from: from,
      fromName: fromName,
      to: to,
      kind: kind,
      body: body,
      gid: gid,
      part: part,
      ttl: ttl,
      path: const [],
      at: at,
    );

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

enum RelayAction { drop, deliver, relay, fanout }

class Decision {
  final RelayAction action;
  final String? why; // 'duplicate' | 'expired' | 'loop', when action == drop
  final Envelope? envelope; // set when action == deliver | relay | fanout
  final String? excludePeer; // set when action == relay | fanout

  const Decision._(this.action, {this.why, this.envelope, this.excludePeer});

  factory Decision.drop(String why) => Decision._(RelayAction.drop, why: why);
  factory Decision.deliver(Envelope envelope) => Decision._(RelayAction.deliver, envelope: envelope);
  factory Decision.relay(Envelope envelope, {String? excludePeer}) =>
      Decision._(RelayAction.relay, envelope: envelope, excludePeer: excludePeer);
  factory Decision.fanout(Envelope envelope, {String? excludePeer}) =>
      Decision._(RelayAction.fanout, envelope: envelope, excludePeer: excludePeer);
}

/// The whole hop rule, in one place.
///
/// [me] is this device's id, [fromPeer] the peer that handed it over (null if
/// we composed it). Returns what to do — the caller performs the side effects.
///
/// Routing has no concept of group membership — only the store knows which
/// groups this device is actually in. So a group-addressed envelope always
/// comes back as `fanout`: TTL/path still advance exactly like a normal relay
/// hop, but whether to also *show* it (join the group's thread) is left to
/// the caller, same split RN's `mesh.ts` makes.
Decision route(Envelope envelope, String me, SeenCache seen, {String? fromPeer}) {
  if (seen.check(envelope.id)) return Decision.drop('duplicate');

  // Our own id already in the path means it came back around to us.
  if (envelope.path.contains(me)) return Decision.drop('loop');

  if (isGroup(envelope.to)) {
    if (envelope.ttl <= 0) return Decision.drop('expired');
    return Decision.fanout(
      envelope.copyWith(ttl: envelope.ttl - 1, path: [...envelope.path, me]),
      excludePeer: fromPeer,
    );
  }

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

const _groupChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// A fresh group address — mirrors RN's `newGroupId` (`g:` + 8 random
/// base36-ish chars). There is no server-side roster; this id, once agreed
/// by every member via the invite envelope, is the group's only anchor.
String newGroupId() {
  final rand = Random();
  final suffix = List.generate(8, (_) => _groupChars[rand.nextInt(_groupChars.length)]).join();
  return 'g:$suffix';
}

/// Nearby's BYTES payload is assumed capped at 32 KiB; envelope bodies above
/// [chunkChars] get split before send so the JSON-wrapped part still fits.
const maxPayload = 32 * 1024;
const chunkChars = 24000;

/// Splits [body] into parts no longer than [size]. A body that already fits
/// comes back as a single-element list (the caller treats that as "no split
/// needed" — see `part`/`gid` staying null on the envelope).
List<String> splitBody(String body, [int size = chunkChars]) {
  if (body.length <= size) return [body];
  final parts = <String>[];
  for (var i = 0; i < body.length; i += size) {
    parts.add(body.substring(i, i + size > body.length ? body.length : i + size));
  }
  return parts;
}

class _PartialGroup {
  final List<String?> parts;
  final int n;
  _PartialGroup(this.n) : parts = List<String?>.filled(n, null);
}

/// Joins chunked envelopes back into the original body. A fixed-size ring of
/// in-flight groups — like [SeenCache], this must forget the oldest partial
/// group rather than grow without bound if a group never completes.
class Reassembler {
  final int limit;
  final Map<String, _PartialGroup> _groups = {};
  final List<String> _order = [];

  Reassembler({this.limit = 16});

  /// Records one part of [envelope]. Returns the joined body once every part
  /// of its `gid` has arrived, else null — the message doesn't exist yet.
  String? add(Envelope envelope) {
    final part = envelope.part;
    if (part == null) return envelope.body;

    final gid = envelope.gid ?? envelope.id;
    var group = _groups[gid];
    if (group == null) {
      group = _PartialGroup(part.n);
      _groups[gid] = group;
      _order.add(gid);
      if (_order.length > limit) {
        final oldest = _order.removeAt(0);
        _groups.remove(oldest);
      }
    }
    if (part.i >= 0 && part.i < group.parts.length) {
      group.parts[part.i] = envelope.body;
    }

    if (group.parts.every((p) => p != null)) {
      _groups.remove(gid);
      _order.remove(gid);
      return group.parts.join();
    }
    return null;
  }

  int get pending => _groups.length;
}

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
    final rawPart = e['part'];
    PartInfo? part;
    if (rawPart is Map && rawPart['i'] is int && rawPart['n'] is int) {
      part = PartInfo(i: rawPart['i'], n: rawPart['n']);
    }
    return Envelope(
      id: e['id'],
      from: e['from'],
      fromName: e['fromName'] is String ? e['fromName'] : null,
      to: e['to'],
      kind: e['kind'] is String ? e['kind'] : 'msg',
      body: e['body'],
      gid: e['gid'] is String ? e['gid'] : null,
      part: part,
      ttl: e['ttl'],
      path: List<String>.from(e['path']),
      at: e['at'] is int ? e['at'] : 0,
    );
  } catch (_) {
    return null;
  }
}
