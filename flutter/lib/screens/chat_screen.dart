// Ported from src/screens/ChatScreen.tsx.
import 'package:flutter/material.dart';
import '../models/mock.dart' as mock;
import '../store/app_store_scope.dart';
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import '../widgets/chip.dart';
import '../widgets/chrome.dart';
import '../widgets/message_bubble.dart';
import '../widgets/type.dart';
import 'catch_me_up_sheet.dart';

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
  bool _summary = false;

  @override
  void dispose() {
    _draft.dispose();
    _scroller.dispose();
    super.dispose();
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
    AppStoreScope.of(context).send(threadId, text);
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final store = AppStoreScope.of(context);
    final thread = store.threadById(widget.threadId)!;
    _baseline ??= thread.messages.length;

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
                  if (thread.group)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: GestureDetector(
                          onTap: () => setState(() => _summary = true),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 36),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(border: Border.all(color: c.hair, width: 1.5), color: c.card, borderRadius: BorderRadius.circular(EchoRadius.pill)),
                            child: const DisplayText('Catch me up · 41 new', size: 13),
                          ),
                        ),
                      ),
                    ),
                ],
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
        if (_summary) CatchMeUpSheet(onClose: () => setState(() => _summary = false)),
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
