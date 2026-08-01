// Real mesh transport — ported from src/features/messaging/api/transport.ts,
// backed by NearbyTransportPlugin.kt (a direct wrapper over Google's real
// com.google.android.gms.nearby.connection API, the same one RN's
// expo-nearby-connections uses). This is the one file in the Flutter app that
// actually talks to another phone.
//
// Interop contract, must match RN exactly (see transport.ts):
//   - serviceId "com.echo.app" (RN's Android application id, not this app's
//     own applicationId — Nearby just needs both sides' serviceId to match).
//   - Strategy.P2P_CLUSTER.
//   - Advertised name packed as "<deviceId>~<display>".
//   - Every connection is auto-accepted on both sides (done natively, see the
//     Kotlin plugin) — trust lives in the app-layer contacts list, not here.
//   - One Payload.fromBytes(utf8 json) per envelope (or per chunk), per peer.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../utils/relay.dart';

const serviceId = 'com.echo.app';

const _methodChannel = MethodChannel('echo.mesh/nearby');
const _eventChannel = EventChannel('echo.mesh/nearby_events');

class PeerInfo {
  final String peerId;
  final String deviceId;
  final String display;
  const PeerInfo({required this.peerId, required this.deviceId, required this.display});
}

typedef ParsedName = ({String deviceId, String display});

String packName(String deviceId, String display) => '$deviceId~$display';

ParsedName unpackName(String raw) {
  final i = raw.indexOf('~');
  if (i < 0) return (deviceId: raw, display: raw);
  return (deviceId: raw.substring(0, i), display: raw.substring(i + 1));
}

typedef OnPeer = void Function(PeerInfo peer, String state); // 'found' | 'connected' | 'lost'
typedef OnEnvelope = void Function(Envelope envelope, String fromPeerId);
typedef OnError = void Function(String message);

class TransportEvents {
  final OnPeer onPeer;
  final OnEnvelope onEnvelope;
  final OnError onError;
  const TransportEvents({required this.onPeer, required this.onEnvelope, required this.onError});
}

typedef StartResult = ({bool ok, String? reason});

class MeshTransport {
  final ParsedName me;
  final TransportEvents events;

  /// Names resolved from either discovery ('found') or an inbound invitation
  /// ('invited' — the only callback that fires on the advertiser side, which
  /// never gets an EndpointDiscoveryCallback of its own for who connected to
  /// it). `connectedPeers` is a separate set: knowing a name isn't the same
  /// as being connected.
  final Map<String, PeerInfo> _known = {};
  final Set<String> _connectedIds = {};
  StreamSubscription? _sub;

  MeshTransport(this.me, this.events);

  List<PeerInfo> get connectedPeers =>
      _connectedIds.map((id) => _known[id]).whereType<PeerInfo>().toList();

  Future<StartResult> start() async {
    try {
      await _methodChannel.invokeMethod('stopAdvertising');
    } catch (_) {}
    try {
      await _methodChannel.invokeMethod('stopDiscovery');
    } catch (_) {}

    try {
      final available = await _methodChannel.invokeMethod<bool>('isAvailable') ?? false;
      if (!available) return (ok: false, reason: 'Google Play Services is not available on this device.');

      final granted = await _methodChannel.invokeMethod<bool>('requestPermissions') ?? false;
      if (!granted) return (ok: false, reason: 'Bluetooth/location permission was not granted.');

      await _sub?.cancel();
      _sub = _eventChannel.receiveBroadcastStream().listen(_onEvent, onError: (e) => events.onError('$e'));

      final advertised = packName(me.deviceId, me.display);
      await _methodChannel.invokeMethod('startAdvertise', {'name': advertised, 'serviceId': serviceId});
      await _methodChannel.invokeMethod('startDiscovery', {'name': advertised, 'serviceId': serviceId});
      return (ok: true, reason: null);
    } catch (e) {
      await stop();
      return (ok: false, reason: '$e');
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _known.clear();
    _connectedIds.clear();
    try {
      await _methodChannel.invokeMethod('stopAll');
    } catch (_) {}
  }

  /// Splits [envelope]'s body across [chunkChars] if needed, sends each part
  /// to every connected peer (except [excludePeerId], the one that just
  /// handed it to us — never bounce a relay straight back). Returns the
  /// number of peers the *last* part was confirmed delivered to, mirroring
  /// RN's `broadcast()` return value (used to decide `sent` vs `queued`).
  Future<int> broadcast(Envelope envelope, {String? excludePeerId}) async {
    final bodies = splitBody(envelope.body);
    final outgoing = bodies.length == 1
        ? [envelope]
        : List<Envelope>.generate(
            bodies.length,
            (i) => Envelope(
              id: '${envelope.id}#$i',
              from: envelope.from,
              fromName: envelope.fromName,
              to: envelope.to,
              kind: envelope.kind,
              body: bodies[i],
              gid: envelope.gid ?? envelope.id,
              part: PartInfo(i: i, n: bodies.length),
              ttl: envelope.ttl,
              path: envelope.path,
              at: envelope.at,
            ),
          );

    final targets = connectedPeers.where((p) => p.peerId != excludePeerId).toList();
    if (targets.isEmpty) return 0;

    var delivered = 0;
    for (final part in outgoing) {
      final bytes = Uint8List.fromList(utf8.encode(encode(part)));
      final results = await Future.wait(targets.map((p) async {
        try {
          final ok = await _methodChannel.invokeMethod<bool>('sendBytes', {'endpointId': p.peerId, 'bytes': bytes});
          return ok ?? false;
        } catch (_) {
          return false;
        }
      }));
      delivered = results.where((ok) => ok).length;
    }
    return delivered;
  }

  void _onEvent(dynamic raw) {
    if (raw is! Map) return;
    final type = raw['type'];
    final peerId = raw['peerId'] as String?;
    if (peerId == null && type != 'error') return;

    switch (type) {
      case 'found':
      case 'invited':
        final name = raw['name'] as String? ?? '';
        final parsed = unpackName(name);
        if (parsed.deviceId == me.deviceId) return; // our own advertisement echoed back
        final info = PeerInfo(peerId: peerId!, deviceId: parsed.deviceId, display: parsed.display);
        _known[peerId] = info;
        if (type == 'found') {
          events.onPeer(info, 'found');
          // Lower device id wins the race, so only one side ever calls
          // requestConnection — otherwise both sides half-open a connection
          // to each other at once.
          if (me.deviceId.compareTo(parsed.deviceId) < 0) {
            _methodChannel.invokeMethod('requestConnection', {
              'name': packName(me.deviceId, me.display),
              'endpointId': peerId,
            });
          }
        }
        break;

      case 'connected':
        _connectedIds.add(peerId!);
        final info = _known[peerId] ?? PeerInfo(peerId: peerId, deviceId: peerId, display: peerId);
        _known[peerId] = info;
        events.onPeer(info, 'connected');
        break;

      case 'lost':
        _connectedIds.remove(peerId);
        final info = _known.remove(peerId);
        if (info != null) events.onPeer(info, 'lost');
        break;

      case 'payload':
        final bytes = raw['bytes'];
        if (bytes == null) return;
        final text = utf8.decode(List<int>.from(bytes as List));
        final envelope = decode(text);
        if (envelope != null && peerId != null) events.onEnvelope(envelope, peerId);
        break;

      case 'error':
        events.onError(raw['message']?.toString() ?? 'Unknown mesh error');
        break;
    }
  }
}
