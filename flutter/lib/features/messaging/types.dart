// Types for peers, mesh status, and the pluggable transport that MeshStore
// drives. The concrete transport (BLE/Nearby-equivalent) is native platform
// work owned elsewhere — this is the contract it implements.
//
// Port of src/features/messaging/types/index.ts (empty in the source) plus the
// PeerInfo/TransportEvents shapes src/store/mesh.ts relies on from
// src/features/messaging/api/transport.ts.
import '../../utils/relay.dart';

class PeerInfo {
  const PeerInfo({required this.peerId, required this.deviceId, required this.display});

  final String peerId;
  final String deviceId;
  final String display;
}

enum PeerLinkState { found, connected, lost }

enum MeshStatus { off, starting, live, error }

class TransportStartResult {
  const TransportStartResult.ok() : ok = true, reason = null;

  const TransportStartResult.failure(String this.reason) : ok = false;

  final bool ok;
  final String? reason;
}

/// Contract a native mesh transport must satisfy for [MeshStore] to drive it.
/// `onPeer`/`onEnvelope`/`onError` are assigned by the store before [start] is
/// called.
abstract class MeshTransport {
  void Function(PeerInfo peer, PeerLinkState state)? onPeer;
  void Function(Envelope envelope, String fromPeerId)? onEnvelope;
  void Function(String message)? onError;

  Future<TransportStartResult> start();
  Future<void> stop();

  /// Returns the number of peers it was actually sent to (fanout).
  Future<int> broadcast(Envelope envelope, {String? excludePeer});
}
