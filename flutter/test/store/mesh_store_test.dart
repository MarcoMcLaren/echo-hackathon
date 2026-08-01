// Unit tests for lib/store/mesh_store.dart: the send() state machine,
// _upsertMessage's create-vs-append branches, _handlePeer's thread mutation,
// and the stats counters.
import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/messaging/types.dart';
import 'package:echo/store/mesh_store.dart';
import 'package:echo/store/mock.dart' as mock;
import 'package:echo/utils/relay.dart';

/// Hand-rolled [MeshTransport] double: start()/broadcast() results are fixed
/// per test, and onPeer/onEnvelope are fired manually to drive MeshStore.
class FakeTransport implements MeshTransport {
  FakeTransport({this.startResult = const TransportStartResult.ok(), this.fanout = 0});

  final TransportStartResult startResult;
  final int fanout;
  final List<Envelope> broadcasted = [];

  @override
  void Function(PeerInfo peer, PeerLinkState state)? onPeer;

  @override
  void Function(Envelope envelope, String fromPeerId)? onEnvelope;

  @override
  void Function(String message)? onError;

  @override
  Future<TransportStartResult> start() async => startResult;

  @override
  Future<void> stop() async {}

  @override
  Future<int> broadcast(Envelope envelope, {String? excludePeer}) async {
    broadcasted.add(envelope);
    return fanout;
  }
}

void main() {
  group('send', () {
    test('with no transport wired up, queues the message with null hops', () async {
      final store = MeshStore(deviceId: 'me');
      await store.send('thabo', 'hi');

      final thread = store.threads.firstWhere((t) => t.id == 'thabo');
      final msg = thread.messages.last;
      expect(msg.state, mock.MsgState.queued);
      expect(msg.hops, isNull);
    });

    test('to a connected peer marks the message delivered with 0 hops', () async {
      final transport = FakeTransport(fanout: 2);
      final store = MeshStore(transport: transport, deviceId: 'me');
      await store.start();
      transport.onPeer?.call(
        const PeerInfo(peerId: 'p-thabo', deviceId: 'thabo', display: 'Thabo Mokoena'),
        PeerLinkState.connected,
      );

      await store.send('thabo', 'hi');

      final thread = store.threads.firstWhere((t) => t.id == 'thabo');
      final msg = thread.messages.last;
      expect(msg.state, mock.MsgState.delivered);
      expect(msg.hops, 0);
    });

    test('fanning out without a connected peer marks the message sent with 1 hop', () async {
      final transport = FakeTransport(fanout: 1);
      final store = MeshStore(transport: transport, deviceId: 'me');
      await store.start();

      await store.send('someone-unknown', 'hi');

      final thread = store.threads.firstWhere((t) => t.id == 'someone-unknown');
      final msg = thread.messages.last;
      expect(msg.state, mock.MsgState.sent);
      expect(msg.hops, 1);
    });

    test('increments stats.sent', () async {
      final store = MeshStore(deviceId: 'me');
      expect(store.stats.sent, 0);
      await store.send('thabo', 'hi');
      expect(store.stats.sent, 1);
    });

    test('a coin send formats the thread preview with two decimals', () async {
      final store = MeshStore(deviceId: 'me');
      await store.send('thabo', '5', kind: EnvelopeKind.coin);

      final thread = store.threads.firstWhere((t) => t.id == 'thabo');
      expect(thread.preview, '5.00 echocoin');
      expect(thread.messages.last.coin, 5.0);
      expect(thread.messages.last.text, isNull);
    });
  });

  group('_upsertMessage (via send)', () {
    test('creates a new thread when the target id is unknown', () async {
      final store = MeshStore(deviceId: 'me');
      expect(store.threads.any((t) => t.id == 'brand-new'), isFalse);

      await store.send('brand-new', 'hey');

      final thread = store.threads.firstWhere((t) => t.id == 'brand-new');
      expect(thread.messages, hasLength(1));
      expect(thread.preview, 'hey');
    });

    test('appends to an existing thread without dropping prior history', () async {
      final store = MeshStore(deviceId: 'me');
      final before = store.threads.firstWhere((t) => t.id == 'thabo').messages.length;

      await store.send('thabo', 'hey again');

      final thread = store.threads.firstWhere((t) => t.id == 'thabo');
      expect(thread.messages, hasLength(before + 1));
      expect(thread.messages.last.text, 'hey again');
    });
  });

  group('_handlePeer', () {
    test('creates a thread for a previously unknown connected peer', () async {
      final transport = FakeTransport();
      final store = MeshStore(transport: transport, deviceId: 'me');
      await store.start();
      expect(store.threads.any((t) => t.id == 'newperson'), isFalse);

      transport.onPeer?.call(
        const PeerInfo(peerId: 'p-new', deviceId: 'newperson', display: 'New Person'),
        PeerLinkState.connected,
      );

      final thread = store.threads.firstWhere((t) => t.id == 'newperson');
      expect(thread.title, 'New Person');
      expect(thread.hops, 0);
      expect(store.peers['newperson']?.connected, isTrue);
    });

    test('flips an existing thread hops to null when the peer is lost', () async {
      final transport = FakeTransport();
      final store = MeshStore(transport: transport, deviceId: 'me');
      await store.start();
      transport.onPeer?.call(
        const PeerInfo(peerId: 'p-thabo', deviceId: 'thabo', display: 'Thabo Mokoena'),
        PeerLinkState.connected,
      );
      expect(store.peers['thabo']?.connected, isTrue);

      transport.onPeer?.call(
        const PeerInfo(peerId: 'p-thabo', deviceId: 'thabo', display: 'Thabo Mokoena'),
        PeerLinkState.lost,
      );

      expect(store.peers['thabo']?.connected, isFalse);
      final thread = store.threads.firstWhere((t) => t.id == 'thabo');
      expect(thread.hops, isNull);
    });
  });

  group('_handleEnvelope (via transport.onEnvelope)', () {
    test('a duplicate envelope increments stats.dropped', () async {
      final transport = FakeTransport();
      final store = MeshStore(transport: transport, deviceId: 'me');
      await store.start();
      final envelope = newEnvelope(
        id: 'dup1',
        from: 'thabo',
        to: 'someone-else',
        kind: EnvelopeKind.msg,
        body: 'hi',
        at: 0,
      );

      transport.onEnvelope?.call(envelope, 'p-thabo');
      expect(store.stats.dropped, 0);
      transport.onEnvelope?.call(envelope, 'p-thabo');
      expect(store.stats.dropped, 1);
    });

    test('relaying increments stats.relayed and rebroadcasts', () async {
      final transport = FakeTransport(fanout: 1);
      final store = MeshStore(transport: transport, deviceId: 'me');
      await store.start();
      final envelope = newEnvelope(
        id: 'r1',
        from: 'someone',
        to: 'not-me',
        kind: EnvelopeKind.msg,
        body: 'hi',
        at: 0,
      );

      transport.onEnvelope?.call(envelope, 'p-x');

      expect(store.stats.relayed, 1);
      expect(transport.broadcasted, hasLength(1));
      expect(transport.broadcasted.first.path, contains('me'));
    });

    test('delivering an envelope addressed to me appends to the sender thread', () async {
      final transport = FakeTransport();
      final store = MeshStore(transport: transport, deviceId: 'me');
      await store.start();
      final envelope = newEnvelope(
        id: 'd1',
        from: 'thabo',
        to: 'me',
        kind: EnvelopeKind.msg,
        body: 'yo',
        at: 0,
      );

      transport.onEnvelope?.call(envelope, 'p-thabo');

      expect(store.stats.delivered, 1);
      final thread = store.threads.firstWhere((t) => t.id == 'thabo');
      expect(thread.messages.last.text, 'yo');
      expect(thread.messages.last.from, 'thabo');
    });
  });
}
