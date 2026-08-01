// Port of src/screens/ChatScreen.tsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/chip.dart';
import '../components/chrome.dart' show MeshStatus, EchoAppBar;
import '../components/type.dart';
import '../features/ai/summarize.dart';
import '../features/messaging/message_bubble.dart';
import '../store/mesh_store.dart';
import '../store/mock.dart' as mock;
import '../store/theme_store.dart';
import '../styles/theme.dart' as tokens;
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
  Future<mock.Summary>? _summaryFuture;

  // Anything past this index arrived while the screen was open, so its route
  // strip draws itself rather than appearing already there.
  int _baseline = 0;
  bool _baselineSet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd(animated: false));
  }

  @override
  void dispose() {
    _draftController.dispose();
    _scroll.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final mesh = context.watch<MeshStore>();
    final thread = mesh.threads.firstWhere((t) => t.id == widget.threadId);

    if (!_baselineSet) {
      _baseline = thread.messages.length;
      _baselineSet = true;
    }

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
                      senderName: thread.group ? mock.byId(thread.messages[i].from)?.name.split(' ').first : null,
                      animate: i >= _baseline,
                    ),
                  if (thread.group)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Semantics(
                          button: true,
                          excludeSemantics: true,
                          label: 'Catch me up · 41 new',
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _summary = true;
                              _summaryFuture = context.read<ThreadSummarizer>().summarize(thread.messages);
                            }),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 36),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                border: Border.all(color: c.hair, width: 1.5),
                                borderRadius: BorderRadius.circular(tokens.AppRadius.pill),
                                color: c.card,
                              ),
                              child: const Display('Catch me up · 41 new', size: 13),
                            ),
                          ),
                        ),
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
            summary: _summaryFuture!,
            onClose: () => setState(() => _summary = false),
          ),
      ],
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
