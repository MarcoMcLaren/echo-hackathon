// Live mesh state. Owns the transport and applies the relay rules to anything
// that arrives, so screens only ever read plain data.
//
// Port of src/store/mesh.ts (through ff3f159, "pairing is the only way to
// become a person you can talk to"). There is no seed data — every thread and
// contact here comes from a real pairing or a real message, so an empty
// screen means "nothing has happened yet," not "the demo set is showing."
// See [MeshTransport] in features/messaging/types.dart for the contract a
// native implementation must satisfy.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../features/messaging/events.dart' show decodeEvent;
import '../features/messaging/notifier.dart';
import '../features/messaging/types.dart';
import '../features/vault/contacts.dart';
import '../features/vault/identity.dart';
import '../utils/relay.dart';
import 'types.dart';

class MeshSelf {
  const MeshSelf({required this.deviceId, required this.display});

  final String deviceId;
  final String display;

  MeshSelf withDisplay(String display) =>
      MeshSelf(deviceId: deviceId, display: display);

  MeshSelf withDeviceId(String deviceId) =>
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

/// What every phone starts with. There is no issuer and no ledger server —
/// this is a demo currency, and pretending otherwise would be dishonest.
/// Everything after this point is real: the balance is opening minus what you
/// sent plus what you received.
const double openingBalance = 100;

/// The wallet, derived from coin messages rather than stored separately. One
/// source of truth means the balance can never disagree with the thread it
/// came from. Reverted transfers stay visible but do not count.
({double balance, List<Entry> entries}) walletFrom(List<Thread> threads) {
  final entries = <Entry>[];
  for (final t in threads) {
    for (final m in t.messages) {
      if (m.coin == null || m.pending) continue;
      entries.add(
        Entry(
          id: m.id,
          amount: m.from == 'me' ? -m.coin! : m.coin!,
          who: t.title,
          hops: m.hops,
          via: m.via,
          note: m.state == MsgState.queued ? 'WAITING FOR A ROUTE · ${m.at}' : m.at,
          reverted: m.reverted,
        ),
      );
    }
  }
  final net = entries.where((e) => !e.reverted).fold<double>(0, (sum, e) => sum + e.amount);
  return (balance: openingBalance + net, entries: entries.reversed.toList());
}

String _randomBase36(int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random();
  return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
}

class MeshStore extends ChangeNotifier {
  /// [deviceId] pins the id outright (what tests do) and skips the identity
  /// vault entirely, so [ready] starts true and [setName] is a plain state
  /// update. Leave it null to have [init]/[start] resolve a persisted
  /// [Profile] from [profileStore] instead.
  MeshStore({
    MeshTransport? transport,
    MeshNotifier? notifier,
    String? deviceId,
    String? display,
    ProfileStore? profileStore,
    ContactsStore? contactsStore,
  }) : _transport = transport, // ignore: prefer_initializing_formals
       _notifier = notifier ?? MockMeshNotifier(),
       _identity = deviceId == null ? IdentityVault(profileStore) : null,
       _contacts = ContactBook(contactsStore),
       ready = deviceId != null,
       me = MeshSelf(deviceId: deviceId ?? 'pending', display: display ?? '');

  final SeenCache _seen = SeenCache();
  final Reassembler _inbound = Reassembler();
  final MeshTransport? _transport;
  final MeshNotifier _notifier;
  final ContactBook _contacts;

  /// Null when [deviceId] was pinned explicitly at construction — nothing to
  /// resolve, and nothing that should override it.
  final IdentityVault? _identity;
  Timer? _cancelTimer;

  MeshSelf me;

  /// False until a name has been chosen (or a deviceId was pinned at
  /// construction). Drives the first-run screen.
  bool ready;
  MeshStatus status = MeshStatus.off;
  String? error;

  /// deviceId -> what we know about them right now. Most of these are
  /// strangers whose only job is carrying traffic.
  Map<String, MeshPeer> peers = {};

  /// The people you have actually met, by tap or by scanned code. Only these
  /// get a conversation, and only these can put a message in front of you.
  Map<String, Contact> contacts = {};

  /// Empty. Conversations appear when you pair with someone or a message
  /// arrives.
  List<Thread> threads = [];

  /// Counts for the demo — proof the relay actually did something.
  MeshStats stats = const MeshStats();

  PendingCoin? pending;

  /// Claim this phone's identity and load its contacts. Called once at
  /// launch (via [start], but safe to call earlier), not when the mesh
  /// starts — identity is who you are, not something that only exists while
  /// the radio is on.
  Future<void> init() async {
    if (ready) return;
    final identity = _identity;
    if (identity == null) {
      ready = true;
      return;
    }
    final profile = await identity.loadProfile();
    // Never set up. The first-run screen asks for a name, and only then does
    // this phone get an id.
    if (profile == null) {
      return;
    }
    final loaded = await _contacts.load();
    me = MeshSelf(deviceId: profile.id, display: profile.name);
    contacts = loaded;
    if (threads.isEmpty) {
      threads = [
        for (final k in loaded.values)
          Thread(
            id: k.id,
            title: k.name,
            initials: _initialsOf(k.name),
            preview: 'Paired',
            at: '',
            hops: null,
            messages: const [],
            unread: 0,
          ),
      ];
    }
    ready = true;
    notifyListeners();
  }

  /// First launch: pick a name, get an id.
  Future<void> createIdentity(String name) async {
    final identity = _identity;
    if (identity == null) return;
    final profile = await identity.createProfile(name);
    me = MeshSelf(deviceId: profile.id, display: profile.name);
    contacts = {};
    ready = true;
    notifyListeners();
  }

  /// Wipe everything and go back to first launch, with a brand new id.
  Future<void> resetApp() async {
    await stop();
    await _contacts.clear();
    contacts = {};
    threads = [];
    peers = {};
    pending = null;
    stats = const MeshStats();
    error = null;
    final identity = _identity;
    if (identity != null) {
      await identity.resetIdentity();
      ready = false;
      me = const MeshSelf(deviceId: 'pending', display: '');
    }
    notifyListeners();
  }

  Future<void> setName(String display) async {
    final identity = _identity;
    if (identity == null) {
      me = me.withDisplay(display);
      notifyListeners();
      return;
    }
    final profile = await identity.renameProfile(display);
    if (profile != null) {
      me = me.withDisplay(profile.name);
      notifyListeners();
    }
  }

  void markRead(String threadId) {
    threads = [
      for (final t in threads) t.id == threadId ? _withUnread(t, 0) : t,
    ];
    notifyListeners();
  }

  /// A tap or a scanned code proved you met. Creates the conversation.
  Future<void> pair(String deviceId, String name) async {
    contacts = await _contacts.add(deviceId, name);
    final i = threads.indexWhere((t) => t.id == deviceId);
    if (i >= 0) {
      final t = threads[i];
      final next = [...threads];
      next[i] = _withHops(t, t.hops, title: name);
      threads = next;
    } else {
      threads = [
        Thread(
          id: deviceId,
          title: name,
          initials: _initialsOf(name),
          preview: 'Paired — say something',
          at: 'now',
          hops: peers.containsKey(deviceId) ? 0 : null,
          messages: const [],
          unread: 0,
        ),
        ...threads,
      ];
    }
    notifyListeners();
  }

  /// Remove someone. They go back to being a node — still relaying for the
  /// mesh, no longer able to reach you. No block needed: the contact list is
  /// an allowlist, so being off it is enough.
  Future<void> unpair(String deviceId) async {
    contacts = await _contacts.remove(deviceId);
    threads = threads.where((t) => t.id != deviceId).toList();
    notifyListeners();
  }

  /// Forget a conversation that has no contact behind it, such as a group.
  void forgetThread(String threadId) {
    threads = threads.where((t) => t.id != threadId).toList();
    notifyListeners();
  }

  /// Make a group from peers you can currently reach, and tell them about it.
  Future<String> createGroup(String name, List<String> memberIds) async {
    final id = newGroupId();
    final members = [me.deviceId, ...memberIds];

    threads = [
      Thread(
        id: id,
        title: name,
        initials: _initialsOf(name),
        group: true,
        members: members,
        preview: '${members.length} people',
        at: 'now',
        hops: 0,
        messages: const [],
        unread: 0,
      ),
      ...threads,
    ];
    notifyListeners();

    // Addressed to the group, so it fans out to everyone in range. Phones
    // not named in it forward the invite without joining.
    await send(
      id,
      jsonEncode({'id': id, 'name': name, 'members': members}),
      kind: EnvelopeKind.invite,
    );
    return id;
  }

  Future<void> start() async {
    if (status == MeshStatus.live || status == MeshStatus.starting) return;
    status = MeshStatus.starting;
    error = null;
    notifyListeners();

    // Identity and contacts are claimed at launch, but starting the mesh
    // without them would advertise as "pending", so make sure they are in.
    await init();

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
      // Travels with the message so a relayed sender still has a name at the
      // far end, where they are not a peer and cannot be looked up.
      fromName: me.display,
      to: threadId,
      kind: kind,
      body: body,
      at: DateTime.now().millisecondsSinceEpoch,
    );
    _seen.check(envelope.id); // never relay our own message back to ourselves

    // A group has no single peer to be "in range of" — it is reachable if
    // anyone is, and the delivery line says how many actually got it.
    final reachable = isGroup(threadId) ? peers.isNotEmpty : peers.containsKey(threadId);
    final transport = _transport;
    final fanout = transport != null ? await transport.broadcast(envelope) : 0;

    // Neither a revert nor an invite is a message in the thread. Both are
    // bookkeeping the UI has already reflected.
    if (kind == EnvelopeKind.revert || kind == EnvelopeKind.invite) {
      stats = stats.copyWith(sent: stats.sent + 1);
      notifyListeners();
      return;
    }

    stats = stats.copyWith(sent: stats.sent + 1);
    threads = _upsertMessage(
      threads,
      threadId,
      Msg(
        id: envelope.id,
        from: 'me',
        text: kind == EnvelopeKind.msg ? body : null,
        coin: kind == EnvelopeKind.coin ? double.tryParse(body) : null,
        image: kind == EnvelopeKind.image ? body : null,
        event: kind == EnvelopeKind.event ? decodeEvent(body) : null,
        at: _clock(envelope.at),
        hops: reachable ? 0 : (fanout > 0 ? 1 : null),
        // No peer at all means it waits — never show it as sent.
        state: fanout == 0
            ? MsgState.queued
            : (reachable ? MsgState.delivered : MsgState.sent),
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
      Msg(
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

    Msg? target;
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

    // Connecting to a node does NOT create a conversation. Being in range of
    // a stranger is not a relationship — it just means they can carry
    // traffic. Conversations come from pairing, nowhere else.
    //
    // What a connection does do is update the route on a conversation you
    // already have with this person.
    final route = state == PeerLinkState.connected ? 0 : null;
    final nextThreads = [
      for (final t in threads) t.id == peer.deviceId ? _withHops(t, route) : t,
    ];

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
      case FanoutDecision(:final envelope, :final excludePeer):
        // Group traffic: carry it on regardless, then show it only if this
        // phone is actually in the group.
        if (envelope.ttl > 0) {
          stats = stats.copyWith(relayed: stats.relayed + 1);
          notifyListeners();
          _transport?.broadcast(envelope, excludePeer: excludePeer);
        }
        final member = threads.any((t) => t.id == envelope.to);
        if (member || envelope.kind == EnvelopeKind.invite) {
          _deliver(envelope);
        }
      case DeliverDecision(:final envelope):
        _deliver(envelope);
    }
  }

  /// Delivered to us — directly, or as a member of the group it's addressed
  /// to. A split payload only becomes a message once every part has landed;
  /// until then there is nothing to show.
  void _deliver(Envelope partial) {
    final whole = _inbound.add(partial);
    if (whole == null) return;
    final e = partial.copyWith(body: whole);

    // Only people you have met can put something in front of you. A
    // stranger's message is still relayed onward for whoever it is for — we
    // just do not show it. This is the difference between being a node in
    // someone's mesh and being in their contacts.
    final known = contacts.containsKey(e.from) || isGroup(e.to);
    if (!known) {
      stats = stats.copyWith(dropped: stats.dropped + 1);
      notifyListeners();
      return;
    }

    final hops = hopsTaken(e);
    final relay = relayedBy(e);

    // An invite creates the group locally — but only from someone you have
    // met, and only if you are actually named in it. Group messages are
    // exempt from the contact check above, because the group itself is the
    // trust boundary: two people in Alice's group need not have paired with
    // each other. An invite is what draws that boundary, so it cannot come
    // from a stranger — otherwise anyone in radio range could put a group on
    // your phone and talk to you through it.
    if (e.kind == EnvelopeKind.invite) {
      if (!contacts.containsKey(e.from)) {
        stats = stats.copyWith(dropped: stats.dropped + 1);
        notifyListeners();
        return;
      }
      _handleInvite(e, hops, relay);
      return;
    }

    if (e.kind == EnvelopeKind.msg || e.kind == EnvelopeKind.coin) {
      _notifier.notify(
        NotifyPayload(
          from: e.fromName ?? peers[e.from]?.display ?? e.from,
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
      // A group message belongs to the group, not to whoever sent it.
      isGroup(e.to) ? e.to : e.from,
      Msg(
        id: e.id,
        from: e.from,
        fromName: e.fromName,
        text: e.kind == EnvelopeKind.msg ? e.body : null,
        coin: e.kind == EnvelopeKind.coin ? double.tryParse(e.body) : null,
        image: e.kind == EnvelopeKind.image ? e.body : null,
        event: e.kind == EnvelopeKind.event ? decodeEvent(e.body) : null,
        at: _clock(e.at),
        hops: hops,
        via: relay != null ? (peers[relay]?.display ?? relay) : null,
      ),
      unread: true,
      // Name the thread from the envelope, not the peer list — a relayed
      // sender is not a peer here.
      title: e.fromName,
    );
    notifyListeners();
  }

  void _handleInvite(Envelope e, int hops, String? relay) {
    try {
      final decoded = jsonDecode(e.body);
      if (decoded is! Map ||
          decoded['id'] is! String ||
          decoded['name'] is! String ||
          decoded['members'] is! List ||
          (decoded['members'] as List).any((m) => m is! String)) {
        return;
      }

      final id = decoded['id'] as String;
      final members = List<String>.from(decoded['members'] as List);
      if (!members.contains(me.deviceId)) return;
      if (threads.any((t) => t.id == id)) return;

      final name = decoded['name'] as String;
      threads = [
        Thread(
          id: id,
          title: name,
          initials: _initialsOf(name),
          group: true,
          members: members,
          preview: '${members.length} people',
          at: _clock(e.at),
          hops: hops,
          via: relay != null ? (peers[relay]?.display ?? relay) : null,
          messages: const [],
          unread: 0,
        ),
        ...threads,
      ];
      notifyListeners();
    } catch (_) {
      // A malformed invite from another build is not our problem.
    }
  }

  Thread _withHops(Thread t, Hops hops, {String? title}) => Thread(
    id: t.id,
    title: title ?? t.title,
    initials: title != null ? _initialsOf(title) : t.initials,
    group: t.group,
    members: t.members,
    preview: t.preview,
    at: t.at,
    hops: hops,
    via: t.via,
    messages: t.messages,
    unread: t.unread,
  );

  Thread _withUnread(Thread t, int unread) => Thread(
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

  Thread _withMessages(Thread t, List<Msg> messages) => Thread(
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
List<Thread> _upsertMessage(
  List<Thread> threads,
  String threadId,
  Msg msg, {
  bool unread = false,
  String? title,
}) {
  final preview =
      msg.text ??
      (msg.image != null ? 'Photo' : null) ??
      msg.event?.title ??
      '${msg.coin?.toStringAsFixed(2)} echocoin';
  final i = threads.indexWhere((t) => t.id == threadId);
  if (i < 0) {
    final resolvedTitle = title ?? threadId;
    return [
      Thread(
        id: threadId,
        title: resolvedTitle,
        initials: _initialsOf(resolvedTitle),
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
  next[i] = Thread(
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
