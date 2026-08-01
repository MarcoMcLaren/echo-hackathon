// Unit tests for lib/utils/relay.dart, mirroring the hop/dedupe/TTL behavior
// documented in src/utils/relay.ts.
import 'package:flutter_test/flutter_test.dart';

import 'package:echo/utils/relay.dart';

Envelope _envelope({
  String id = 'e1',
  String from = 'a',
  String to = 'b',
  EnvelopeKind kind = EnvelopeKind.msg,
  String body = 'hi',
  int ttl = defaultTtl,
  List<String> path = const [],
  int at = 1000,
  String? gid,
  EnvelopePart? part,
}) => Envelope(
  id: id,
  from: from,
  to: to,
  kind: kind,
  body: body,
  ttl: ttl,
  path: path,
  at: at,
  gid: gid,
  part: part,
);

void main() {
  group('newEnvelope', () {
    test('defaults ttl to DEFAULT_TTL and path to empty', () {
      final e = newEnvelope(
        id: 'e1',
        from: 'a',
        to: 'b',
        kind: EnvelopeKind.msg,
        body: 'hi',
        at: 1,
      );
      expect(e.ttl, defaultTtl);
      expect(e.path, isEmpty);
    });

    test('accepts an explicit ttl override', () {
      final e = newEnvelope(
        id: 'e1',
        from: 'a',
        to: 'b',
        kind: EnvelopeKind.coin,
        body: '5',
        at: 1,
        ttl: 1,
      );
      expect(e.ttl, 1);
    });
  });

  group('hopsTaken / relayedBy', () {
    test('0 hops and no relay when the path is empty', () {
      final e = _envelope(path: const []);
      expect(hopsTaken(e), 0);
      expect(relayedBy(e), isNull);
    });

    test('counts path length and reports the last hop', () {
      final e = _envelope(path: const ['x', 'y']);
      expect(hopsTaken(e), 2);
      expect(relayedBy(e), 'y');
    });
  });

  group('SeenCache', () {
    test('reports false the first time and true on repeats', () {
      final seen = SeenCache();
      expect(seen.check('a'), isFalse);
      expect(seen.check('a'), isTrue);
      expect(seen.size, 1);
    });

    test('forgets the oldest id once the limit is exceeded', () {
      final seen = SeenCache(2);
      expect(seen.check('a'), isFalse);
      expect(seen.check('b'), isFalse);
      expect(seen.check('c'), isFalse); // evicts 'a'
      expect(seen.check('a'), isFalse); // 'a' was forgotten, so it's new again
      expect(seen.size, 2);
    });
  });

  group('route', () {
    test('delivers when the envelope is addressed to me', () {
      final decision = route(_envelope(to: 'me'), 'me', SeenCache());
      expect(decision, isA<DeliverDecision>());
      expect((decision as DeliverDecision).envelope.to, 'me');
    });

    test('drops a duplicate id without touching the envelope', () {
      final seen = SeenCache();
      final e = _envelope(id: 'dup', to: 'someone-else');
      route(e, 'me', seen); // first sighting, records it
      final decision = route(e, 'me', seen);
      expect(decision, isA<DropDecision>());
      expect((decision as DropDecision).why, 'duplicate');
    });

    test('drops as a loop when my id is already in the path', () {
      final e = _envelope(to: 'someone-else', path: const ['me']);
      final decision = route(e, 'me', SeenCache());
      expect(decision, isA<DropDecision>());
      expect((decision as DropDecision).why, 'loop');
    });

    test('drops as expired once ttl is exhausted', () {
      final e = _envelope(to: 'someone-else', ttl: 0);
      final decision = route(e, 'me', SeenCache());
      expect(decision, isA<DropDecision>());
      expect((decision as DropDecision).why, 'expired');
    });

    test('relays otherwise, burning a hop and appending to the path', () {
      final e = _envelope(to: 'someone-else', ttl: 3, path: const ['x']);
      final decision = route(e, 'me', SeenCache(), fromPeer: 'x');
      expect(decision, isA<RelayDecision>());
      final relay = decision as RelayDecision;
      expect(relay.envelope.ttl, 2);
      expect(relay.envelope.path, ['x', 'me']);
      expect(relay.excludePeer, 'x');
    });

    test('duplicate check takes priority over loop/deliver/expired', () {
      final seen = SeenCache();
      final e = _envelope(id: 'dup2', to: 'me', path: const ['me'], ttl: 0);
      route(e, 'me', seen);
      final decision = route(e, 'me', seen);
      expect(decision, isA<DropDecision>());
      expect((decision as DropDecision).why, 'duplicate');
    });
  });

  group('EnvelopeKind.fromWire', () {
    test('round-trips every kind through wire/fromWire', () {
      for (final kind in EnvelopeKind.values) {
        expect(EnvelopeKind.fromWire(kind.wire), kind);
      }
    });

    test('falls back to msg for an unrecognized wire value', () {
      expect(EnvelopeKind.fromWire('bogus'), EnvelopeKind.msg);
    });
  });

  group('splitBody', () {
    test('returns a single part when the body fits under the size', () {
      expect(splitBody('short', size: 10), ['short']);
    });

    test('splits a long body into size-bounded parts, preserving order', () {
      final parts = splitBody('abcdefghij', size: 4);
      expect(parts, ['abcd', 'efgh', 'ij']);
      expect(parts.join(), 'abcdefghij');
    });
  });

  group('Reassembler', () {
    test('passes a whole (non-split) envelope straight through', () {
      final r = Reassembler();
      final e = _envelope(body: 'hi');
      expect(r.add(e), 'hi');
      expect(r.pending, 0);
    });

    test('returns null until every part has arrived, then the joined body', () {
      final r = Reassembler();
      const gid = 'g1';
      final p0 = _envelope(
        id: 'i1',
        gid: gid,
        part: const EnvelopePart(i: 0, n: 2),
        body: 'AB',
      );
      final p1 = _envelope(
        id: 'i1',
        gid: gid,
        part: const EnvelopePart(i: 1, n: 2),
        body: 'CD',
      );

      expect(r.add(p0), isNull);
      expect(r.pending, 1);
      expect(r.add(p1), 'ABCD');
      expect(r.pending, 0);
    });

    test('parts arriving out of order still reassemble in position order', () {
      final r = Reassembler();
      const gid = 'g2';
      final p1 = _envelope(
        gid: gid,
        part: const EnvelopePart(i: 1, n: 3),
        body: 'B',
      );
      final p0 = _envelope(
        gid: gid,
        part: const EnvelopePart(i: 0, n: 3),
        body: 'A',
      );
      final p2 = _envelope(
        gid: gid,
        part: const EnvelopePart(i: 2, n: 3),
        body: 'C',
      );

      expect(r.add(p1), isNull);
      expect(r.add(p0), isNull);
      expect(r.add(p2), 'ABC');
    });

    test('evicts the oldest incomplete group once the limit is exceeded', () {
      final r = Reassembler(1);
      r.add(
        _envelope(gid: 'old', part: const EnvelopePart(i: 0, n: 2), body: 'x'),
      );
      expect(r.pending, 1);

      r.add(
        _envelope(gid: 'new', part: const EnvelopePart(i: 0, n: 2), body: 'y'),
      );
      expect(r.pending, 1, reason: 'old group evicted to make room for new');

      // The evicted group's remaining part can never complete it anymore.
      expect(
        r.add(
          _envelope(
            gid: 'old',
            part: const EnvelopePart(i: 1, n: 2),
            body: 'z',
          ),
        ),
        isNull,
      );
    });
  });

  group('isGroup', () {
    test('true for a g: prefixed id', () {
      expect(isGroup('g:braai'), isTrue);
    });

    test('false otherwise', () {
      expect(isGroup('thabo'), isFalse);
    });
  });

  group('encode / decode', () {
    test('round-trips an envelope', () {
      final e = _envelope(
        path: const ['x', 'y'],
        kind: EnvelopeKind.coin,
        body: '12.5',
      );
      final decoded = decode(encode(e));
      expect(decoded, isNotNull);
      expect(decoded!.id, e.id);
      expect(decoded.from, e.from);
      expect(decoded.to, e.to);
      expect(decoded.kind, EnvelopeKind.coin);
      expect(decoded.body, e.body);
      expect(decoded.ttl, e.ttl);
      expect(decoded.path, e.path);
      expect(decoded.at, e.at);
    });

    test('returns null for malformed JSON instead of throwing', () {
      expect(decode('not json'), isNull);
    });

    test('returns null when required fields are missing', () {
      expect(decode('{"id":"e1","from":"a"}'), isNull);
    });

    test('returns null when a field has the wrong type', () {
      expect(
        decode('{"id":1,"from":"a","to":"b","body":"x","ttl":3,"path":[]}'),
        isNull,
      );
    });

    test(
      'round-trips a revert envelope carrying the original message id as body',
      () {
        final e = _envelope(kind: EnvelopeKind.revert, body: 'c1');
        final decoded = decode(encode(e));
        expect(decoded!.kind, EnvelopeKind.revert);
        expect(decoded.body, 'c1');
      },
    );

    test('round-trips gid/part for a split image envelope', () {
      final e = _envelope(
        kind: EnvelopeKind.image,
        gid: 'g1',
        part: const EnvelopePart(i: 0, n: 2),
      );
      final decoded = decode(encode(e));
      expect(decoded!.gid, 'g1');
      expect(decoded.part?.i, 0);
      expect(decoded.part?.n, 2);
    });

    test('a whole message decodes with gid/part left null', () {
      final decoded = decode(encode(_envelope()));
      expect(decoded!.gid, isNull);
      expect(decoded.part, isNull);
    });

    test('returns null when path contains non-string entries', () {
      // A payload like this from an older/other build must not decode into a
      // booby-trapped Envelope that throws later, inside route().
      final malformed = decode(
        '{"id":"a","from":"b","to":"c","kind":"msg","body":"hi","ttl":3,"path":[1,2],"at":0}',
      );
      expect(malformed, isNull);
    });
  });
}
