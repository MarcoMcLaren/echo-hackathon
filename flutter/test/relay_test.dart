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
}) => Envelope(id: id, from: from, to: to, kind: kind, body: body, ttl: ttl, path: path, at: at);

void main() {
  group('newEnvelope', () {
    test('defaults ttl to DEFAULT_TTL and path to empty', () {
      final e = newEnvelope(id: 'e1', from: 'a', to: 'b', kind: EnvelopeKind.msg, body: 'hi', at: 1);
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
      final e = _envelope(path: const ['x', 'y'], kind: EnvelopeKind.coin, body: '12.5');
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
      expect(decode('{"id":1,"from":"a","to":"b","body":"x","ttl":3,"path":[]}'), isNull);
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
