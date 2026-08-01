// Ported from src/screens/ReachScreen.tsx.
import 'package:flutter/material.dart';
import '../models/mock.dart' as mock;
import '../store/app_store.dart';
import '../store/app_store_scope.dart';
import '../theme/echo_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/chip.dart';
import '../widgets/chrome.dart';
import '../widgets/reach_map.dart';
import '../widgets/type.dart';

class ReachScreen extends StatelessWidget {
  final ValueChanged<String> onOpen;
  const ReachScreen({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = EchoTheme.of(context);
    final store = AppStoreScope.of(context);

    final statusLine = switch (store.status) {
      MeshStatus.live => 'MESH LIVE · 0 PEERS · TAP TO STOP',
      MeshStatus.starting => 'STARTING MESH',
      MeshStatus.off => 'MESH OFF · TAP TO START',
    };

    // Real peers when the mesh is up; there's no Flutter transport, so this
    // always falls back to the seeded demo, same branch RN takes on a solo
    // device — a single phone still shows what the screen is for.
    final nodes = mock.contacts.map((p) => MapNode(id: p.id, name: p.name, hops: p.hops)).toList();

    return Column(
      children: [
        MeshStatusBar(
          right: statusLine,
          state: switch (store.status) {
            MeshStatus.live => MeshState.live,
            MeshStatus.starting => MeshState.starting,
            MeshStatus.off => MeshState.off,
          },
          onPress: store.status == MeshStatus.live
              ? store.stop
              : store.status == MeshStatus.starting
                  ? null
                  : store.start,
        ),
        EchoAppBar(
          title: 'Reach',
          sub: store.status == MeshStatus.live ? '0 reachable · ${store.stats.relayed} relayed for others' : 'Mesh off · showing the demo set',
          right: Semantics(
            button: true,
            label: 'Theme: ${theme.mode.name}. Tap to change.',
            child: GestureDetector(
              onTap: theme.cycle,
              child: MonoText(theme.mode.name.toUpperCase(), size: 9),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            children: [
              ReachMap(nodes: nodes),
              const SizedBox(height: 12),
              const MonoText('CONVERSATIONS', size: 10),
              const SizedBox(height: 4),
              for (var i = 0; i < store.threads.length; i++) _ConversationRow(thread: store.threads[i], isLast: i == store.threads.length - 1, onOpen: onOpen),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final mock.Thread thread;
  final bool isLast;
  final ValueChanged<String> onOpen;

  const _ConversationRow({required this.thread, required this.isLast, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    return Semantics(
      button: true,
      label:
          '${thread.title}. ${thread.hops == null ? 'No route' : thread.hops == 0 ? 'Direct' : 'Via ${thread.via}'}',
      child: InkWell(
        onTap: () => onOpen(thread.id),
        child: Container(
          constraints: const BoxConstraints(minHeight: touchMinChat),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: c.hair2, width: 1))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Avatar(initials: thread.initials, hops: thread.hops),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DisplayText(thread.title, size: 14),
                    const SizedBox(height: 1),
                    BodyText(thread.preview, size: 11.5, dim: Dim.two, maxLines: 1),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MonoText(thread.at, size: 9),
                  const SizedBox(height: 4),
                  HopChip(hops: thread.hops, via: thread.via, label: thread.group ? '${thread.members!.length} in mesh' : null),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const touchMinChat = 48.0;
