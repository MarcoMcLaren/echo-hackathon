// Unit tests for lib/store/mesh_store.dart: the send() state machine,
// _upsertMessage's create-vs-append branches, _handlePeer's thread mutation,
// the stats counters, unread/markRead, the coin cancel window, revertLastCoin,
// notification triggers, groups/invites, image/event kinds, and persisted
// device identity.
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/messaging/events.dart';
import 'package:echo/features/messaging/notifier.dart';
import 'package:echo/features/messaging/types.dart';
import 'package:echo/features/vault/identity.dart';
import 'package:echo/store/mesh_store.dart';
import 'package:echo/store/mock.dart' as mock;
import 'package:echo/utils/relay.dart';

/// Hand-rolled [MeshTransport] double: start()/broadcast() results are fixed
/// per test, and onPeer/onEnvelope are fired manually to drive MeshStore.
class FakeTransport implements MeshTransport {
  FakeTransport({
    this.startResult = const TransportStartResult.ok(),
    this.fanout = 0,
  });

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
    test(
      'with no transport wired up, queues the message with null hops',
      () async {
        final store = MeshStore(deviceId: 'me');
        await store.send('thabo', 'hi');

        final thread = store.threads.firstWhere((t) => t.id == 'thabo');
        final msg = thread.messages.last;
        expect(msg.state, mock.MsgState.queued);
        expect(msg.hops, isNull);
      },
    );

    test(
      'to a connected peer marks the message delivered with 0 hops',
      () async {
        final transport = FakeTransport(fanout: 2);
        final store = MeshStore(transport: transport, deviceId: 'me');
        await store.start();
        transport.onPeer?.call(
          const PeerInfo(
            peerId: 'p-thabo',
            deviceId: 'thabo',
            display: 'Thabo Mokoena',
          ),
          PeerLinkState.connected,
        );

        await store.send('thabo', 'hi');

        final thread = store.threads.firstWhere((t) => t.id == 'thabo');
        final msg = thread.messages.last;
        expect(msg.state, mock.MsgState.delivered);
        expect(msg.hops, 0);
      },
    );

    test(
      'fanning out without a connected peer marks the message sent with 1 hop',
      () async {
        final transport = FakeTransport(fanout: 1);
        final store = MeshStore(transport: transport, deviceId: 'me');
        await store.start();

        await store.send('someone-unknown', 'hi');

        final thread = store.threads.firstWhere(
          (t) => t.id == 'someone-unknown',
        );
        final msg = thread.messages.last;
        expect(msg.state, mock.MsgState.sent);
        expect(msg.hops, 1);
      },
    );

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

    test(
      'appends to an existing thread without dropping prior history',
      () async {
        final store = MeshStore(deviceId: 'me');
        final before = store.threads
            .firstWhere((t) => t.id == 'thabo')
            .messages
            .length;

        await store.send('thabo', 'hey again');

        final thread = store.threads.firstWhere((t) => t.id == 'thabo');
        expect(thread.messages, hasLength(before + 1));
        expect(thread.messages.last.text, 'hey again');
      },
    );
  });

  group('_handlePeer', () {
    test('creates a thread for a previously unknown connected peer', () async {
      final transport = FakeTransport();
      final store = MeshStore(transport: transport, deviceId: 'me');
      await store.start();
      expect(store.threads.any((t) => t.id == 'newperson'), isFalse);

      transport.onPeer?.call(
        const PeerInfo(
          peerId: 'p-new',
          deviceId: 'newperson',
          display: 'New Person',
        ),
        PeerLinkState.connected,
      );

      final thread = store.threads.firstWhere((t) => t.id == 'newperson');
      expect(thread.title, 'New Person');
      expect(thread.hops, 0);
      expect(store.peers.containsKey('newperson'), isTrue);
    });

    test(
      'removes a lost peer entirely rather than marking it disconnected',
      () async {
        final transport = FakeTransport();
        final store = MeshStore(transport: transport, deviceId: 'me');
        await store.start();
        transport.onPeer?.call(
          const PeerInfo(
            peerId: 'p-thabo',
            deviceId: 'thabo',
            display: 'Thabo Mokoena',
          ),
          PeerLinkState.connected,
        );
        expect(store.peers.containsKey('thabo'), isTrue);

        transport.onPeer?.call(
          const PeerInfo(
            peerId: 'p-thabo',
            deviceId: 'thabo',
            display: 'Thabo Mokoena',
          ),
          PeerLinkState.lost,
        );

        // Ghost-peer fix: a lost peer is gone from the map, not lingering with
        // some disconnected flag — a node the peer count would disagree about.
        expect(store.peers.containsKey('thabo'), isFalse);
        final thread = store.threads.firstWhere((t) => t.id == 'thabo');
        expect(thread.hops, isNull);
      },
    );
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

    test(
      'delivering an envelope addressed to me appends to the sender thread',
      () async {
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
      },
    );

    test(
      'delivering a revert marks the referenced message reverted, not a new one',
      () async {
        final transport = FakeTransport();
        final store = MeshStore(transport: transport, deviceId: 'me');
        await store.start();
        transport.onEnvelope?.call(
          newEnvelope(
            id: 'c1',
            from: 'thabo',
            to: 'me',
            kind: EnvelopeKind.coin,
            body: '12.5',
            at: 0,
          ),
          'p-thabo',
        );
        final before = store.threads
            .firstWhere((t) => t.id == 'thabo')
            .messages
            .length;

        transport.onEnvelope?.call(
          newEnvelope(
            id: 'rv1',
            from: 'thabo',
            to: 'me',
            kind: EnvelopeKind.revert,
            body: 'c1',
            at: 0,
          ),
          'p-thabo',
        );

        final thread = store.threads.firstWhere((t) => t.id == 'thabo');
        expect(
          thread.messages,
          hasLength(before),
          reason: 'a revert updates, never appends',
        );
        expect(
          thread.messages.firstWhere((m) => m.id == 'c1').reverted,
          isTrue,
        );
        expect(store.stats.delivered, 2);
      },
    );
  });

  group('unread / markRead', () {
    test('a delivered message increments the thread unread count', () async {
      final transport = FakeTransport();
      final store = MeshStore(transport: transport, deviceId: 'me');
      await store.start();
      final before = store.threads.firstWhere((t) => t.id == 'thabo').unread;

      transport.onEnvelope?.call(
        newEnvelope(
          id: 'u1',
          from: 'thabo',
          to: 'me',
          kind: EnvelopeKind.msg,
          body: 'hi',
          at: 0,
        ),
        'p-thabo',
      );

      expect(
        store.threads.firstWhere((t) => t.id == 'thabo').unread,
        before + 1,
      );
    });

    test('markRead resets a thread unread count to zero', () async {
      final store = MeshStore(deviceId: 'me');
      expect(
        store.threads.firstWhere((t) => t.id == 'braai').unread,
        greaterThan(0),
      );

      store.markRead('braai');

      expect(store.threads.firstWhere((t) => t.id == 'braai').unread, 0);
    });
  });

  group('notifications', () {
    test('start() prepares the notifier', () async {
      final notifier = MockMeshNotifier();
      final store = MeshStore(
        transport: FakeTransport(),
        notifier: notifier,
        deviceId: 'me',
      );
      await store.start();
      expect(notifier.prepared, isTrue);
    });

    test('a delivered msg or coin notifies; a revert does not', () async {
      final notifier = MockMeshNotifier();
      final transport = FakeTransport();
      final store = MeshStore(
        transport: transport,
        notifier: notifier,
        deviceId: 'me',
      );
      await store.start();

      transport.onEnvelope?.call(
        newEnvelope(
          id: 'n1',
          from: 'thabo',
          to: 'me',
          kind: EnvelopeKind.msg,
          body: 'hi',
          at: 0,
        ),
        'p-thabo',
      );
      expect(notifier.sent, hasLength(1));
      expect(notifier.sent.single.body, 'hi');

      transport.onEnvelope?.call(
        newEnvelope(
          id: 'n2',
          from: 'thabo',
          to: 'me',
          kind: EnvelopeKind.revert,
          body: 'n1',
          at: 0,
        ),
        'p-thabo',
      );
      expect(
        notifier.sent,
        hasLength(1),
        reason: 'a revert is bookkeeping, not an arrival',
      );
    });
  });

  group('coin cancel window', () {
    test('queueCoin shows a pending placeholder immediately', () {
      final store = MeshStore(deviceId: 'me');
      store.queueCoin('thabo', 5);

      expect(store.pending, isNotNull);
      expect(store.pending!.amount, 5);
      final thread = store.threads.firstWhere((t) => t.id == 'thabo');
      expect(thread.messages.last.pending, isTrue);
      expect(thread.messages.last.coin, 5);

      store.cancelPending(); // avoid leaking a live Timer past the test
    });

    test('cancelPending removes the placeholder and clears pending', () {
      final store = MeshStore(deviceId: 'me');
      final before = store.threads
          .firstWhere((t) => t.id == 'thabo')
          .messages
          .length;
      store.queueCoin('thabo', 5);

      store.cancelPending();

      expect(store.pending, isNull);
      expect(
        store.threads.firstWhere((t) => t.id == 'thabo').messages,
        hasLength(before),
      );
    });

    test('queueCoin replaces a still-pending coin — one at a time', () {
      final store = MeshStore(deviceId: 'me');
      store.queueCoin('thabo', 5);
      final firstId = store.pending!.msgId;

      store.queueCoin('thabo', 10);

      expect(store.pending!.amount, 10);
      final thread = store.threads.firstWhere((t) => t.id == 'thabo');
      expect(thread.messages.where((m) => m.id == firstId), isEmpty);

      store.cancelPending();
    });

    test(
      'once the window elapses, the coin is actually sent and the placeholder clears',
      () {
        fakeAsync((async) {
          final transport = FakeTransport(fanout: 1);
          final store = MeshStore(transport: transport, deviceId: 'me');

          store.queueCoin('thabo', 5);
          async.elapse(const Duration(milliseconds: cancelWindowMs));

          expect(store.pending, isNull);
          expect(transport.broadcasted, hasLength(1));
          expect(transport.broadcasted.single.kind, EnvelopeKind.coin);
        });
      },
    );

    test('cancelling before the window elapses never sends anything', () {
      fakeAsync((async) {
        final transport = FakeTransport(fanout: 1);
        final store = MeshStore(transport: transport, deviceId: 'me');

        store.queueCoin('thabo', 5);
        store.cancelPending();
        async.elapse(const Duration(milliseconds: cancelWindowMs));

        expect(transport.broadcasted, isEmpty);
      });
    });
  });

  group('revertLastCoin', () {
    test(
      'marks the most recent coin I sent as reverted and broadcasts a revert',
      () async {
        final transport = FakeTransport(fanout: 1);
        final store = MeshStore(transport: transport, deviceId: 'me');
        await store.start();
        await store.send('thabo', '5', kind: EnvelopeKind.coin);
        final sentId = store.threads
            .firstWhere((t) => t.id == 'thabo')
            .messages
            .last
            .id;

        final did = await store.revertLastCoin('thabo');

        expect(did, isTrue);
        final thread = store.threads.firstWhere((t) => t.id == 'thabo');
        expect(
          thread.messages.firstWhere((m) => m.id == sentId).reverted,
          isTrue,
        );
        expect(transport.broadcasted.last.kind, EnvelopeKind.revert);
        expect(transport.broadcasted.last.body, sentId);
      },
    );

    test('returns false when there is no coin of mine to revert', () async {
      final store = MeshStore(deviceId: 'me');
      // The seeded thabo thread has a coin from thabo, not from me.
      expect(await store.revertLastCoin('thabo'), isFalse);
    });

    test('returns false for an unknown thread', () async {
      final store = MeshStore(deviceId: 'me');
      expect(await store.revertLastCoin('nope'), isFalse);
    });
  });

  group('stop', () {
    test(
      'drops peers and sets hops to null on threads that were connected',
      () async {
        final transport = FakeTransport();
        final store = MeshStore(transport: transport, deviceId: 'me');
        await store.start();
        transport.onPeer?.call(
          const PeerInfo(
            peerId: 'p-thabo',
            deviceId: 'thabo',
            display: 'Thabo Mokoena',
          ),
          PeerLinkState.connected,
        );
        expect(store.threads.firstWhere((t) => t.id == 'thabo').hops, 0);

        await store.stop();

        expect(store.peers, isEmpty);
        expect(store.threads.firstWhere((t) => t.id == 'thabo').hops, isNull);
      },
    );
  });

  group('createGroup', () {
    test('creates a group thread with me + the given members', () async {
      final store = MeshStore(deviceId: 'me');
      final id = await store.createGroup('Braai Crew', ['thabo', 'naledi']);

      final thread = store.threads.firstWhere((t) => t.id == id);
      expect(thread.group, isTrue);
      expect(thread.members, ['me', 'thabo', 'naledi']);
      expect(thread.title, 'Braai Crew');
      expect(thread.preview, '3 people');
      expect(thread.messages, isEmpty);
    });

    test('broadcasts an invite envelope addressed to the group', () async {
      final transport = FakeTransport(fanout: 2);
      final store = MeshStore(transport: transport, deviceId: 'me');
      await store.start();

      final id = await store.createGroup('Braai Crew', ['thabo']);

      final invite = transport.broadcasted.last;
      expect(invite.kind, EnvelopeKind.invite);
      expect(invite.to, id);
      final body = jsonDecode(invite.body) as Map;
      expect(body['id'], id);
      expect(body['name'], 'Braai Crew');
      expect(body['members'], ['me', 'thabo']);
    });

    test(
      'an invite is bookkeeping — it adds no message to the group thread',
      () async {
        final transport = FakeTransport(fanout: 1);
        final store = MeshStore(transport: transport, deviceId: 'me');
        await store.start();

        final id = await store.createGroup('Braai Crew', ['thabo']);

        expect(store.threads.firstWhere((t) => t.id == id).messages, isEmpty);
        expect(store.stats.sent, 1);
      },
    );
  });

  group('group traffic (via transport.onEnvelope)', () {
    test('an invite creates the group thread when I am a member', () async {
      final transport = FakeTransport(fanout: 1);
      final store = MeshStore(transport: transport, deviceId: 'me');
      await store.start();

      transport.onEnvelope?.call(
        newEnvelope(
          id: 'inv1',
          from: 'thabo',
          to: 'g:braai2',
          kind: EnvelopeKind.invite,
          body: jsonEncode({
            'id': 'g:braai2',
            'name': 'Braai Crew',
            'members': ['me', 'thabo', 'naledi'],
          }),
          at: 0,
        ),
        'p-thabo',
      );

      final thread = store.threads.firstWhere((t) => t.id == 'g:braai2');
      expect(thread.group, isTrue);
      expect(thread.title, 'Braai Crew');
      expect(thread.members, ['me', 'thabo', 'naledi']);
    });

    test('an invite that does not name me is ignored', () async {
      final transport = FakeTransport(fanout: 1);
      final store = MeshStore(transport: transport, deviceId: 'me');
      await store.start();

      transport.onEnvelope?.call(
        newEnvelope(
          id: 'inv2',
          from: 'thabo',
          to: 'g:other',
          kind: EnvelopeKind.invite,
          body: jsonEncode({
            'id': 'g:other',
            'name': 'Other Group',
            'members': ['thabo', 'naledi'],
          }),
          at: 0,
        ),
        'p-thabo',
      );

      expect(store.threads.any((t) => t.id == 'g:other'), isFalse);
    });

    test('a malformed invite is dropped without throwing', () async {
      final transport = FakeTransport(fanout: 1);
      final store = MeshStore(transport: transport, deviceId: 'me');
      await store.start();

      expect(
        () => transport.onEnvelope?.call(
          newEnvelope(
            id: 'inv3',
            from: 'thabo',
            to: 'g:bad',
            kind: EnvelopeKind.invite,
            body: 'not json',
            at: 0,
          ),
          'p-thabo',
        ),
        returnsNormally,
      );
      expect(store.threads.any((t) => t.id == 'g:bad'), isFalse);
    });

    test(
      'group traffic is always relayed on, even when I am not a member',
      () async {
        final transport = FakeTransport(fanout: 1);
        final store = MeshStore(transport: transport, deviceId: 'me');
        await store.start();

        transport.onEnvelope?.call(
          newEnvelope(
            id: 'g1',
            from: 'thabo',
            to: 'g:not-mine',
            kind: EnvelopeKind.msg,
            body: 'hi',
            at: 0,
          ),
          'p-thabo',
        );

        expect(transport.broadcasted, hasLength(1));
        expect(store.stats.relayed, 1);
        expect(store.stats.delivered, 0);
        expect(store.threads.any((t) => t.id == 'g:not-mine'), isFalse);
      },
    );

    test(
      'group traffic is delivered into the thread when I am a member',
      () async {
        final transport = FakeTransport(fanout: 1);
        final store = MeshStore(transport: transport, deviceId: 'me');
        await store.start();
        final groupId = await store.createGroup('Braai Crew', ['thabo']);

        transport.onEnvelope?.call(
          newEnvelope(
            id: 'g2',
            from: 'thabo',
            fromName: 'Thabo Mokoena',
            to: groupId,
            kind: EnvelopeKind.msg,
            body: 'bring wood',
            at: 0,
          ),
          'p-thabo',
        );

        final thread = store.threads.firstWhere((t) => t.id == groupId);
        expect(thread.messages.last.text, 'bring wood');
        expect(thread.messages.last.from, 'thabo');
        expect(store.stats.delivered, 1);
      },
    );

    test(
      'a ttl-exhausted group envelope is not relayed again but is still '
      'delivered to members',
      () async {
        final transport = FakeTransport(fanout: 1);
        final store = MeshStore(transport: transport, deviceId: 'me');
        await store.start();
        final groupId = await store.createGroup('Braai Crew', ['thabo']);
        final broadcastsBefore = transport.broadcasted.length;

        transport.onEnvelope?.call(
          newEnvelope(
            id: 'g3',
            from: 'thabo',
            to: groupId,
            kind: EnvelopeKind.msg,
            body: 'last hop',
            ttl: 0,
            at: 0,
          ),
          'p-thabo',
        );

        expect(transport.broadcasted, hasLength(broadcastsBefore));
        final thread = store.threads.firstWhere((t) => t.id == groupId);
        expect(thread.messages.last.text, 'last hop');
      },
    );
  });

  group('fromName', () {
    test('send() carries me.display as the envelope fromName', () async {
      final transport = FakeTransport(fanout: 1);
      final store = MeshStore(
        transport: transport,
        deviceId: 'me',
        display: 'Reon Fourie',
      );
      await store.start();

      await store.send('thabo', 'hi');

      expect(transport.broadcasted.single.fromName, 'Reon Fourie');
    });

    test('setName changes what future sends carry', () async {
      final transport = FakeTransport(fanout: 1);
      final store = MeshStore(
        transport: transport,
        deviceId: 'me',
        display: 'Old Name',
      );
      await store.start();
      store.setName('New Name');

      await store.send('thabo', 'hi');

      expect(transport.broadcasted.single.fromName, 'New Name');
    });

    test(
      'a relayed sender not in the peer list is notified/titled by fromName',
      () async {
        final notifier = MockMeshNotifier();
        final transport = FakeTransport();
        final store = MeshStore(
          transport: transport,
          notifier: notifier,
          deviceId: 'me',
        );
        await store.start();

        transport.onEnvelope?.call(
          newEnvelope(
            id: 'far1',
            from: 'stranger-device-id',
            fromName: 'Distant Cousin',
            to: 'me',
            kind: EnvelopeKind.msg,
            body: 'hi from far away',
            at: 0,
          ),
          'p-relay',
        );

        expect(notifier.sent.single.from, 'Distant Cousin');
        final thread = store.threads.firstWhere(
          (t) => t.id == 'stranger-device-id',
        );
        expect(thread.title, 'Distant Cousin');
      },
    );

    test(
      'without fromName, notify falls back to the peer list display name',
      () async {
        final notifier = MockMeshNotifier();
        final transport = FakeTransport();
        final store = MeshStore(
          transport: transport,
          notifier: notifier,
          deviceId: 'me',
        );
        await store.start();
        transport.onPeer?.call(
          const PeerInfo(
            peerId: 'p-thabo',
            deviceId: 'thabo',
            display: 'Thabo Mokoena',
          ),
          PeerLinkState.connected,
        );

        transport.onEnvelope?.call(
          newEnvelope(
            id: 'near1',
            from: 'thabo',
            to: 'me',
            kind: EnvelopeKind.msg,
            body: 'hi',
            at: 0,
          ),
          'p-thabo',
        );

        expect(notifier.sent.single.from, 'Thabo Mokoena');
      },
    );

    test(
      'a thread titled with the raw device id is renamed once the sender '
      'becomes a peer',
      () async {
        final transport = FakeTransport();
        final store = MeshStore(transport: transport, deviceId: 'me');
        await store.start();

        // No fromName: the thread is titled with the raw device id.
        transport.onEnvelope?.call(
          newEnvelope(
            id: 'pre1',
            from: 'newperson',
            to: 'me',
            kind: EnvelopeKind.msg,
            body: 'hi',
            at: 0,
          ),
          'p-x',
        );
        expect(
          store.threads.firstWhere((t) => t.id == 'newperson').title,
          'newperson',
        );

        transport.onPeer?.call(
          const PeerInfo(
            peerId: 'p-new',
            deviceId: 'newperson',
            display: 'New Person',
          ),
          PeerLinkState.connected,
        );

        final thread = store.threads.firstWhere((t) => t.id == 'newperson');
        expect(thread.title, 'New Person');
        expect(thread.initials, 'NP');
      },
    );

    test(
      'a thread already titled from fromName is left alone once the sender '
      'becomes a peer',
      () async {
        final transport = FakeTransport();
        final store = MeshStore(transport: transport, deviceId: 'me');
        await store.start();

        transport.onEnvelope?.call(
          newEnvelope(
            id: 'pre2',
            from: 'newperson',
            fromName: 'New Person (relayed)',
            to: 'me',
            kind: EnvelopeKind.msg,
            body: 'hi',
            at: 0,
          ),
          'p-x',
        );

        transport.onPeer?.call(
          const PeerInfo(
            peerId: 'p-new',
            deviceId: 'newperson',
            display: 'New Person',
          ),
          PeerLinkState.connected,
        );

        expect(
          store.threads.firstWhere((t) => t.id == 'newperson').title,
          'New Person (relayed)',
        );
      },
    );
  });

  group('image and event kinds', () {
    test(
      'send(kind: image) stores the body as the image and previews "Photo"',
      () async {
        final store = MeshStore(deviceId: 'me');
        await store.send(
          'thabo',
          'data:image/jpeg;base64,abcd',
          kind: EnvelopeKind.image,
        );

        final thread = store.threads.firstWhere((t) => t.id == 'thabo');
        expect(thread.messages.last.image, 'data:image/jpeg;base64,abcd');
        expect(thread.messages.last.text, isNull);
        expect(thread.preview, 'Photo');
      },
    );

    test(
      'send(kind: event) decodes the body and previews the event title',
      () async {
        final store = MeshStore(deviceId: 'me');
        final body = encodeEvent(
          const MeshEvent(title: 'Braai', startsAt: 1000),
        );

        await store.send('thabo', body, kind: EnvelopeKind.event);

        final thread = store.threads.firstWhere((t) => t.id == 'thabo');
        expect(thread.messages.last.event?.title, 'Braai');
        expect(thread.preview, 'Braai');
      },
    );

    test('receiving an image envelope stores it on the delivered message', () async {
      final transport = FakeTransport();
      final store = MeshStore(transport: transport, deviceId: 'me');
      await store.start();

      transport.onEnvelope?.call(
        newEnvelope(
          id: 'img1',
          from: 'thabo',
          to: 'me',
          kind: EnvelopeKind.image,
          body: 'data:image/jpeg;base64,abcd',
          at: 0,
        ),
        'p-thabo',
      );

      final thread = store.threads.firstWhere((t) => t.id == 'thabo');
      expect(thread.messages.last.image, 'data:image/jpeg;base64,abcd');
      expect(thread.preview, 'Photo');
    });

    test(
      'receiving an event envelope decodes it onto the delivered message',
      () async {
        final transport = FakeTransport();
        final store = MeshStore(transport: transport, deviceId: 'me');
        await store.start();
        final body = encodeEvent(
          const MeshEvent(title: 'Braai', startsAt: 1000),
        );

        transport.onEnvelope?.call(
          newEnvelope(
            id: 'evt1',
            from: 'thabo',
            to: 'me',
            kind: EnvelopeKind.event,
            body: body,
            at: 0,
          ),
          'p-thabo',
        );

        final thread = store.threads.firstWhere((t) => t.id == 'thabo');
        expect(thread.messages.last.event?.title, 'Braai');
      },
    );

    test(
      'a malformed event body decodes to a null event rather than throwing',
      () async {
        final store = MeshStore(deviceId: 'me');
        await store.send('thabo', 'not json', kind: EnvelopeKind.event);

        final thread = store.threads.firstWhere((t) => t.id == 'thabo');
        expect(thread.messages.last.event, isNull);
      },
    );
  });

  group('persisted device identity', () {
    test('an explicit deviceId is never overridden by start()', () async {
      final identityStore = InMemoryIdentityStore();
      await identityStore.write('should-not-be-used');
      final store = MeshStore(deviceId: 'me', identityStore: identityStore);

      await store.start();

      expect(store.me.deviceId, 'me');
    });

    test(
      'without an explicit deviceId, start() resolves and persists an id',
      () async {
        final identityStore = InMemoryIdentityStore();
        final store = MeshStore(identityStore: identityStore);

        await store.start();

        final resolved = store.me.deviceId;
        expect(resolved, isNotEmpty);
        expect(await identityStore.read(), resolved);
      },
    );

    test(
      'a second store sharing the identity store resolves to the same id',
      () async {
        final identityStore = InMemoryIdentityStore();
        final first = MeshStore(identityStore: identityStore);
        await first.start();

        final second = MeshStore(identityStore: identityStore);
        await second.start();

        expect(second.me.deviceId, first.me.deviceId);
      },
    );
  });
}
