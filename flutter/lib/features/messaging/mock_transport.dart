// A [MeshTransport] double for tests and for a build that hasn't wired up a
// real transport yet. Connects nobody on its own — a real transport reports
// peers it actually discovers over the air, and fabricating some here would
// make every screen built against this look alive when the mesh is not.
// Tests that need a peer call [connectPeer] to simulate what a real
// transport's discovery would report.
//
// Port intent of src/features/messaging/api/transport.ts's MeshTransport
// class, minus the native expo-nearby-connections calls: this is the fake
// half of the adapter pair described there. The real BLE/Nearby-equivalent
// transport is native platform work that lands separately and must also
// implement the [MeshTransport] contract in types.dart.
import 'dart:async';

import '../../utils/relay.dart';
import 'types.dart';

class MockTransport implements MeshTransport {
  @override
  void Function(PeerInfo peer, PeerLinkState state)? onPeer;

  @override
  void Function(Envelope envelope, String fromPeerId)? onEnvelope;

  @override
  void Function(String message)? onError;

  final Set<String> _connectedPeerIds = {};
  bool _running = false;

  /// Every part actually put "on the air" by [broadcast], in order — a whole
  /// envelope counts as one part. Lets tests assert on the chunking that a
  /// real transport is responsible for (see [chunkEnvelope]) without a wire
  /// to inspect.
  final List<Envelope> sentParts = [];

  @override
  Future<TransportStartResult> start() async {
    _running = true;
    return const TransportStartResult.ok();
  }

  @override
  Future<void> stop() async {
    _connectedPeerIds.clear();
    _running = false;
  }

  @override
  Future<int> broadcast(Envelope envelope, {String? excludePeer}) async {
    if (!_running) return 0;
    // Real work a native transport would also do: split an oversized body
    // into parts before it goes over the air. There is no wire here to send
    // them on, so this only has to account for them.
    sentParts.addAll(chunkEnvelope(envelope));
    return _connectedPeerIds.where((id) => id != excludePeer).length;
  }

  /// Test hook: a real transport reports a peer when its own discovery finds
  /// one. This one has to be told.
  void connectPeer(PeerInfo peer) {
    if (!_running) return;
    _connectedPeerIds.add(peer.peerId);
    onPeer?.call(peer, PeerLinkState.connected);
  }

  /// Test hook: the counterpart to [connectPeer].
  void disconnectPeer(PeerInfo peer) {
    _connectedPeerIds.remove(peer.peerId);
    onPeer?.call(peer, PeerLinkState.lost);
  }
}
