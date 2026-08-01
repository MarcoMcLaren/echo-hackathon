// Ported from src/screens/ChatScreen.tsx.
import 'dart:async';

import 'package:flutter/material.dart';
import '../hooks/use_shake.dart';
import '../models/mock.dart' as mock;
import '../store/app_store.dart';
import '../store/app_store_scope.dart';
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import '../widgets/chip.dart';
import '../widgets/chrome.dart';
import '../widgets/message_bubble.dart';
import '../widgets/type.dart';
import 'catch_me_up_sheet.dart';

/// Under this many unread, you can just read them yourself.
const summaryThreshold = 5;

class ChatScreen extends StatefulWidget {
  final String threadId;
  final VoidCallback onBack;
  final ValueChanged<String> onSendCoin;

  const ChatScreen({super.key, required this.threadId, required this.onBack, required this.onSendCoin});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _draft = TextEditingController();
  final _scroller = ScrollController();
  int? _baseline;
  int? _backlog;
  bool _summary = false;

  late AppStore _store;
  ShakeDetector? _shake;
  String? _countdownFor;
  Timer? _countdownTimer;
  int _left = 0;
  String? _note;
  Timer? _noteTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = AppStoreScope.of(context);
    _shake ??= ShakeDetector(_onShake);
    _syncCountdown();

    final thread = _store.threadById(widget.threadId);
    if (thread != null) {
      // Held from the moment the screen opened. Clearing the badge
      // immediately would also remove the offer to summarise what hasn't
      // been read yet.
      _backlog ??= thread.unread;
      if (thread.unread > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _store.markRead(widget.threadId);
        });
      }
    }
  }

  @override
  void dispose() {
    _draft.dispose();
    _scroller.dispose();
    _shake?.dispose();
    _countdownTimer?.cancel();
    _noteTimer?.cancel();
    super.dispose();
  }

  /// Shake does whatever the visible control does: cancel what is still
  /// held, otherwise take back the last payment that already went.
  void _onShake() {
    final holding = _store.pending?.threadId == widget.threadId ? _store.pending : null;
    if (holding != null) {
      _store.cancelPending();
      _showNote('Send cancelled');
    } else {
      final did = _store.revertLastCoin(widget.threadId);
      _showNote(did ? 'Last payment taken back' : 'Nothing to take back');
    }
  }

  void _showNote(String text) {
    setState(() => _note = text);
    _noteTimer?.cancel();
    _noteTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _note = null);
    });
  }

  void _syncCountdown() {
    final holding = _store.pending?.threadId == widget.threadId ? _store.pending : null;
    if (holding?.msgId == _countdownFor) return;
    _countdownFor = holding?.msgId;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (holding == null) {
      _left = 0;
      return;
    }
    _left = _secondsLeft(holding.until);
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() => _left = _secondsLeft(holding.until));
    });
  }

  int _secondsLeft(DateTime until) {
    final ms = until.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void _scrollToEnd({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroller.hasClients) return;
      if (animated) {
        _scroller.animateTo(_scroller.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      } else {
        _scroller.jumpTo(_scroller.position.maxScrollExtent);
      }
    });
  }

  void _send(String threadId) {
    final text = _draft.text.trim();
    if (text.isEmpty) return;
    _draft.clear();
    _store.send(threadId, text);
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final store = _store;
    final thread = store.threadById(widget.threadId)!;
    _baseline ??= thread.messages.length;
    final holding = store.pending?.threadId == widget.threadId ? store.pending : null;
    final backlog = _backlog ?? thread.unread;

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
            const MeshStatusBar(),
            EchoAppBar(title: thread.title, sub: sub, onBack: widget.onBack, right: HopChip(hops: thread.hops, via: thread.via)),
            Expanded(
              child: ListView(
                controller: _scroller,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                children: [
                  if (thread.group) const _ReachBar(),
                  const Center(child: Padding(padding: EdgeInsets.only(bottom: 8), child: MonoText('TODAY', size: 8.5))),
                  for (var i = 0; i < thread.messages.length; i++)
                    MessageBubble(
                      msg: thread.messages[i],
                      senderName: thread.group && thread.messages[i].from != 'me' ? mock.byId(thread.messages[i].from)?.name.split(' ')[0] : null,
                      animate: i >= _baseline!,
                    ),
                  if (backlog >= summaryThreshold)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Semantics(
                          button: true,
                          label: 'Summarise $backlog unread messages on this phone',
                          child: GestureDetector(
                            onTap: () => setState(() => _summary = true),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 36),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(border: Border.all(color: c.hair, width: 1.5), color: c.card, borderRadius: BorderRadius.circular(EchoRadius.pill)),
                              child: DisplayText('Catch me up · $backlog unread', size: 13),
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
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MonoText('SENDING ${holding.amount.toStringAsFixed(2)} IN ${_left}s', size: 9, color: Colors.white),
                          Opacity(opacity: 0.75, child: const MonoText('OR SHAKE THE PHONE', size: 8.5, color: Colors.white)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _store.cancelPending();
                        _showNote('Send cancelled');
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        alignment: Alignment.center,
                        child: const DisplayText('Cancel', size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            if (_note != null)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(14)),
                  child: MonoText(_note!.toUpperCase(), size: 9, color: c.paper),
                ),
              ),
            Container(
              padding: EdgeInsets.fromLTRB(12, 9, 12, 9 + MediaQuery.paddingOf(context).bottom),
              decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.hair2, width: 1))),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Send echocoin',
                    child: GestureDetector(
                      onTap: () => widget.onSendCoin(thread.id),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.coin, width: 1.5)),
                        child: CoinMark(size: 15, color: c.coin),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _draft,
                      onSubmitted: (_) => _send(thread.id),
                      textInputAction: TextInputAction.send,
                      style: TextStyle(fontSize: 12.5, color: c.ink),
                      decoration: InputDecoration(
                        hintText: thread.group ? 'Message ${thread.title}' : 'Message',
                        hintStyle: TextStyle(color: c.ink3),
                        filled: true,
                        fillColor: c.paper,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: const BoxConstraints(minHeight: 40),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: c.hair2)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: c.hair2)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: c.hair2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Send message',
                    child: GestureDetector(
                      onTap: () => _send(thread.id),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: c.ink),
                        child: DisplayText('↑', size: 15, color: c.paper),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_summary) CatchMeUpSheet(thread: thread, unread: backlog, onClose: () => setState(() => _summary = false)),
      ],
    );
  }
}

/// Who can actually hear you right now, before you type.
class _ReachBar extends StatelessWidget {
  const _ReachBar();

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final pips = [c.direct, c.direct, c.relay, c.dim];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: c.card, border: Border.all(color: c.hair2), borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(children: [for (final p in pips) Padding(padding: const EdgeInsets.only(right: 3), child: Container(width: 7, height: 7, decoration: BoxDecoration(color: p, borderRadius: BorderRadius.circular(4))))]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                MonoText('2 DIRECT · 1 VIA THABO · 1 OUT OF REACH', size: 8.5, dim: Dim.two),
                MonoText('SIPHO GETS IT WHEN HE’S BACK', size: 8.5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
