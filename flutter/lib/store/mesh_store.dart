// Live mesh state. Owns the transport and applies the relay rules to anything
// that arrives, so screens only ever read plain data.
//
// Port of src/store/mesh.ts. The demo/mock threads are preserved as the seed so
// screens have real content whether or not a transport has been wired in yet —
// see [MeshTransport] in features/messaging/types.dart for the contract a
// native implementation must satisfy.
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../features/messaging/notifier.dart';
import '../features/messaging/types.dart';
import '../utils/relay.dart';
import 'mock.dart' as mock;

class MeshSelf {
  const MeshSelf({required this.deviceId, required this.display});

  final String deviceId;
  final String display;

  MeshSelf withDisplay(String display) =>
      MeshSelf(deviceId: deviceId, display: display);
}

/// Only phones reachable right now. A peer that goes away is removed from
/// [MeshStore.peers] rather than kept as a disconnected entry — a ghost node
/// on the map that will never reconnect reads as a bug, and it makes the peer
/// count disagree with the conversation list.
class MeshPeer {
  const MeshPeer({required this.display, required this.peerId});

  final String display;
  final String peerId;
}

class MeshStats {
  const MeshStats({
    this.sent = 0,
    this.delivered = 0,
    this.relayed = 0,
    this.dropped = 0,
  });

  final int sent;
  final int delivered;
  final int relayed;
  final int dropped;

  MeshStats copyWith({int? sent, int? delivered, int? relayed, int? dropped}) =>
      MeshStats(
        sent: sent ?? this.sent,
        delivered: delivered ?? this.delivered,
        relayed: relayed ?? this.relayed,
        dropped: dropped ?? this.dropped,
      );
}

/// A coin send held in its cancel window. One at a time, deliberately.
class PendingCoin {
  const PendingCoin({
    required this.msgId,
    required this.threadId,
    required this.amount,
    required this.until,
  });

  final String msgId;
  final String threadId;
  final double amount;

  /// millisecondsSinceEpoch the hold expires at.
  final int until;
}

/// Under this many unread, you can just read them yourself.
const int summaryThreshold = 5;

/// Long enough to catch a mistake, short enough not to feel broken.
const int cancelWindowMs = 5000;

const _fallbackDisplayName = 'Echo phone';

/// Per launch. Persisting it needs storage that isn't wired up yet.
String _randomDeviceId() => _randomBase36(6);

String _randomBase36(int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random();
  return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
}

class MeshStore extends ChangeNotifier {
  MeshStore({
    this._transport,
    MeshNotifier? notifier,
    String? deviceId,
    String? display,
  }) : _notifier = notifier ?? MockMeshNotifier(),
       me = MeshSelf(
         deviceId: deviceId ?? _randomDeviceId(),
         display: display ?? _fallbackDisplayName,
       );

  final SeenCache _seen = SeenCache();
  final Reassembler _inbound = Reassembler();
  final MeshTransport? _transport;
  final MeshNotifier _notifier;
  Timer? _cancelTimer;

  MeshSelf me;
  MeshStatus status = MeshStatus.off;
  String? error;

  /// deviceId -> what we know about them right now.
  Map<String, MeshPeer> peers = {};
  List<mock.Thread> threads = List.of(mock.threads);

  /// Counts for the demo — proof the relay actually did something.
  MeshStats stats = const MeshStats();

  PendingCoin? pending;

  void setName(String display) {
    me = me.withDisplay(display);
    notifyListeners();
  }

  void markRead(String threadId) {
    threads = [
      for (final t in threads) t.id == threadId ? _withUnread(t, 0) : t,
    ];
    notifyListeners();
  }

  Future<void> start() async {
    if (status == MeshStatus.live || status == MeshStatus.starting) return;
    status = MeshStatus.starting;
    error = null;
    notifyListeners();

    // Asked for here rather than at launch: the permission makes sense to
    // someone who has just turned the mesh on, and nowhere else.
    unawaited(_notifier.prepare());

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
    // Peers are session state. Conversations stay, but nothing has a route.
    final oldPeers = peers;
    status = MeshStatus.off;
    error = null;
    peers = {};
    threads = [
      for (final t in threads)
        oldPeers.containsKey(t.id) ? _withHops(t, null) : t,
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelTimer?.cancel();
    _transport?.stop();
    super.dispose();
  }

  Future<void> send(
    String threadId,
    String body, {
    EnvelopeKind kind = EnvelopeKind.msg,
  }) async {
    final envelope = newEnvelope(
      id: '${me.deviceId}-${DateTime.now().millisecondsSinceEpoch}-${_randomBase36(4)}',
      from: me.deviceId,
      to: threadId,
      kind: kind,
      body: body,
      at: DateTime.now().millisecondsSinceEpoch,
    );
    _seen.check(envelope.id); // never relay our own message back to ourselves

    final reachable = peers.containsKey(threadId);
    final transport = _transport;
    final fanout = transport != null ? await transport.broadcast(envelope) : 0;

    // A revert is bookkeeping on an existing message, not a new one in the
    // thread — revertLastCoin has already struck the original through.
    if (kind == EnvelopeKind.revert) {
      stats = stats.copyWith(sent: stats.sent + 1);
      notifyListeners();
      return;
    }

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

  /// Show it in the thread, but hold it back for [cancelWindowMs] first.
  void queueCoin(String threadId, double amount) {
    // One at a time: a queue of pending payments is a queue of things you
    // can't cancel individually under pressure.
    cancelPending();

    final now = DateTime.now().millisecondsSinceEpoch;
    // The random suffix (as in send()'s envelope ids) keeps two holds queued
    // in quick succession from colliding on the same millisecond.
    final msgId = '${me.deviceId}-$now-${_randomBase36(4)}-p';
    pending = PendingCoin(
      msgId: msgId,
      threadId: threadId,
      amount: amount,
      until: now + cancelWindowMs,
    );
    threads = _upsertMessage(
      threads,
      threadId,
      mock.Msg(
        id: msgId,
        from: 'me',
        coin: amount,
        at: _clock(now),
        hops: peers.containsKey(threadId) ? 0 : null,
        pending: true,
      ),
    );
    notifyListeners();

    _cancelTimer = Timer(const Duration(milliseconds: cancelWindowMs), () {
      final held = pending;
      if (held == null || held.msgId != msgId) return;
      // Drop the placeholder, then send for real.
      pending = null;
      threads = [
        for (final t in threads)
          t.id == threadId
              ? _withMessages(
                  t,
                  t.messages.where((m) => m.id != msgId).toList(),
                )
              : t,
      ];
      notifyListeners();
      send(threadId, amount.toString(), kind: EnvelopeKind.coin);
    });
  }

  void cancelPending() {
    _cancelTimer?.cancel();
    _cancelTimer = null;
    final held = pending;
    if (held == null) return;
    pending = null;
    threads = [
      for (final t in threads)
        t.id == held.threadId
            ? _withMessages(
                t,
                t.messages.where((m) => m.id != held.msgId).toList(),
              )
            : t,
    ];
    notifyListeners();
  }

  /// Take back the most recent coin already sent in this thread.
  Future<bool> revertLastCoin(String threadId) async {
    final idx = threads.indexWhere((t) => t.id == threadId);
    if (idx < 0) return false;

    mock.Msg? target;
    for (final m in threads[idx].messages.reversed) {
      if (m.from == 'me' && m.coin != null && !m.reverted && !m.pending) {
        target = m;
        break;
      }
    }
    if (target == null) return false;

    // Mark it here first so the gesture feels immediate; the peer honours the
    // revert when the message reaches them, or when a route opens.
    threads = [
      for (final t in threads)
        t.id == threadId
            ? _withMessages(t, [
                for (final m in t.messages)
                  m.id == target.id ? m.withReverted(true) : m,
              ])
            : t,
    ];
    notifyListeners();

    await send(threadId, target.id, kind: EnvelopeKind.revert);
    return true;
  }

  void _handlePeer(PeerInfo peer, PeerLinkState state) {
    final nextPeers = Map<String, MeshPeer>.from(peers);
    if (state == PeerLinkState.lost) {
      nextPeers.remove(peer.deviceId);
    } else if (state == PeerLinkState.connected) {
      nextPeers[peer.deviceId] = MeshPeer(
        display: peer.display,
        peerId: peer.peerId,
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
          unread: 0,
        ),
        ...threads,
      ];
    } else if (hasThread) {
      nextThreads = [
        for (final t in threads)
          t.id == peer.deviceId
              ? _withHops(t, state == PeerLinkState.connected ? 0 : null)
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
        // A split payload only becomes a message once every part has landed;
        // until then there is nothing to show.
        final whole = _inbound.add(envelope);
        if (whole == null) return;
        final e = envelope.copyWith(body: whole);

        final hops = hopsTaken(e);
        final relay = relayedBy(e);

        if (e.kind == EnvelopeKind.msg || e.kind == EnvelopeKind.coin) {
          _notifier.notify(
            NotifyPayload(
              from: peers[e.from]?.display ?? e.from,
              body: e.kind == EnvelopeKind.coin
                  ? 'Sent you ${(double.tryParse(e.body) ?? 0).toStringAsFixed(2)} echocoin'
                  : e.body,
              threadId: e.from,
              hops: hops,
            ),
          );
        }

        // A take-back references an earlier message rather than adding one.
        // The row stays on screen marked reverted — money that quietly
        // disappears is worse than money you can see was returned.
        if (e.kind == EnvelopeKind.revert) {
          stats = stats.copyWith(delivered: stats.delivered + 1);
          threads = [
            for (final t in threads)
              t.id == e.from
                  ? _withMessages(t, [
                      for (final m in t.messages)
                        m.id == e.body ? m.withReverted(true) : m,
                    ])
                  : t,
          ];
          notifyListeners();
          return;
        }

        stats = stats.copyWith(delivered: stats.delivered + 1);
        threads = _upsertMessage(
          threads,
          e.from,
          mock.Msg(
            id: e.id,
            from: e.from,
            text: e.kind == EnvelopeKind.msg ? e.body : null,
            coin: e.kind == EnvelopeKind.coin ? double.tryParse(e.body) : null,
            at: _clock(e.at),
            hops: hops,
            via: relay != null ? _displayOf(relay) : null,
          ),
          unread: true,
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

  mock.Thread _withHops(mock.Thread t, mock.Hops hops) => mock.Thread(
    id: t.id,
    title: t.title,
    initials: t.initials,
    group: t.group,
    members: t.members,
    preview: t.preview,
    at: t.at,
    hops: hops,
    via: t.via,
    messages: t.messages,
    unread: t.unread,
  );

  mock.Thread _withUnread(mock.Thread t, int unread) => mock.Thread(
    id: t.id,
    title: t.title,
    initials: t.initials,
    group: t.group,
    members: t.members,
    preview: t.preview,
    at: t.at,
    hops: t.hops,
    via: t.via,
    messages: t.messages,
    unread: unread,
  );

  mock.Thread _withMessages(mock.Thread t, List<mock.Msg> messages) =>
      mock.Thread(
        id: t.id,
        title: t.title,
        initials: t.initials,
        group: t.group,
        members: t.members,
        preview: t.preview,
        at: t.at,
        hops: t.hops,
        via: t.via,
        messages: messages,
        unread: t.unread,
      );
}

String _initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'[\s-]+'))
      .where((p) => p.isNotEmpty)
      .toList();
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
List<mock.Thread> _upsertMessage(
  List<mock.Thread> threads,
  String threadId,
  mock.Msg msg, {
  bool unread = false,
}) {
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
        unread: unread ? 1 : 0,
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
    unread: t.unread + (unread ? 1 : 0),
  );
  return next;
}
