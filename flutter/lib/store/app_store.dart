// Live app state — ported from src/store/mesh.ts, minus the transport.
// There is no Flutter equivalent of expo-nearby-connections, so this store
// only ever operates the way RN's own store behaves on a solo device with no
// peers: sends land locally as 'queued', nothing gets relayed. start()/stop()
// simulate the off -> starting -> live status transition RN shows, since
// there's nothing real to start without a transport.
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../features/notify.dart';
import '../models/mock.dart' as mock;
import '../utils/identity.dart';
import '../utils/relay.dart';

enum MeshStatus { off, starting, live }

/// Long enough to catch a mistake, short enough not to feel broken.
const cancelWindow = Duration(seconds: 5);

/// A coin send held in its cancel window. One at a time, deliberately.
class PendingCoin {
  final String msgId;
  final String threadId;
  final double amount;
  final DateTime until;
  const PendingCoin({required this.msgId, required this.threadId, required this.amount, required this.until});
}

class Stats {
  final int sent;
  final int delivered;
  final int relayed;
  final int dropped;
  const Stats({this.sent = 0, this.delivered = 0, this.relayed = 0, this.dropped = 0});

  Stats copyWith({int? sent, int? delivered, int? relayed, int? dropped}) => Stats(
        sent: sent ?? this.sent,
        delivered: delivered ?? this.delivered,
        relayed: relayed ?? this.relayed,
        dropped: dropped ?? this.dropped,
      );
}

class AppStore extends ChangeNotifier {
  /// Replaced with the persisted identity the first time the mesh starts,
  /// mirroring store/mesh.ts. Message authorship in the UI always uses the
  /// literal 'me', so this only matters for envelope routing.
  String deviceId = 'me';
  MeshStatus status = MeshStatus.off;
  Stats stats = const Stats();
  PendingCoin? pending;
  final SeenCache _seen = SeenCache();
  int _counter = 0;
  Timer? _cancelTimer;

  final List<mock.Thread> threads = mock.seedThreads();

  mock.Thread? threadById(String id) {
    for (final t in threads) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> start() async {
    if (status == MeshStatus.live || status == MeshStatus.starting) return;
    status = MeshStatus.starting;
    notifyListeners();
    // Stable across restarts, so the phone you spoke to earlier is still the
    // same phone and doesn't come back as a stranger.
    deviceId = await deviceIdentity();
    // Asked for here rather than at launch: the permission makes sense to
    // someone who has just turned the mesh on, and nowhere else.
    unawaited(prepareNotifications());
    await Future.delayed(const Duration(milliseconds: 700));
    status = MeshStatus.live;
    notifyListeners();
  }

  void stop() {
    status = MeshStatus.off;
    notifyListeners();
  }

  /// Held from the moment the screen opened. Clearing the badge immediately
  /// would also remove the offer to summarise what hasn't been read yet — the
  /// caller (ChatScreen) is expected to snapshot `unread` before calling this.
  void markRead(String threadId) {
    final thread = threadById(threadId);
    if (thread == null || thread.unread == 0) return;
    thread.unread = 0;
    notifyListeners();
  }

  /// Ports store/mesh.ts's send(): append to the thread immediately, and
  /// since there's no transport, it always lands as 'queued' — no peer is
  /// ever actually connected on a solo Flutter device.
  void send(String threadId, String body, {String kind = 'msg'}) {
    final envelope = newEnvelope(
      id: '$deviceId-${_counter++}',
      from: deviceId,
      to: threadId,
      kind: kind,
      body: body,
      at: 0,
    );
    _seen.check(envelope.id); // never relay our own message back to ourselves

    // A revert is bookkeeping on an existing message, not a new one in the
    // thread — revertLastCoin has already struck the original through.
    if (kind == 'revert') {
      stats = stats.copyWith(sent: stats.sent + 1);
      notifyListeners();
      return;
    }

    final thread = threadById(threadId);
    final msg = mock.Msg(
      id: envelope.id,
      from: 'me',
      text: kind == 'msg' ? body : null,
      coin: kind == 'coin' ? double.tryParse(body) : null,
      at: _clock(),
      hops: null,
      state: 'queued',
    );

    if (thread != null) {
      thread.messages.add(msg);
      thread.preview = msg.text ?? '${msg.coin?.toStringAsFixed(2)} echocoin';
      thread.at = msg.at;
    }

    stats = stats.copyWith(sent: stats.sent + 1);
    notifyListeners();
  }

  /// Show it in the thread, but hold it back for [cancelWindow] first.
  void queueCoin(String threadId, double amount) {
    // One at a time: a queue of pending payments is a queue of things you
    // can't cancel individually under pressure.
    cancelPending();

    final msgId = '$deviceId-${_counter++}-p';
    pending = PendingCoin(msgId: msgId, threadId: threadId, amount: amount, until: DateTime.now().add(cancelWindow));

    final thread = threadById(threadId);
    thread?.messages.add(mock.Msg(id: msgId, from: 'me', coin: amount, at: _clock(), hops: null, pending: true));
    notifyListeners();

    _cancelTimer = Timer(cancelWindow, () {
      final held = pending;
      if (held == null || held.msgId != msgId) return;
      // Drop the placeholder, then send for real.
      final t = threadById(threadId);
      t?.messages.removeWhere((m) => m.id == msgId);
      pending = null;
      send(threadId, amount.toString(), kind: 'coin');
    });
  }

  void cancelPending() {
    _cancelTimer?.cancel();
    _cancelTimer = null;
    final held = pending;
    if (held == null) return;
    final t = threadById(held.threadId);
    t?.messages.removeWhere((m) => m.id == held.msgId);
    pending = null;
    notifyListeners();
  }

  /// Take back the most recent coin already sent in this thread.
  bool revertLastCoin(String threadId) {
    final thread = threadById(threadId);
    if (thread == null) return false;

    var targetIndex = -1;
    for (var i = thread.messages.length - 1; i >= 0; i--) {
      final m = thread.messages[i];
      if (m.from == 'me' && m.coin != null && !m.reverted && !m.pending) {
        targetIndex = i;
        break;
      }
    }
    if (targetIndex < 0) return false;

    // Mark it here first so the gesture feels immediate; the peer honours the
    // revert when the message reaches them, or when a route opens.
    final target = thread.messages[targetIndex];
    thread.messages[targetIndex] = target.copyWith(reverted: true);
    notifyListeners();

    send(threadId, target.id, kind: 'revert');
    return true;
  }

  static const _demoTexts = {
    'braai': 'Someone else is bringing chairs too',
    'thabo': 'On my way now',
    'naledi': 'Nearly there, hang tight',
    'sipho': 'Finally got signal back',
  };

  /// Stand-in for a real transport: there is no expo-nearby-connections
  /// equivalent here, so nothing ever actually arrives from another phone.
  /// This simulates one arriving message so the local-notification plumbing
  /// in notify.dart is actually exercised and visible, rather than being
  /// wired up with nothing to trigger it.
  ///
  /// Delayed on purpose: notifyMessage() suppresses the notification while
  /// the app is foregrounded (correctly — you're already looking at the
  /// thread), so an instantaneous demo could never show a real banner. The
  /// delay gives whoever triggered this a moment to background the app
  /// first, the same way a message actually arriving while you're elsewhere
  /// would.
  static const demoArrivalDelay = Duration(seconds: 4);

  void receiveDemoMessage(String threadId) {
    final thread = threadById(threadId);
    if (thread == null) return;

    Timer(demoArrivalDelay, () {
      final t = threadById(threadId);
      if (t == null) return;

      final sender = t.group ? (t.members?.firstWhere((m) => m != 'me', orElse: () => threadId) ?? threadId) : threadId;
      final text = _demoTexts[threadId] ?? 'New message just arrived';
      final senderName = mock.byId(sender)?.name ?? sender;

      final msg = mock.Msg(id: '$deviceId-${_counter++}-demo', from: sender, text: text, at: _clock(), hops: t.hops, via: t.via);
      t.messages.add(msg);
      t.preview = t.group ? '$senderName: $text' : text;
      t.at = msg.at;
      t.unread += 1;
      notifyListeners();

      notifyMessage(from: senderName, body: text, threadId: threadId, hops: t.hops);
    });
  }

  @override
  void dispose() {
    _cancelTimer?.cancel();
    super.dispose();
  }

  String _clock() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}';
  }
}
