import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/messaging/mock_transport.dart';
import 'package:echo/features/messaging/types.dart';
import 'package:echo/utils/relay.dart';

void main() {
  group('MockTransport', () {
    test(
      'connects only the direct (hops == 0) demo contacts after start',
      () async {
        final transport = MockTransport(peerJoinDelay: Duration.zero);
        final connected = <String>[];
        transport.onPeer = (peer, state) {
          if (state == PeerLinkState.connected) connected.add(peer.deviceId);
        };

        final result = await transport.start();
        expect(result.ok, isTrue);

        await Future.delayed(const Duration(milliseconds: 10));

        expect(connected, containsAll(['lerato', 'thabo']));
        expect(
          connected,
          isNot(contains('naledi')),
        ); // 1 hop — out of direct radio range
        expect(connected, isNot(contains('sipho'))); // no route at all
      },
    );

    test(
      'broadcast fans out to connected peers, excluding the given one',
      () async {
        final transport = MockTransport(peerJoinDelay: Duration.zero);
        transport.onPeer = (_, _) {};
        await transport.start();
        await Future.delayed(const Duration(milliseconds: 10));

        final envelope = newEnvelope(
          id: 'e1',
          from: 'me',
          to: 'thabo',
          kind: EnvelopeKind.msg,
          body: 'hi',
          at: 0,
        );

        final fanout = await transport.broadcast(envelope);
        expect(fanout, 2);

        final excluded = await transport.broadcast(
          envelope,
          excludePeer: 'mock-thabo',
        );
        expect(excluded, 1);
      },
    );

    test('broadcast returns 0 before start and after stop', () async {
      final transport = MockTransport(peerJoinDelay: Duration.zero);
      final envelope = newEnvelope(
        id: 'e1',
        from: 'me',
        to: 'thabo',
        kind: EnvelopeKind.msg,
        body: 'hi',
        at: 0,
      );
      expect(await transport.broadcast(envelope), 0);

      transport.onPeer = (_, _) {};
      await transport.start();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(await transport.broadcast(envelope), greaterThan(0));

      await transport.stop();
      expect(await transport.broadcast(envelope), 0);
    });

    test('stop cancels pending peer-join timers', () async {
      final transport = MockTransport(
        peerJoinDelay: const Duration(milliseconds: 50),
      );
      var peerEvents = 0;
      transport.onPeer = (_, _) => peerEvents++;

      await transport.start();
      await transport.stop();
      await Future.delayed(const Duration(milliseconds: 80));

      expect(peerEvents, 0);
    });

    test(
      'broadcast records a whole (unchunked) envelope as a single sent part',
      () async {
        final transport = MockTransport(peerJoinDelay: Duration.zero);
        transport.onPeer = (_, _) {};
        await transport.start();
        await Future.delayed(const Duration(milliseconds: 10));

        final envelope = newEnvelope(
          id: 'e1',
          from: 'me',
          to: 'thabo',
          kind: EnvelopeKind.msg,
          body: 'hi',
          at: 0,
        );
        await transport.broadcast(envelope);

        expect(transport.sentParts, [same(envelope)]);
      },
    );

    test(
      'broadcast chunks an oversized body before it "goes on the air"',
      () async {
        final transport = MockTransport(peerJoinDelay: Duration.zero);
        transport.onPeer = (_, _) {};
        await transport.start();
        await Future.delayed(const Duration(milliseconds: 10));

        final envelope = newEnvelope(
          id: 'photo1',
          from: 'me',
          to: 'thabo',
          kind: EnvelopeKind.image,
          body: 'x' * (chunkChars * 2 + 10),
          at: 0,
        );
        await transport.broadcast(envelope);

        expect(transport.sentParts, hasLength(3));
        expect(transport.sentParts.every((p) => p.gid == 'photo1'), isTrue);
        expect(
          transport.sentParts.map((p) => p.id),
          ['photo1#0', 'photo1#1', 'photo1#2'],
        );
      },
    );

    test('broadcast does not chunk when the body fits in one part', () async {
      final transport = MockTransport(peerJoinDelay: Duration.zero);
      transport.onPeer = (_, _) {};
      await transport.start();
      await Future.delayed(const Duration(milliseconds: 10));

      final envelope = newEnvelope(
        id: 'e1',
        from: 'me',
        to: 'thabo',
        kind: EnvelopeKind.msg,
        body: 'hi',
        at: 0,
      );
      await transport.broadcast(envelope);

      expect(transport.sentParts.single.gid, isNull);
      expect(transport.sentParts.single.part, isNull);
    });
  });
}
