// Live app state — ported from src/store/mesh.ts, now backed by a real
// transport (see features/messaging/mesh_transport.dart). Two distinctions
// matter throughout this file, straight from RN's `ff3f159`:
//   - `peers` are raw nearby endpoints (carry traffic, never named to the
//     user beyond "NODE") vs `contacts` are people you actually paired with
//     (persisted, the only ones who get a Thread).
//   - Connecting to a peer never creates a conversation by itself. Only
//     `pair()` (from a real QR scan) or an accepted group `invite` does.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../features/messaging/events.dart';
import '../features/messaging/mesh_transport.dart';
import '../features/vault/contacts.dart';
import '../features/vault/identity.dart' as vault;
import '../features/notify.dart';
import '../models/types.dart';
import '../utils/relay.dart';

enum MeshStatus { off, starting, live, error }

/// Long enough to catch a mistake, short enough not to feel broken.
const cancelWindow = Duration(seconds: 5);

/// Every phone starts here — there is no issuer, and pretending otherwise
/// would be dishonest. Ported from RN's `OPENING_BALANCE` (`120ebb0`).
const openingBalance = 100.0;

class PeerEntry {
  final String display;
  final String peerId;
  const PeerEntry({required this.display, required this.peerId});
}

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

/// A pure projection of coin messages already in `threads` — no separate
/// ledger is stored, so it structurally cannot disagree with the thread it
/// came from. Ported from RN's `walletFrom` (`120ebb0`).
class WalletSnapshot {
  final double balance;
  final List<Entry> entries;
  const WalletSnapshot({required this.balance, required this.entries});
}

WalletSnapshot walletFrom(List<Thread> threads) {
  final entries = <Entry>[];
  for (final t in threads) {
    for (final m in t.messages) {
      if (m.coin == null || m.pending) continue;
      final amount = m.from == 'me' ? -m.coin! : m.coin!;
      entries.add(Entry(id: m.id, amount: amount, who: t.title, hops: t.hops, via: t.via, note: m.at, reverted: m.reverted));
    }
  }
  final net = entries.where((e) => !e.reverted).fold<double>(0, (sum, e) => sum + e.amount);
  return WalletSnapshot(balance: openingBalance + net, entries: entries.reversed.toList());
}

class AppStore extends ChangeNotifier {
  /// False until a name has been chosen (SetupScreen). Nothing behind the tab
  /// UI renders until this flips.
  bool ready = false;
  String meId = 'pending';
  String meDisplay = '';

  MeshStatus status = MeshStatus.off;
  String? error;
  Stats stats = const Stats();
  PendingCoin? pending;

  /// Raw nearby endpoints, keyed by deviceId — session-only, cleared on stop().
  final Map<String, PeerEntry> peers = {};

  /// Paired people, keyed by deviceId — persisted. Only these get a Thread.
  Map<String, Contact> contacts = {};

  final List<Thread> threads = [];

  final SeenCache _seen = SeenCache();
  final Reassembler _inbound = Reassembler();
  int _counter = 0;
  Timer? _cancelTimer;
  MeshTransport? _transport;

  Thread? threadById(String id) {
    for (final t in threads) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ---- identity / contacts --------------------------------------------

  /// Fires once at launch, before the mesh is ever started. If a profile
  /// already exists, rebuilds thread stubs from persisted contacts — contacts
  /// survive a restart, message history does not (there is no persisted
  /// message store, only the contact list). Ported from RN's `init()`.
  Future<void> init() async {
    final profile = await vault.loadProfile();
    if (profile == null) {
      ready = false;
      notifyListeners();
      return;
    }
    meId = profile.id;
    meDisplay = profile.name;
    contacts = await loadContacts();

    if (threads.isEmpty) {
      for (final c in contacts.values) {
        threads.add(Thread(
          id: c.id,
          title: c.name,
          initials: initialsOf(c.name),
          preview: 'Paired',
          at: _clock(),
          hops: null,
          messages: [],
        ));
      }
    }

    // TEMP: manual verification of the on-device LLM summary fix. Not for
    // commit — revert before this branch ships.
    if (kDebugMode) {
      threads.add(Thread(
        id: '__debug_summary_test__',
        title: 'Summary Test',
        initials: 'ST',
        preview: 'Debug thread for Catch me up',
        at: _clock(),
        hops: 0,
        unread: 6,
        messages: [
          const Msg(id: 'd1', from: 'stranger', fromName: 'Sam', text: 'Meet at the north gate at 7?', at: '10:01', hops: 0),
          const Msg(id: 'd2', from: 'me', text: 'Works for me, bringing the tent', at: '10:02', hops: 0),
          const Msg(id: 'd3', from: 'stranger', fromName: 'Sam', text: 'Can you grab 20 for the campsite fee, I will pay you back', at: '10:05', hops: 0),
          const Msg(id: 'd4', from: 'me', coin: 20.0, at: '10:06', hops: 0),
          const Msg(id: 'd5', from: 'stranger', fromName: 'Sam', text: 'Got it, thanks. Also did you find the flashlight?', at: '10:10', hops: 0),
          const Msg(id: 'd6', from: 'stranger', fromName: 'Sam', text: 'No rush but let me know before dark', at: '10:12', hops: 0),
        ],
      ));
    }

    ready = true;
    notifyListeners();
  }

  Future<void> createIdentity(String name) async {
    final profile = await vault.createProfile(name);
    meId = profile.id;
    meDisplay = profile.name;
    ready = true;
    notifyListeners();
  }

  Future<void> setName(String display) async {
    final profile = await vault.renameProfile(display);
    if (profile == null) return;
    meDisplay = profile.name;
    notifyListeners();
  }

  /// Stops the mesh, wipes identity/contacts, and resets every in-memory
  /// field back to the pre-setup shape. Next launch mints a brand-new random
  /// id — the phone comes back as a genuinely different phone, not the same
  /// one with its history hidden.
  Future<void> resetApp() async {
    stop();
    vault.resetIdentity();
    ready = false;
    meId = 'pending';
    meDisplay = '';
    contacts = {};
    threads.clear();
    peers.clear();
    stats = const Stats();
    pending = null;
    notifyListeners();
  }

  // ---- mesh lifecycle ----------------------------------------------------

  Future<void> start() async {
    if (status == MeshStatus.live || status == MeshStatus.starting) return;
    status = MeshStatus.starting;
    error = null;
    notifyListeners();

    unawaited(prepareNotifications());

    _transport = MeshTransport(
      (deviceId: meId, display: meDisplay),
      TransportEvents(onPeer: _onPeer, onEnvelope: _onEnvelope, onError: _onTransportError),
    );
    final result = await _transport!.start();
    if (!result.ok) {
      status = MeshStatus.error;
      error = result.reason;
      _transport = null;
      notifyListeners();
      return;
    }

    status = MeshStatus.live;
    notifyListeners();
  }

  void stop() {
    _transport?.stop();
    _transport = null;
    peers.clear();
    for (final t in threads) {
      if (t.hops == 0) t.hops = null;
    }
    status = MeshStatus.off;
    notifyListeners();
  }

  void _onTransportError(String message) {
    error = message;
    notifyListeners();
  }

  /// Connecting to a node just updates `hops` on any *already-existing*
  /// thread with that id — it never creates or renames one. Ported from RN's
  /// `ff3f159` (which deliberately removed the old "auto-create a thread on
  /// connect" behavior).
  void _onPeer(PeerInfo peer, String state) {
    if (state == 'connected') {
      peers[peer.deviceId] = PeerEntry(display: peer.display, peerId: peer.peerId);
    } else if (state == 'lost') {
      peers.remove(peer.deviceId);
    } else {
      // 'found': known to the transport but not yet connected — nothing to
      // reflect in the store until it actually connects.
      notifyListeners();
      return;
    }

    final thread = threadById(peer.deviceId);
    if (thread != null) {
      thread.hops = state == 'connected' ? 0 : null;
    }
    notifyListeners();
  }

  // ---- pairing / groups ---------------------------------------------------

  /// The only way a 1:1 Thread gets created. Called after a real QR scan
  /// confirms a fingerprint match.
  Future<void> pair(String deviceId, String name) async {
    contacts = await addContact(deviceId, name);
    final existing = threadById(deviceId);
    if (existing != null) {
      existing.title = name;
      existing.initials = initialsOf(name);
    } else {
      threads.add(Thread(
        id: deviceId,
        title: name,
        initials: initialsOf(name),
        preview: 'Paired — say something',
        at: _clock(),
        hops: peers.containsKey(deviceId) ? 0 : null,
        messages: [],
      ));
    }
    notifyListeners();
  }

  /// Removes the contact + thread. The underlying Nearby connection is
  /// untouched — they drop back to being an anonymous relaying node.
  Future<void> unpair(String deviceId) async {
    contacts = await removeContact(deviceId);
    threads.removeWhere((t) => t.id == deviceId);
    notifyListeners();
  }

  /// Leaving a group: just deletes the local thread. No contact/unpair
  /// semantics apply — a group has no single peer behind it.
  void forgetThread(String threadId) {
    threads.removeWhere((t) => t.id == threadId);
    notifyListeners();
  }

  Future<String> createGroup(String name, List<String> memberIds) async {
    final id = newGroupId();
    final members = [meId, ...memberIds];
    threads.add(Thread(
      id: id,
      title: name,
      initials: initialsOf(name),
      group: true,
      members: members,
      preview: '${members.length} people',
      at: _clock(),
      hops: 0,
      messages: [],
    ));
    notifyListeners();

    await send(id, jsonEncode({'id': id, 'name': name, 'members': members}), kind: 'invite');
    return id;
  }

  // ---- messages ------------------------------------------------------

  /// Held from the moment the screen opened. Clearing the badge immediately
  /// would also remove the offer to summarise what hasn't been read yet — the
  /// caller (ChatScreen) is expected to snapshot `unread` before calling this.
  void markRead(String threadId) {
    final thread = threadById(threadId);
    if (thread == null || thread.unread == 0) return;
    thread.unread = 0;
    notifyListeners();
  }

  bool _reachable(String threadId, Thread? thread) {
    if (thread != null && thread.group) {
      return thread.members?.any((m) => m != meId && peers.containsKey(m)) ?? false;
    }
    return peers.containsKey(threadId);
  }

  /// Ports store/mesh.ts's send(): builds the envelope, hands it to the real
  /// transport, then upserts the local Thread with a hops/state derived from
  /// whether the broadcast actually reached anyone.
  Future<void> send(String threadId, String body, {String kind = 'msg'}) async {
    final envelope = newEnvelope(
      id: '$meId-${_counter++}',
      from: meId,
      fromName: meDisplay,
      to: threadId,
      kind: kind,
      body: body,
      at: 0,
    );
    _seen.check(envelope.id); // never relay our own message back to ourselves

    final thread = threadById(threadId);
    final delivered = await _transport?.broadcast(envelope) ?? 0;

    // A revert is bookkeeping on an existing message, not a new one in the
    // thread — revertLastCoin has already struck the original through.
    if (kind == 'revert') {
      stats = stats.copyWith(sent: stats.sent + 1);
      notifyListeners();
      return;
    }

    final directlyReachable = _reachable(threadId, thread);
    final state = delivered == 0 ? 'queued' : (directlyReachable ? 'delivered' : 'sent');

    final msg = Msg(
      id: envelope.id,
      from: 'me',
      text: kind == 'msg' ? body : null,
      coin: kind == 'coin' ? double.tryParse(body) : null,
      image: kind == 'image' ? body : null,
      event: kind == 'event' ? decodeEvent(body) : null,
      at: _clock(),
      hops: directlyReachable ? 0 : (delivered > 0 ? 1 : null),
      state: kind == 'invite' ? null : state,
    );

    if (thread != null && kind != 'invite') {
      thread.messages.add(msg);
      thread.preview = _previewOf(msg);
      thread.at = msg.at;
    }

    stats = stats.copyWith(sent: stats.sent + 1);
    notifyListeners();
  }

  String _previewOf(Msg m) {
    if (m.text != null) return m.text!;
    if (m.coin != null) return '${m.coin!.toStringAsFixed(2)} echocoin';
    if (m.image != null) return 'Photo';
    if (m.event != null) return 'Event: ${m.event!.title}';
    return '';
  }

  /// Show it in the thread, but hold it back for [cancelWindow] first.
  void queueCoin(String threadId, double amount) {
    // One at a time: a queue of pending payments is a queue of things you
    // can't cancel individually under pressure.
    cancelPending();

    final msgId = '$meId-${_counter++}-p';
    pending = PendingCoin(msgId: msgId, threadId: threadId, amount: amount, until: DateTime.now().add(cancelWindow));

    final thread = threadById(threadId);
    thread?.messages.add(Msg(id: msgId, from: 'me', coin: amount, at: _clock(), hops: null, pending: true));
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

  // ---- receiving -----------------------------------------------------

  void _onEnvelope(Envelope envelope, String fromPeerId) {
    final decision = route(envelope, meId, _seen, fromPeer: fromPeerId);

    switch (decision.action) {
      case RelayAction.drop:
        stats = stats.copyWith(dropped: stats.dropped + 1);
        notifyListeners();
        return;

      case RelayAction.relay:
        stats = stats.copyWith(relayed: stats.relayed + 1);
        unawaited(_transport?.broadcast(decision.envelope!, excludePeerId: decision.excludePeer));
        notifyListeners();
        return;

      case RelayAction.fanout:
        final env = decision.envelope!;
        if (env.ttl > 0) {
          unawaited(_transport?.broadcast(env, excludePeerId: decision.excludePeer));
        }
        final isMember = threads.any((t) => t.id == env.to);
        if (!isMember && env.kind != 'invite') return; // carry it, don't show it
        _receive(env);
        return;

      case RelayAction.deliver:
        _receive(decision.envelope!);
        return;
    }
  }

  void _receive(Envelope envelope) {
    final body = _inbound.add(envelope);
    if (body == null) return; // still waiting on more chunks

    final isGroupMsg = isGroup(envelope.to);

    // Invites are never exempt from the contact gate — accepting one from a
    // stranger would reopen the door pairing is meant to close. Non-invite
    // group messages ARE exempt: the group is its own trust boundary.
    final known = contacts.containsKey(envelope.from);
    if (envelope.kind == 'invite') {
      if (!known) {
        stats = stats.copyWith(dropped: stats.dropped + 1);
        notifyListeners();
        return;
      }
    } else if (!isGroupMsg && !known) {
      stats = stats.copyWith(dropped: stats.dropped + 1);
      notifyListeners();
      return;
    }

    if (envelope.kind == 'invite') {
      _handleInvite(envelope, body);
      return;
    }
    if (envelope.kind == 'revert') {
      _handleRevert(envelope, body);
      return;
    }

    _upsertIncoming(envelope, body);
  }

  void _handleInvite(Envelope envelope, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return;
      final id = decoded['id'] as String?;
      final name = decoded['name'] as String?;
      final rawMembers = decoded['members'];
      if (id == null || name == null || rawMembers is! List) return;
      final members = rawMembers.map((e) => e.toString()).toList();
      if (!members.contains(meId)) return; // relayed on, but not for us to join

      if (threadById(id) == null) {
        threads.add(Thread(
          id: id,
          title: name,
          initials: initialsOf(name),
          group: true,
          members: members,
          preview: '${members.length} people',
          at: _clock(),
          hops: 0,
          messages: [],
        ));
        notifyListeners();
      }
    } catch (_) {
      // Malformed invite — never crash the app over another build's payload.
    }
  }

  void _handleRevert(Envelope envelope, String body) {
    final threadId = isGroup(envelope.to) ? envelope.to : envelope.from;
    final thread = threadById(threadId);
    if (thread == null) return;
    final index = thread.messages.indexWhere((m) => m.id == body);
    if (index < 0) return;
    thread.messages[index] = thread.messages[index].copyWith(reverted: true);
    notifyListeners();
  }

  void _upsertIncoming(Envelope envelope, String body) {
    final threadId = isGroup(envelope.to) ? envelope.to : envelope.from;
    var thread = threadById(threadId);

    final senderName = envelope.fromName ?? contacts[envelope.from]?.name ?? envelope.from;

    if (thread == null) {
      thread = Thread(
        id: threadId,
        title: senderName,
        initials: initialsOf(senderName),
        preview: '',
        at: _clock(),
        hops: peers.containsKey(envelope.from) ? 0 : null,
        via: relayedBy(envelope) != null ? peers[relayedBy(envelope)]?.display : null,
        messages: [],
      );
      threads.add(thread);
    }

    final msg = Msg(
      id: envelope.id,
      from: thread.group ? envelope.from : threadId,
      fromName: thread.group ? senderName : null,
      text: envelope.kind == 'msg' ? body : null,
      coin: envelope.kind == 'coin' ? double.tryParse(body) : null,
      image: envelope.kind == 'image' ? body : null,
      event: envelope.kind == 'event' ? decodeEvent(body) : null,
      at: _clock(),
      hops: hopsTaken(envelope),
      via: relayedBy(envelope) != null ? peers[relayedBy(envelope)]?.display ?? relayedBy(envelope) : null,
    );

    thread.messages.add(msg);
    thread.preview = thread.group ? '$senderName: ${_previewOf(msg)}' : _previewOf(msg);
    thread.at = msg.at;
    thread.unread += 1;
    notifyListeners();

    notifyMessage(from: senderName, body: _previewOf(msg), threadId: thread.id, hops: msg.hops);
  }

  @override
  void dispose() {
    _cancelTimer?.cancel();
    _transport?.stop();
    super.dispose();
  }

  String _clock() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}';
  }
}
