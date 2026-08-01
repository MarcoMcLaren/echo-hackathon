// Live mesh state. Owns the transport and applies the relay rules to anything
// that arrives, so screens only ever read plain data.
//
// Port of src/store/mesh.ts. The demo/mock threads are preserved as the seed so
// screens have real content whether or not a transport has been wired in yet —
// see [MeshTransport] in features/messaging/types.dart for the contract a
// native implementation must satisfy.
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../features/messaging/types.dart';
import '../utils/relay.dart';
import 'mock.dart' as mock;

class MeshSelf {
  const MeshSelf({required this.deviceId, required this.display});

  final String deviceId;
  final String display;

  MeshSelf withDisplay(String display) => MeshSelf(deviceId: deviceId, display: display);
}

class MeshPeer {
  const MeshPeer({required this.display, required this.peerId, required this.connected});

  final String display;
  final String peerId;
  final bool connected;

  MeshPeer withConnected(bool connected) =>
      MeshPeer(display: display, peerId: peerId, connected: connected);
}

class MeshStats {
  const MeshStats({this.sent = 0, this.delivered = 0, this.relayed = 0, this.dropped = 0});

  final int sent;
  final int delivered;
  final int relayed;
  final int dropped;

  MeshStats copyWith({int? sent, int? delivered, int? relayed, int? dropped}) => MeshStats(
    sent: sent ?? this.sent,
    delivered: delivered ?? this.delivered,
    relayed: relayed ?? this.relayed,
    dropped: dropped ?? this.dropped,
  );
}

const _fallbackDisplayName = 'Echo phone';

/// Per launch. Persisting it needs storage that isn't wired up yet.
String _randomDeviceId() => _randomBase36(6);

String _randomBase36(int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random();
  return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
}

class MeshStore extends ChangeNotifier {
  MeshStore({MeshTransport? transport, String? deviceId, String? display})
    : _transport = transport,
      me = MeshSelf(
        deviceId: deviceId ?? _randomDeviceId(),
        display: display ?? _fallbackDisplayName,
      );

  final SeenCache _seen = SeenCache();
  final MeshTransport? _transport;

  MeshSelf me;
  MeshStatus status = MeshStatus.off;
  String? error;

  /// deviceId -> what we know about them right now.
  Map<String, MeshPeer> peers = {};
  List<mock.Thread> threads = List.of(mock.threads);

  /// Counts for the demo — proof the relay actually did something.
  MeshStats stats = const MeshStats();

  void setName(String display) {
    me = me.withDisplay(display);
    notifyListeners();
  }

  Future<void> start() async {
    if (status == MeshStatus.live || status == MeshStatus.starting) return;
    status = MeshStatus.starting;
    error = null;
    notifyListeners();

    final transport = _transport;
    if (transport == null) {
      status = MeshStatus.error;
      error = 'No mesh transport is wired up on this build yet.';
      notifyListeners();
      return;
    }

    transport.onPeer = _handlePeer;
    transport.onEnvelope = _handleEnvelope;
    transport.onError = (message) {
      error = message;
      notifyListeners();
    };

    final result = await transport.start();
    if (!result.ok) {
      status = MeshStatus.error;
      error = result.reason;
      notifyListeners();
      return;
    }
    status = MeshStatus.live;
    notifyListeners();
  }

  Future<void> stop() async {
    await _transport?.stop();
    status = MeshStatus.off;
    peers = {};
    notifyListeners();
  }

  Future<void> send(String threadId, String body, {EnvelopeKind kind = EnvelopeKind.msg}) async {
    final envelope = newEnvelope(
      id: '${me.deviceId}-${DateTime.now().millisecondsSinceEpoch}-${_randomBase36(4)}',
      from: me.deviceId,
      to: threadId,
      kind: kind,
      body: body,
      at: DateTime.now().millisecondsSinceEpoch,
    );
    _seen.check(envelope.id); // never relay our own message back to ourselves

    final reachable = peers[threadId]?.connected ?? false;
    final transport = _transport;
    final fanout = transport != null ? await transport.broadcast(envelope) : 0;

    stats = stats.copyWith(sent: stats.sent + 1);
    threads = _upsertMessage(
      threads,
      threadId,
      mock.Msg(
        id: envelope.id,
        from: 'me',
        text: kind == EnvelopeKind.msg ? body : null,
        coin: kind == EnvelopeKind.coin ? double.tryParse(body) : null,
        at: _clock(envelope.at),
        hops: reachable ? 0 : (fanout > 0 ? 1 : null),
        // No peer at all means it waits — never show it as sent.
        state: fanout == 0
            ? mock.MsgState.queued
            : (reachable ? mock.MsgState.delivered : mock.MsgState.sent),
      ),
    );
    notifyListeners();
  }

  void _handlePeer(PeerInfo peer, PeerLinkState state) {
    final nextPeers = Map<String, MeshPeer>.from(peers);
    if (state == PeerLinkState.lost) {
      final existing = nextPeers[peer.deviceId];
      if (existing != null) nextPeers[peer.deviceId] = existing.withConnected(false);
    } else {
      nextPeers[peer.deviceId] = MeshPeer(
        display: peer.display,
        peerId: peer.peerId,
        connected: state == PeerLinkState.connected,
      );
    }

    // A phone you can reach has to be a phone you can open a chat with, or the
    // mesh is live and there is nothing to do with it.
    var nextThreads = threads;
    final hasThread = threads.any((t) => t.id == peer.deviceId);
    if (state == PeerLinkState.connected && !hasThread) {
      nextThreads = [
        mock.Thread(
          id: peer.deviceId,
          title: peer.display,
          initials: _initialsOf(peer.display),
          preview: 'Connected over the mesh',
          at: 'now',
          hops: 0,
          messages: const [],
        ),
        ...threads,
      ];
    } else if (hasThread) {
      nextThreads = [
        for (final t in threads)
          t.id == peer.deviceId
              ? mock.Thread(
                  id: t.id,
                  title: t.title,
                  initials: t.initials,
                  group: t.group,
                  members: t.members,
                  preview: t.preview,
                  at: t.at,
                  hops: state == PeerLinkState.connected ? 0 : null,
                  via: t.via,
                  messages: t.messages,
                )
              : t,
      ];
    }

    peers = nextPeers;
    threads = nextThreads;
    notifyListeners();
  }

  void _handleEnvelope(Envelope envelope, String fromPeerId) {
    final decision = route(envelope, me.deviceId, _seen, fromPeer: fromPeerId);

    switch (decision) {
      case DropDecision():
        stats = stats.copyWith(dropped: stats.dropped + 1);
        notifyListeners();
      case RelayDecision(:final envelope, :final excludePeer):
        stats = stats.copyWith(relayed: stats.relayed + 1);
        notifyListeners();
        _transport?.broadcast(envelope, excludePeer: excludePeer);
      case DeliverDecision(:final envelope):
        final hops = hopsTaken(envelope);
        final relay = relayedBy(envelope);
        stats = stats.copyWith(delivered: stats.delivered + 1);
        threads = _upsertMessage(
          threads,
          envelope.from,
          mock.Msg(
            id: envelope.id,
            from: envelope.from,
            text: envelope.kind == EnvelopeKind.msg ? envelope.body : null,
            coin: envelope.kind == EnvelopeKind.coin ? double.tryParse(envelope.body) : null,
            at: _clock(envelope.at),
            hops: hops,
            via: relay != null ? _displayOf(relay) : null,
          ),
        );
        notifyListeners();
    }
  }

  String _displayOf(String id) {
    final peer = peers[id];
    if (peer != null) return peer.display;
    for (final t in mock.threads) {
      if (t.id == id) return t.title;
    }
    return id;
  }
}

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'[\s-]+')).where((p) => p.isNotEmpty).toList();
  final letters = parts.length > 1
      ? '${parts[0][0]}${parts[1][0]}'
      : name.substring(0, min(2, name.length));
  return letters.toUpperCase();
}

String _clock(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// Append to a thread, creating one for a sender we've never heard from.
List<mock.Thread> _upsertMessage(List<mock.Thread> threads, String threadId, mock.Msg msg) {
  final preview = msg.text ?? '${msg.coin?.toStringAsFixed(2)} echocoin';
  final i = threads.indexWhere((t) => t.id == threadId);
  if (i < 0) {
    return [
      mock.Thread(
        id: threadId,
        title: threadId,
        initials: threadId.substring(0, min(2, threadId.length)).toUpperCase(),
        preview: preview,
        at: msg.at,
        hops: msg.hops,
        via: msg.via,
        messages: [msg],
      ),
      ...threads,
    ];
  }
  final t = threads[i];
  final next = [...threads];
  next[i] = mock.Thread(
    id: t.id,
    title: t.title,
    initials: t.initials,
    group: t.group,
    members: t.members,
    preview: preview,
    at: msg.at,
    hops: msg.hops,
    via: msg.via,
    messages: [...t.messages, msg],
  );
  return next;
}
