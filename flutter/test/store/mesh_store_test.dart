// Unit tests for lib/store/mesh_store.dart: the send() state machine,
// _upsertMessage's create-vs-append branches, _handlePeer's thread mutation,
// the stats counters, unread/markRead, the coin cancel window, revertLastCoin,
// notification triggers, groups/invites, image/event kinds, persisted device
// identity, and the pairing model (contacts gate who can message you, peers
// alone never can).
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/messaging/events.dart';
import 'package:echo/features/messaging/notifier.dart';
import 'package:echo/features/messaging/types.dart';
import 'package:echo/features/vault/contacts.dart';
import 'package:echo/features/vault/identity.dart';
import 'package:echo/store/mesh_store.dart';
import 'package:echo/store/types.dart';
import 'package:echo/utils/relay.dart';

import '../support/demo_data.dart';

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
        expect(msg.state, MsgState.queued);
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
        expect(msg.state, MsgState.delivered);
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
        expect(msg.state, MsgState.sent);
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
        await store.send('thabo', 'hey');
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
    test('connecting to a stranger does not create a conversation', () async {
      final transport = FakeTransport();
      final store = MeshStore(transport: transport, deviceId: 'me');
      await store.start();

      transport.onPeer?.call(
        const PeerInfo(
          peerId: 'p-new',
          deviceId: 'newperson',
          display: 'New Person',
        ),
        PeerLinkState.connected,
      );

      expect(store.threads.any((t) => t.id == 'newperson'), isFalse);
      expect(store.peers.containsKey('newperson'), isTrue);
    });

    test(
      'connecting to an already-paired contact updates the route on their thread',
      () async {
        final transport = FakeTransport();
        final store = demoStore(transport: transport);
        await store.start();
        // Naledi is seeded reachable only via a relay (hops: 1).
        expect(store.threads.firstWhere((t) => t.id == 'naledi').hops, 1);

        transport.onPeer?.call(
          const PeerInfo(
            peerId: 'p-naledi',
            deviceId: 'naledi',
            display: 'Naledi Khumalo',
          ),
          PeerLinkState.connected,
        );

        expect(store.threads.firstWhere((t) => t.id == 'naledi').hops, 0);
      },
    );

    test(
      'removes a lost peer entirely rather than marking it disconnected',
      () async {
        final transport = FakeTransport();
        final store = demoStore(transport: transport);
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

  group('contact gating (via transport.onEnvelope)', () {
    test(
      'a message from someone who is not a contact is dropped, not delivered',
      () async {
        final transport = FakeTransport();
        final store = MeshStore(transport: transport, deviceId: 'me');
        await store.start();

        transport.onEnvelope?.call(
          newEnvelope(
            id: 's1',
            from: 'stranger',
            to: 'me',
            kind: EnvelopeKind.msg,
            body: 'hi',
            at: 0,
          ),
          'p-stranger',
        );

        expect(store.stats.dropped, 1);
        expect(store.stats.delivered, 0);
        expect(store.threads.any((t) => t.id == 'stranger'), isFalse);
      },
    );

    test('a message from a paired contact is delivered', () async {
      final transport = FakeTransport();
      final store = demoStore(transport: transport);
      await store.start();

      transport.onEnvelope?.call(
        newEnvelope(
          id: 's2',
          from: 'thabo',
          to: 'me',
          kind: EnvelopeKind.msg,
          body: 'hi',
          at: 0,
        ),
        'p-thabo',
      );

      expect(store.stats.delivered, 1);
      expect(store.stats.dropped, 0);
    });

    test(
      'an invite from a non-contact is dropped even though it names me as a member',
      () async {
        final transport = FakeTransport(fanout: 1);
        final store = MeshStore(transport: transport, deviceId: 'me');
        await store.start();

        transport.onEnvelope?.call(
          newEnvelope(
            id: 'inv-stranger',
            from: 'stranger',
            to: 'g:x',
            kind: EnvelopeKind.invite,
            body: jsonEncode({
              'id': 'g:x',
              'name': 'X',
              'members': ['me', 'stranger'],
            }),
            at: 0,
          ),
          'p-stranger',
        );

        expect(store.threads.any((t) => t.id == 'g:x'), isFalse);
        expect(store.stats.dropped, 1);
      },
    );
  });

  group('unread / markRead', () {
    test('a delivered message increments the thread unread count', () async {
      final transport = FakeTransport();
      final store = demoStore(transport: transport);
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
      final store = demoStore();
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
      final store = demoStore(transport: transport, notifier: notifier);
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
      final store = demoStore();
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
      final store = demoStore();
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
        final store = demoStore(transport: transport);
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
      final store = demoStore(transport: transport);
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
      final store = demoStore(transport: transport);
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
      final store = demoStore(transport: transport);
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
      'group traffic is delivered into the thread when I am a member, even '
      'from someone who is not a contact — the group is its own trust boundary',
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

  group('pair', () {
    test('creates a conversation for a newly met device', () async {
      final store = MeshStore(deviceId: 'me');

      await store.pair('thabo', 'Thabo Mokoena');

      expect(store.contacts.containsKey('thabo'), isTrue);
      final thread = store.threads.firstWhere((t) => t.id == 'thabo');
      expect(thread.title, 'Thabo Mokoena');
      expect(thread.messages, isEmpty);
    });

    test(
      'pairing with someone already connected marks the thread reachable now',
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

        await store.pair('thabo', 'Thabo Mokoena');

        expect(store.threads.firstWhere((t) => t.id == 'thabo').hops, 0);
      },
    );

    test(
      're-pairing an existing thread renames it rather than duplicating it',
      () async {
        final store = demoStore();
        final before = store.threads.length;

        await store.pair('thabo', 'Thabo M.');

        expect(store.threads.length, before);
        expect(
          store.threads.firstWhere((t) => t.id == 'thabo').title,
          'Thabo M.',
        );
      },
    );
  });

  group('unpair', () {
    test(
      'removes the contact and its conversation, but the peer connection stays',
      () async {
        final transport = FakeTransport();
        final store = demoStore(transport: transport);
        await store.start();
        transport.onPeer?.call(
          const PeerInfo(
            peerId: 'p-thabo',
            deviceId: 'thabo',
            display: 'Thabo Mokoena',
          ),
          PeerLinkState.connected,
        );

        await store.unpair('thabo');

        expect(store.contacts.containsKey('thabo'), isFalse);
        expect(store.threads.any((t) => t.id == 'thabo'), isFalse);
        expect(store.peers.containsKey('thabo'), isTrue);
      },
    );

    test('a message from an unpaired device is dropped again', () async {
      final transport = FakeTransport();
      final store = demoStore(transport: transport);
      await store.start();
      await store.unpair('thabo');

      transport.onEnvelope?.call(
        newEnvelope(
          id: 'after-unpair',
          from: 'thabo',
          to: 'me',
          kind: EnvelopeKind.msg,
          body: 'hi',
          at: 0,
        ),
        'p-thabo',
      );

      expect(store.stats.dropped, 1);
      expect(store.stats.delivered, 0);
    });
  });

  group('forgetThread', () {
    test('removes a thread with no contact behind it, such as a group', () async {
      final store = MeshStore(deviceId: 'me');
      final id = await store.createGroup('Braai Crew', []);

      store.forgetThread(id);

      expect(store.threads.any((t) => t.id == id), isFalse);
    });
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
      'a paired sender not in the peer list is notified by fromName',
      () async {
        final notifier = MockMeshNotifier();
        final transport = FakeTransport();
        final store = MeshStore(
          transport: transport,
          notifier: notifier,
          deviceId: 'me',
        );
        await store.start();
        await store.pair('stranger-device-id', 'Distant Cousin');

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
      },
    );

    test(
      'without fromName, notify falls back to the peer list display name',
      () async {
        final notifier = MockMeshNotifier();
        final transport = FakeTransport();
        final store = demoStore(transport: transport, notifier: notifier);
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
      final store = demoStore(transport: transport);
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
        final store = demoStore(transport: transport);
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
      final profileStore = InMemoryProfileStore();
      await profileStore.write(const Profile(id: 'should-not-be-used', name: 'Nope'));
      final store = MeshStore(deviceId: 'me', profileStore: profileStore);

      await store.start();

      expect(store.me.deviceId, 'me');
    });

    test(
      'without a profile yet, start() leaves the phone pending rather than minting an id',
      () async {
        final store = MeshStore(profileStore: InMemoryProfileStore());

        await store.start();

        expect(store.ready, isFalse);
        expect(store.me.deviceId, 'pending');
      },
    );

    test('createIdentity mints and persists a profile', () async {
      final profileStore = InMemoryProfileStore();
      final store = MeshStore(profileStore: profileStore);

      await store.createIdentity('Reon Fourie');

      expect(store.ready, isTrue);
      expect(store.me.deviceId, isNotEmpty);
      expect(store.me.display, 'Reon Fourie');
      expect((await profileStore.read())?.name, 'Reon Fourie');
    });

    test(
      'a second store sharing the profile store resolves to the same id',
      () async {
        final profileStore = InMemoryProfileStore();
        final first = MeshStore(profileStore: profileStore);
        await first.createIdentity('Reon Fourie');

        final second = MeshStore(profileStore: profileStore);
        await second.start();

        expect(second.me.deviceId, first.me.deviceId);
        expect(second.ready, isTrue);
      },
    );

    test(
      'contacts persisted under a shared store are rebuilt into threads on init',
      () async {
        final profileStore = InMemoryProfileStore();
        final contactsStore = InMemoryContactsStore();
        final first = MeshStore(profileStore: profileStore, contactsStore: contactsStore);
        await first.createIdentity('Reon Fourie');
        await first.pair('thabo', 'Thabo Mokoena');

        final second = MeshStore(profileStore: profileStore, contactsStore: contactsStore);
        await second.start();

        expect(second.contacts.containsKey('thabo'), isTrue);
        expect(second.threads.any((t) => t.id == 'thabo'), isTrue);
      },
    );
  });

  group('resetApp', () {
    test('wipes identity, contacts, and threads back to first-run', () async {
      final profileStore = InMemoryProfileStore();
      final contactsStore = InMemoryContactsStore();
      final store = MeshStore(profileStore: profileStore, contactsStore: contactsStore);
      await store.createIdentity('Reon Fourie');
      await store.pair('thabo', 'Thabo Mokoena');

      await store.resetApp();

      expect(store.ready, isFalse);
      expect(store.me.deviceId, 'pending');
      expect(store.contacts, isEmpty);
      expect(store.threads, isEmpty);
      expect(await profileStore.read(), isNull);
    });
  });
}
