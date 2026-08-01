import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/messaging/mock_transport.dart';
import 'package:echo/features/messaging/types.dart';
import 'package:echo/utils/relay.dart';

const _thabo = PeerInfo(peerId: 'p-thabo', deviceId: 'thabo', display: 'Thabo Mokoena');
const _naledi = PeerInfo(peerId: 'p-naledi', deviceId: 'naledi', display: 'Naledi Khumalo');

void main() {
  group('MockTransport', () {
    test('connects nobody on its own after start', () async {
      final transport = MockTransport();
      final connected = <String>[];
      transport.onPeer = (peer, state) {
        if (state == PeerLinkState.connected) connected.add(peer.deviceId);
      };

      final result = await transport.start();
      expect(result.ok, isTrue);

      await Future.delayed(const Duration(milliseconds: 10));
      expect(connected, isEmpty);
    });

    test('connectPeer reports a connected peer once running', () async {
      final transport = MockTransport();
      final events = <PeerLinkState>[];
      transport.onPeer = (_, state) => events.add(state);
      await transport.start();

      transport.connectPeer(_thabo);

      expect(events, [PeerLinkState.connected]);
    });

    test('connectPeer before start is a no-op', () async {
      final transport = MockTransport();
      var events = 0;
      transport.onPeer = (_, _) => events++;

      transport.connectPeer(_thabo);

      expect(events, 0);
    });

    test('disconnectPeer reports a peer as lost', () async {
      final transport = MockTransport();
      final events = <PeerLinkState>[];
      transport.onPeer = (_, state) => events.add(state);
      await transport.start();
      transport.connectPeer(_thabo);

      transport.disconnectPeer(_thabo);

      expect(events, [PeerLinkState.connected, PeerLinkState.lost]);
    });

    test('broadcast fans out to connected peers, excluding the given one', () async {
      final transport = MockTransport();
      transport.onPeer = (_, _) {};
      await transport.start();
      transport.connectPeer(_thabo);
      transport.connectPeer(_naledi);

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

      final excluded = await transport.broadcast(envelope, excludePeer: 'p-thabo');
      expect(excluded, 1);
    });

    test('broadcast returns 0 before start and after stop', () async {
      final transport = MockTransport();
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
      transport.connectPeer(_thabo);
      expect(await transport.broadcast(envelope), greaterThan(0));

      await transport.stop();
      expect(await transport.broadcast(envelope), 0);
    });

    test('stop clears connected peers', () async {
      final transport = MockTransport();
      transport.onPeer = (_, _) {};
      await transport.start();
      transport.connectPeer(_thabo);

      await transport.stop();
      await transport.start();

      final envelope = newEnvelope(
        id: 'e1',
        from: 'me',
        to: 'thabo',
        kind: EnvelopeKind.msg,
        body: 'hi',
        at: 0,
      );
      expect(await transport.broadcast(envelope), 0);
    });

    test('broadcast records a whole (unchunked) envelope as a single sent part', () async {
      final transport = MockTransport();
      transport.onPeer = (_, _) {};
      await transport.start();
      transport.connectPeer(_thabo);

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
    });

    test('broadcast chunks an oversized body before it "goes on the air"', () async {
      final transport = MockTransport();
      transport.onPeer = (_, _) {};
      await transport.start();
      transport.connectPeer(_thabo);

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
      expect(transport.sentParts.map((p) => p.id), ['photo1#0', 'photo1#1', 'photo1#2']);
    });

    test('broadcast does not chunk when the body fits in one part', () async {
      final transport = MockTransport();
      transport.onPeer = (_, _) {};
      await transport.start();
      transport.connectPeer(_thabo);

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
