// Port of src/screens/ChatScreen.tsx.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/chip.dart';
import '../components/chrome.dart' show MeshStatus, EchoAppBar;
import '../components/type.dart';
import '../features/messaging/attachments.dart';
import '../features/messaging/event_composer.dart';
import '../features/messaging/events.dart';
import '../features/messaging/message_bubble.dart';
import '../services/shake_service.dart';
import '../store/mesh_store.dart';
import '../store/mock.dart' as mock;
import '../store/theme_store.dart';
import '../styles/theme.dart' as tokens;
import '../utils/relay.dart' show EnvelopeKind;
import 'catch_me_up_sheet.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.threadId, required this.onBack, required this.onSendCoin});

  final String threadId;
  final VoidCallback onBack;
  final ValueChanged<String> onSendCoin;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _draftController = TextEditingController();
  final _scroll = ScrollController();
  bool _summary = false;

  ShakeService? _shake;
  StreamSubscription<void>? _shakeSub;
  Timer? _countdown;
  Timer? _noteTimer;
  String? _note;
  bool _attaching = false;
  bool _composingEvent = false;

  // Anything past this index arrived while the screen was open, so its route
  // strip draws itself rather than appearing already there.
  int _baseline = 0;
  bool _baselineSet = false;

  // Held from the moment the screen opened. Clearing the unread badge
  // immediately would also remove the offer to summarise what you have not
  // read yet.
  int? _backlog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd(animated: false));

    final shake = context.read<ShakeService>();
    _shake = shake;
    shake.start();
    _shakeSub = shake.onShake.listen((_) => _onShake());
  }

  @override
  void dispose() {
    _draftController.dispose();
    _scroll.dispose();
    _shakeSub?.cancel();
    _countdown?.cancel();
    _noteTimer?.cancel();
    _shake?.stop();
    super.dispose();
  }

  void _onShake() {
    final mesh = context.read<MeshStore>();
    final holding = mesh.pending?.threadId == widget.threadId ? mesh.pending : null;
    if (holding != null) {
      mesh.cancelPending();
      _showNote('Send cancelled');
    } else {
      mesh.revertLastCoin(widget.threadId).then((did) {
        _showNote(did ? 'Last payment taken back' : 'Nothing to take back');
      });
    }
  }

  /// Ticks the "in Ns" countdown on the coin-cancel banner independently of
  /// any MeshStore change — runs only while a hold is actually showing, so a
  /// screen with nothing pending never schedules a frame on its own.
  void _syncCountdown({required bool active}) {
    if (active) {
      _countdown ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _countdown?.cancel();
      _countdown = null;
    }
  }

  void _showNote(String text) {
    if (!mounted) return;
    setState(() => _note = text);
    _noteTimer?.cancel();
    _noteTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _note = null);
    });
  }

  void _scrollToEnd({required bool animated}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (animated) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  void _send(MeshStore mesh, String threadId) {
    final text = _draftController.text.trim();
    if (text.isEmpty) return;
    _draftController.clear();
    mesh.send(threadId, text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd(animated: true));
  }

  String _peerName(MeshStore mesh, String id) => mesh.peers[id]?.display ?? id;

  Future<void> _attachPhoto(MeshStore mesh, String threadId, {required bool fromCamera}) async {
    setState(() => _attaching = false);
    final source = context.read<ImageSource>();
    final picked = fromCamera ? await source.pickFromCamera() : await source.pickFromLibrary();
    if (!mounted) return;
    if (picked == null) return;
    if (picked.bytes > maxImageChars) {
      _showNote('That photo is too big to send over the mesh');
      return;
    }
    _showNote('Sending photo in ${chunkCount(picked.bytes)} parts');
    mesh.send(threadId, picked.dataUri, kind: EnvelopeKind.image);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd(animated: true));
  }

  void _sendEvent(MeshStore mesh, String threadId, MeshEvent event) {
    setState(() => _composingEvent = false);
    mesh.send(threadId, encodeEvent(event), kind: EnvelopeKind.event);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd(animated: true));
  }

  Future<void> _addToCalendar(MeshEvent event) async {
    final result = await context.read<CalendarWriter>().save(event);
    if (!mounted) return;
    _showNote(
      result.ok
          ? 'Added to your calendar'
          : switch (result.reason!) {
              SaveFailureReason.denied => 'Echo needs calendar permission to add it',
              SaveFailureReason.noCalendar => 'No calendar on this phone can be written to',
              SaveFailureReason.error => 'Could not add it to the calendar',
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final mesh = context.watch<MeshStore>();
    final thread = mesh.threads.firstWhere((t) => t.id == widget.threadId);

    if (!_baselineSet) {
      _baseline = thread.messages.length;
      _baselineSet = true;
    }
    _backlog ??= thread.unread;
    final backlog = _backlog!;

    if (thread.unread > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) mesh.markRead(widget.threadId);
      });
    }

    final holding = mesh.pending?.threadId == widget.threadId ? mesh.pending : null;
    _syncCountdown(active: holding != null);
    final left = holding == null
        ? 0
        : ((holding.until - DateTime.now().millisecondsSinceEpoch) / 1000).ceil().clamp(0, 999);

    final sub = thread.group
        ? '${thread.members!.length} members · 3 reachable'
        : thread.hops == null
        ? 'No route · messages queue here'
        : thread.hops == 0
        ? 'Direct · in Bluetooth range'
        : '${thread.hops! + 1} hops · via ${thread.via}';

    return Stack(
      children: [
        Column(
          children: [
            const MeshStatus(),
            EchoAppBar(
              title: thread.title,
              sub: sub,
              onBack: widget.onBack,
              right: HopChip(hops: thread.hops, via: thread.via),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                children: [
                  if (thread.group) _ReachBar(colors: c),
                  const Center(child: Padding(padding: EdgeInsets.only(bottom: 8), child: Mono('TODAY', size: 8.5))),
                  for (var i = 0; i < thread.messages.length; i++)
                    MessageBubble(
                      key: ValueKey(thread.messages[i].id),
                      msg: thread.messages[i],
                      senderName: thread.group
                          ? mock.byId(thread.messages[i].from)?.name.split(' ').first ??
                                _peerName(mesh, thread.messages[i].from)
                          : null,
                      animate: i >= _baseline,
                      onSaveEvent: _addToCalendar,
                    ),
                  if (backlog >= summaryThreshold)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Semantics(
                          button: true,
                          excludeSemantics: true,
                          label: 'Summarise $backlog unread messages on this phone',
                          child: GestureDetector(
                            onTap: () => setState(() => _summary = true),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 36),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                border: Border.all(color: c.hair, width: 1.5),
                                borderRadius: BorderRadius.circular(tokens.AppRadius.pill),
                                color: c.card,
                              ),
                              child: Display('Catch me up · $backlog unread', size: 13),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (holding != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: c.coin,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Mono('SENDING ${holding.amount.toStringAsFixed(2)} IN ${left}s', size: 9, color: Colors.white),
                          Opacity(
                            opacity: 0.75,
                            child: const Mono('OR SHAKE THE PHONE', size: 8.5, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Cancel send',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () {
                          mesh.cancelPending();
                          _showNote('Send cancelled');
                        },
                        child: Container(
                          constraints: const BoxConstraints(minHeight: tokens.touchMin),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          child: const Display('Cancel', size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_note != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(14)),
                    child: Mono(_note!.toUpperCase(), size: 9, color: c.paper),
                  ),
                ),
              ),
            if (_composingEvent)
              EventComposer(
                onCancel: () => setState(() => _composingEvent = false),
                onSend: (event) => _sendEvent(mesh, thread.id, event),
              ),
            if (_attaching)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.hair2))),
                child: Row(
                  children: [
                    Expanded(
                      child: _AttachOption(
                        label: 'Take a photo',
                        colors: c,
                        onTap: () => _attachPhoto(mesh, thread.id, fromCamera: true),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _AttachOption(
                        label: 'Choose photo',
                        colors: c,
                        onTap: () => _attachPhoto(mesh, thread.id, fromCamera: false),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _AttachOption(
                        label: 'Event',
                        colors: c,
                        onTap: () => setState(() {
                          _attaching = false;
                          _composingEvent = true;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: c.card,
                border: Border(top: BorderSide(color: c.hair2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Semantics(
                    button: true,
                    label: 'Attach a photo or an event',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => setState(() => _attaching = !_attaching),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: c.hair, width: 1.5),
                        ),
                        child: Display(_attaching ? '×' : '+', size: 17, dim: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Send echocoin',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => widget.onSendCoin(thread.id),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: c.coin, width: 1.5),
                        ),
                        child: CoinMark(size: 15, color: c.coin),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _draftController,
                      onSubmitted: (_) => _send(mesh, thread.id),
                      textInputAction: TextInputAction.send,
                      style: TextStyle(color: c.ink, fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: thread.group ? 'Message ${thread.title}' : 'Message',
                        hintStyle: TextStyle(color: c.ink3),
                        filled: true,
                        fillColor: c.paper,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: c.hair2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: c.hair2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Send message',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => _send(mesh, thread.id),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: c.ink),
                        child: Display('↑', size: 15, color: c.paper),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_summary)
          CatchMeUpSheet(
            thread: thread,
            unread: backlog,
            onClose: () => setState(() => _summary = false),
          ),
      ],
    );
  }
}

/// One tile in the attach-photo/attach-event row.
class _AttachOption extends StatelessWidget {
  const _AttachOption({required this.label, required this.colors, required this.onTap});

  final String label;
  final tokens.Palette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: tokens.touchMin),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: colors.hair, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Display(label, size: 13),
        ),
      ),
    );
  }
}

/// Who can actually hear you right now, before you type.
class _ReachBar extends StatelessWidget {
  const _ReachBar({required this.colors});

  final tokens.Palette colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final pips = [c.direct, c.direct, c.relay, c.dim];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.hair2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in pips)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Container(width: 7, height: 7, decoration: BoxDecoration(color: p, shape: BoxShape.circle)),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Mono('2 DIRECT · 1 VIA THABO · 1 OUT OF REACH', size: 8.5, dim: 2),
                Mono('SIPHO GETS IT WHEN HE’S BACK', size: 8.5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
