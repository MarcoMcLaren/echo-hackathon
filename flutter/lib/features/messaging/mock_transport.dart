// Mock implementation of [MeshTransport], wired to the demo contacts in
// store/mock.dart so [MeshStore] has something to go "live" over headlessly.
//
// Port intent of src/features/messaging/api/transport.ts's MeshTransport
// class, minus the native expo-nearby-connections calls: this is the fake
// half of the adapter pair described there. The real BLE/Nearby-equivalent
// transport is native platform work that lands separately and must also
// implement the [MeshTransport] contract in types.dart.
import 'dart:async';

import '../../store/mock.dart' as mock;
import '../../utils/relay.dart';
import 'types.dart';

/// Simulates discovering and connecting to the direct (hops == 0) demo
/// contacts shortly after [start], and staying silent about anyone out of
/// direct radio range — matching what a real P2P-clustering transport could
/// see on its own (multi-hop reach is [MeshStore]'s relay logic, not the
/// transport's).
class MockTransport implements MeshTransport {
  MockTransport({this.peerJoinDelay = const Duration(milliseconds: 400)});

  final Duration peerJoinDelay;

  @override
  void Function(PeerInfo peer, PeerLinkState state)? onPeer;

  @override
  void Function(Envelope envelope, String fromPeerId)? onEnvelope;

  @override
  void Function(String message)? onError;

  final List<Timer> _timers = [];
  final Set<String> _connectedPeerIds = {};
  bool _running = false;

  @override
  Future<TransportStartResult> start() async {
    if (_running) return const TransportStartResult.ok();
    _running = true;

    for (final contact in mock.contacts.where((c) => c.hops == 0)) {
      final timer = Timer(peerJoinDelay, () {
        if (!_running) return;
        final peerId = 'mock-${contact.id}';
        _connectedPeerIds.add(peerId);
        onPeer?.call(
          PeerInfo(peerId: peerId, deviceId: contact.id, display: contact.name),
          PeerLinkState.connected,
        );
      });
      _timers.add(timer);
    }

    return const TransportStartResult.ok();
  }

  @override
  Future<void> stop() async {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _connectedPeerIds.clear();
    _running = false;
  }

  @override
  Future<int> broadcast(Envelope envelope, {String? excludePeer}) async {
    if (!_running) return 0;
    return _connectedPeerIds.where((id) => id != excludePeer).length;
  }
}
