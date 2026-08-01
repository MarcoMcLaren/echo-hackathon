// Real mesh transport over Google Nearby Connections (Android, BLE + Wi-Fi).
//
// Port intent of src/features/messaging/api/transport.ts's MeshTransport:
// P2P_CLUSTER strategy (advertise + discover simultaneously so everyone in
// one room can reach everyone else), identity packed into the advertised
// display name, the lower-device-id-initiates tie-break, and chunking an
// oversized body via utils/relay.dart's chunkEnvelope before it goes over the
// wire. Nearby gives us P2P *clustering*, not multi-hop relay past radio
// range — that stays MeshStore's job, same as upstream.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:nearby_connections/nearby_connections.dart';

import '../../utils/relay.dart';
import 'nearby_permissions.dart';
import 'types.dart';

const String _serviceId = 'com.echo.hackathon.mesh';

/// Nearby only carries a display name, so identity rides along inside it —
/// same trick as the RN transport.
String _packName(String deviceId, String display) => '$deviceId~$display';

({String deviceId, String display}) _unpackName(String raw) {
  final i = raw.indexOf('~');
  if (i < 0) return (deviceId: raw, display: raw);
  return (deviceId: raw.substring(0, i), display: raw.substring(i + 1));
}

/// Nearby surfaces failures as a bare exception with a status code baked
/// into the message; showing that to someone mid-demo tells them nothing.
String _explain(Object e) {
  final text = e.toString();
  if (text.contains('MISSING_PERMISSION')) {
    return 'Echo needs Bluetooth and location permission to find phones.';
  }
  if (text.contains('8001')) {
    return 'Mesh was started twice. Stop it and start again.';
  }
  if (text.contains('8002') || text.contains('8003') || text.contains('8004')) {
    return 'The radio was still busy from the last session. Try again.';
  }
  if (text.contains('8007') || text.contains('8020')) {
    return 'Turn Bluetooth off and on again, then retry.';
  }
  return 'Could not start the mesh. Check Bluetooth is on.';
}

/// [deviceId] and [display] are read lazily — once, at [start] — rather than
/// passed in at construction: this transport is built (see main.dart) before
/// MeshStore resolves its persisted identity, and it must advertise the
/// exact id MeshStore will later check incoming envelopes' `to` field
/// against, or direct messages addressed to us never match and get relayed
/// past us instead of delivered.
class NearbyTransport implements MeshTransport {
  NearbyTransport({required this._deviceId, required this._display});

  final String Function() _deviceId;
  final String Function() _display;

  @override
  void Function(PeerInfo peer, PeerLinkState state)? onPeer;

  @override
  void Function(Envelope envelope, String fromPeerId)? onEnvelope;

  @override
  void Function(String message)? onError;

  final Nearby _nearby = Nearby();

  /// endpointId -> peer, once onConnectionInitiated has told us who they are
  /// but before Nearby confirms the two-way handshake.
  final Map<String, PeerInfo> _pending = {};

  /// endpointId -> peer, confirmed connected. What [broadcast] fans out to.
  final Map<String, PeerInfo> _peers = {};

  bool _running = false;

  @override
  Future<TransportStartResult> start() async {
    if (_running) return const TransportStartResult.ok();

    debugPrint('[mesh-debug] transport.start: requesting permissions');
    final perm = await ensureNearbyPermissions();
    debugPrint('[mesh-debug] transport.start: permissions ok=${perm.ok} missing=${perm.missing}');
    if (!perm.ok) {
      return const TransportStartResult.failure(
        'Echo needs Bluetooth and location permission to find phones.',
      );
    }

    final myDeviceId = _deviceId();
    final advertised = _packName(myDeviceId, _display());

    // A previous session (or a hot reload that reset our Dart state) can
    // leave the radio still advertising, which makes the next start fail.
    // Clear it first, same as upstream.
    debugPrint('[mesh-debug] transport.start: stopping stale radio');
    await _stopRadio();
    debugPrint('[mesh-debug] transport.start: radio clear, advertising as $advertised');

    try {
      await _nearby.startAdvertising(
        advertised,
        Strategy.P2P_CLUSTER,
        serviceId: _serviceId,
        onConnectionInitiated: (id, info) => _onConnectionInitiated(id, info, myDeviceId),
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      debugPrint('[mesh-debug] transport.start: advertising up, starting discovery');
      await _nearby.startDiscovery(
        advertised,
        Strategy.P2P_CLUSTER,
        serviceId: _serviceId,
        onEndpointFound: (id, name, foundServiceId) => _onEndpointFound(id, name, myDeviceId, advertised),
        onEndpointLost: _onEndpointLost,
      );
    } catch (e) {
      debugPrint('[mesh-debug] transport.start: FAILED: $e');
      await stop();
      return TransportStartResult.failure(_explain(e));
    }

    debugPrint('[mesh-debug] transport.start: live');
    _running = true;
    return const TransportStartResult.ok();
  }

  void _onEndpointFound(String endpointId, String name, String myDeviceId, String myAdvertisedName) {
    final peer = _unpackName(name);
    // Some devices report their own advertisement back. Never treat that as
    // a peer, or we appear in our own mesh.
    if (peer.deviceId == myDeviceId) return;

    // Both sides discover each other; the lower device id initiates so we
    // don't race into two half-open connections.
    if (myDeviceId.compareTo(peer.deviceId) < 0) {
      unawaited(
        _nearby
            .requestConnection(
              myAdvertisedName,
              endpointId,
              onConnectionInitiated: (id, info) => _onConnectionInitiated(id, info, myDeviceId),
              onConnectionResult: _onConnectionResult,
              onDisconnected: _onDisconnected,
            )
            .catchError((_) => false), // the other side may have got there first
      );
    }
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId == null) return;
    _pending.remove(endpointId);
    final peer = _peers.remove(endpointId);
    if (peer != null) onPeer?.call(peer, PeerLinkState.lost);
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info, String myDeviceId) {
    final peer = _unpackName(info.endpointName);
    if (peer.deviceId == myDeviceId) {
      unawaited(_nearby.rejectConnection(endpointId).catchError((_) => false));
      return;
    }

    _pending[endpointId] = PeerInfo(peerId: endpointId, deviceId: peer.deviceId, display: peer.display);

    // Accept everyone. A phone we have never met is still a node that can
    // carry traffic, and the mesh is stronger for having it.
    unawaited(
      _nearby.acceptConnection(endpointId, onPayLoadRecieved: _onPayloadReceived).catchError((e) {
        onError?.call(_explain(e));
        return false;
      }),
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    final peer = _pending.remove(endpointId);
    if (status == Status.CONNECTED && peer != null) {
      _peers[endpointId] = peer;
      onPeer?.call(peer, PeerLinkState.connected);
    }
  }

  void _onDisconnected(String endpointId) {
    _pending.remove(endpointId);
    final peer = _peers.remove(endpointId);
    if (peer != null) onPeer?.call(peer, PeerLinkState.lost);
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type != PayloadType.BYTES) return;
    final bytes = payload.bytes;
    if (bytes == null) return;
    final envelope = decode(utf8.decode(bytes));
    // A malformed payload from another build is a peer problem, not ours —
    // drop it quietly.
    if (envelope != null) onEnvelope?.call(envelope, endpointId);
  }

  /// Sends to every connected peer except [excludePeer]. Nearby's BYTES
  /// payload is capped at 32 KiB, so [chunkEnvelope] splits anything bigger
  /// into parts first — each a normal envelope with its own id, so a relay
  /// forwards them without needing to know they belong together.
  @override
  Future<int> broadcast(Envelope envelope, {String? excludePeer}) async {
    if (!_running) return 0;

    final targets = _peers.values.where((p) => p.peerId != excludePeer).toList();
    if (targets.isEmpty) return 0;

    var delivered = 0;
    for (final part in chunkEnvelope(envelope)) {
      final bytes = Uint8List.fromList(utf8.encode(encode(part)));
      final results = await Future.wait(targets.map((p) => _sendBytes(p.peerId, bytes)));
      // Count peers reached, not parts sent.
      final reached = results.where((ok) => ok).length;
      if (reached > delivered) delivered = reached;
    }
    return delivered;
  }

  Future<bool> _sendBytes(String endpointId, Uint8List bytes) async {
    try {
      await _nearby.sendBytesPayload(endpointId, bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    _pending.clear();
    _peers.clear();
    _running = false;
    await _stopRadio();
  }

  /// Never lets a radio-teardown failure escape — there is nothing useful to
  /// do with it, and an unawaited throw from here (e.g. during a widget's
  /// synchronous dispose) would crash whatever called us.
  Future<void> _stopRadio() async {
    await Future.wait([
      _nearby.stopAdvertising().catchError((_) {}),
      _nearby.stopDiscovery().catchError((_) {}),
      _nearby.stopAllEndpoints().catchError((_) {}),
    ]);
  }
}
