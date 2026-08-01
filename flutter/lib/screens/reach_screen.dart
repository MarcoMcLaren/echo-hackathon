// Ported from src/screens/ReachScreen.tsx.
import 'package:flutter/material.dart';
import '../models/types.dart' as types;
import '../screens/new_group_screen.dart';
import '../store/app_store.dart';
import '../store/app_store_scope.dart';
import '../theme/echo_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/chip.dart';
import '../widgets/chrome.dart';
import '../widgets/reach_map.dart';
import '../widgets/remove_sheet.dart';
import '../widgets/type.dart';

class ReachScreen extends StatefulWidget {
  final ValueChanged<String> onOpen;
  const ReachScreen({super.key, required this.onOpen});

  @override
  State<ReachScreen> createState() => _ReachScreenState();
}

class _ReachScreenState extends State<ReachScreen> {
  bool _newGroup = false;
  types.Thread? _removing;

  @override
  Widget build(BuildContext context) {
    final theme = EchoTheme.of(context);
    final store = AppStoreScope.of(context);

    final strangerCount = store.peers.keys.where((id) => !store.contacts.containsKey(id)).length;

    final statusLine = switch (store.status) {
      MeshStatus.live => 'MESH LIVE · ${store.peers.length} PEERS · TAP TO STOP',
      MeshStatus.starting => 'STARTING MESH',
      MeshStatus.error => 'MESH ERROR · TAP TO RETRY',
      MeshStatus.off => 'MESH OFF · TAP TO START',
    };

    // Contacts (people you've actually paired with) draw named; raw peers
    // that never became a contact draw as an anonymous "NODE" — ported from
    // ff3f159's stranger/contact split.
    final nodes = [
      for (final entry in store.peers.entries)
        MapNode(
          id: entry.key,
          name: store.contacts[entry.key]?.name ?? entry.value.display,
          hops: 0,
          stranger: !store.contacts.containsKey(entry.key),
        ),
    ];

    if (_newGroup) {
      final reachable = store.peers.keys.toSet();
      return NewGroupScreen(
        contacts: store.contacts,
        reachableIds: reachable,
        onBack: () => setState(() => _newGroup = false),
        onCreate: (name, memberIds) async {
          final id = await store.createGroup(name, memberIds);
          if (!mounted) return;
          setState(() => _newGroup = false);
          widget.onOpen(id);
        },
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            MeshStatusBar(
              right: statusLine,
              state: switch (store.status) {
                MeshStatus.live => MeshState.live,
                MeshStatus.starting => MeshState.starting,
                MeshStatus.error => MeshState.error,
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
              sub: store.status == MeshStatus.live
                  ? '${store.contacts.length} contacts · $strangerCount relaying · ${store.stats.relayed} carried'
                  : 'Mesh off · start it to find people nearby',
              right: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    label: 'New group',
                    child: GestureDetector(
                      onTap: () => setState(() => _newGroup = true),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: DisplayText('+', size: 20),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Theme: ${theme.mode.name}. Tap to change.',
                    child: GestureDetector(
                      onTap: theme.cycle,
                      child: MonoText(theme.mode.name.toUpperCase(), size: 9),
                    ),
                  ),
                ],
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
                  if (store.threads.isEmpty)
                    _EmptyState(status: store.status, strangerCount: strangerCount)
                  else
                    for (var i = 0; i < store.threads.length; i++)
                      _ConversationRow(
                        thread: store.threads[i],
                        isLast: i == store.threads.length - 1,
                        onOpen: widget.onOpen,
                        onRemove: () => setState(() => _removing = store.threads[i]),
                      ),
                ],
              ),
            ),
          ],
        ),
        if (_removing != null)
          RemoveSheet(
            thread: _removing!,
            onConfirm: () {
              final t = _removing!;
              setState(() => _removing = null);
              if (t.group) {
                store.forgetThread(t.id);
              } else {
                store.unpair(t.id);
              }
            },
            onClose: () => setState(() => _removing = null),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final MeshStatus status;
  final int strangerCount;
  const _EmptyState({required this.status, required this.strangerCount});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final text = status != MeshStatus.live
        ? 'Start the mesh above, then tap or scan with someone nearby to meet them.'
        : strangerCount > 0
            ? '$strangerCount phone${strangerCount == 1 ? '' : 's'} relaying nearby, but you haven’t met anyone yet — meet a phone to start a conversation.'
            : 'No one nearby yet. Meet a phone to start a conversation.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: c.hair2), borderRadius: BorderRadius.circular(12)),
      child: BodyText(text, size: 13, dim: Dim.two),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final types.Thread thread;
  final bool isLast;
  final ValueChanged<String> onOpen;
  final VoidCallback onRemove;

  const _ConversationRow({required this.thread, required this.isLast, required this.onOpen, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    return Semantics(
      button: true,
      label:
          '${thread.title}. ${thread.hops == null ? 'No route' : thread.hops == 0 ? 'Direct' : 'Via ${thread.via}'}',
      child: InkWell(
        onTap: () => onOpen(thread.id),
        onLongPress: onRemove,
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
                    BodyText(thread.preview, size: 11.5, dim: thread.unread > 0 ? Dim.one : Dim.two, maxLines: 1),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (thread.unread > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(9)),
                      child: MonoText('${thread.unread}', size: 8.5, color: c.paper),
                    )
                  else
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
