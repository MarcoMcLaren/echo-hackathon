// Port of src/screens/ReachScreen.tsx: mesh status + contact map + threads.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/avatar.dart';
import '../components/chip.dart';
import '../components/chrome.dart' show MeshStatus, MeshState, EchoAppBar;
import '../components/type.dart';
import '../features/messaging/reach_map.dart';
import '../features/messaging/remove_sheet.dart';
import '../features/messaging/types.dart' as transport;
import '../store/mesh_store.dart';
import '../store/theme_store.dart';
import '../store/types.dart' as types;
import '../styles/theme.dart' as tokens;

MeshState _chromeState(transport.MeshStatus status) => switch (status) {
  transport.MeshStatus.off => MeshState.off,
  transport.MeshStatus.starting => MeshState.starting,
  transport.MeshStatus.live => MeshState.live,
  transport.MeshStatus.error => MeshState.error,
};

class ReachScreen extends StatefulWidget {
  const ReachScreen({super.key, required this.onOpen, required this.onNewGroup});

  final ValueChanged<String> onOpen;
  final VoidCallback onNewGroup;

  @override
  State<ReachScreen> createState() => _ReachScreenState();
}

class _ReachScreenState extends State<ReachScreen> {
  types.Thread? _removing;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final themeStore = context.watch<ThemeStore>();
    final mesh = context.watch<MeshStore>();

    // peers only ever holds currently-reachable phones (see MeshPeer in
    // mesh_store.dart), so every entry here counts as live.
    final live = mesh.peers.length;

    final statusLine = switch (mesh.status) {
      transport.MeshStatus.live =>
        'MESH LIVE · $live NODE${live == 1 ? '' : 'S'} IN RANGE · TAP TO STOP',
      transport.MeshStatus.starting => 'STARTING MESH',
      transport.MeshStatus.error => (mesh.error ?? 'MESH FAILED').toUpperCase(),
      transport.MeshStatus.off => 'MESH OFF · TAP TO START',
    };

    // Everything in range goes on the map, but only people you have met are
<<<<<<< HEAD
    // named. The rest are nodes: they carry traffic and nothing else. Off
    // the mesh, or with nobody in range, there is nothing to show — no
    // seeded demo standing in for it.
    final nodes = [
      for (final entry in mesh.peers.entries)
        MapNode(
          id: entry.key,
          name: mesh.contacts[entry.key]?.name ?? entry.value.display,
          hops: 0,
          stranger: !mesh.contacts.containsKey(entry.key),
        ),
    ];
    final strangers = nodes.where((n) => n.stranger).length;
=======
    // named. Off the mesh, or with nobody in range, there is nothing to show
    // — no seeded demo standing in for it.
    final nodes = [
      for (final entry in mesh.peers.entries)
        MapNode(id: entry.key, name: mesh.contacts[entry.key]?.name ?? entry.value.display, hops: 0),
    ];
>>>>>>> 32f78fcf58440299edded6647836b26ce8c1e3bf

    final VoidCallback? onPress = switch (mesh.status) {
      transport.MeshStatus.live => mesh.stop,
      transport.MeshStatus.starting => null,
      transport.MeshStatus.off || transport.MeshStatus.error => mesh.start,
    };

    return Stack(
      children: [
<<<<<<< HEAD
        Column(
          children: [
            MeshStatus(
              right: statusLine,
              state: _chromeState(mesh.status),
              onPress: onPress,
            ),
            EchoAppBar(
              title: 'Reach',
              sub: mesh.status == transport.MeshStatus.live
                  ? '${mesh.contacts.length} contacts · $strangers relaying · ${mesh.stats.relayed} carried'
                  : 'Mesh off · nothing is listening',
              right: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    label: 'Theme: ${themeStore.mode.name}. Tap to change.',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: themeStore.cycle,
                      child: Mono(themeStore.mode.name.toUpperCase(), size: 9),
=======
        MeshStatus(
          right: statusLine,
          state: _chromeState(mesh.status),
          onPress: onPress,
        ),
        EchoAppBar(
          title: 'Reach',
          sub: mesh.status == transport.MeshStatus.live
              ? '$live reachable · ${mesh.stats.relayed} relayed for others'
              : 'Mesh off · nothing in range',
          right: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: true,
                label: 'Theme: ${themeStore.mode.name}. Tap to change.',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: themeStore.cycle,
                  child: Mono(themeStore.mode.name.toUpperCase(), size: 9),
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: 'New group',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onNewGroup,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: tokens.touchMin, minHeight: tokens.touchMin),
                    alignment: Alignment.center,
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.hair, width: 1.5)),
                      child: Display('+', size: 17, dim: 1),
>>>>>>> 32f78fcf58440299edded6647836b26ce8c1e3bf
                    ),
                  ),
                  const SizedBox(width: 10),
                  Semantics(
                    button: true,
                    label: 'New group',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: widget.onNewGroup,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: tokens.touchMin, minHeight: tokens.touchMin),
                        alignment: Alignment.center,
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.hair, width: 1.5)),
                          child: Display('+', size: 17, dim: 1),
                        ),
                      ),
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
                  const Mono('CONVERSATIONS', size: 10),
                  const SizedBox(height: 12),
                  if (mesh.threads.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.hair2),
                        borderRadius: BorderRadius.circular(tokens.AppRadius.card),
                      ),
                      child: Body(
                        mesh.status != transport.MeshStatus.live
                            ? 'Tap the line above to start the mesh, then meet someone with a '
                                  'phone tap or a scanned code.'
                            : strangers > 0
                            ? '$strangers phone${strangers == 1 ? '' : 's'} in range '
                                  '${strangers == 1 ? 'is' : 'are'} carrying messages for the '
                                  'mesh, but being nearby is not the same as knowing someone. '
                                  'Go to Meet and tap or scan a code to start a conversation.'
                            : 'Nobody yet. Go to Meet and hold the phones together, or scan a '
                                  'code, to add someone.',
                        size: 13,
                        dim: 2,
                      ),
                    ),
                  for (var i = 0; i < mesh.threads.length; i++)
                    _ConvRow(
                      thread: mesh.threads[i],
                      isLast: i == mesh.threads.length - 1,
                      colors: c,
                      onTap: () => widget.onOpen(mesh.threads[i].id),
                      onLongPress: () => setState(() => _removing = mesh.threads[i]),
                    ),
                  if (mesh.threads.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Center(child: Mono('HOLD A CONVERSATION TO REMOVE IT', size: 8.5)),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (_removing != null)
          RemoveSheet(
            thread: _removing!,
            onCancel: () => setState(() => _removing = null),
            onConfirm: () {
              final removed = _removing!;
              // A group has no peer behind it, so there is nothing to
              // block — leaving is just forgetting it.
              if (removed.group) {
                mesh.forgetThread(removed.id);
              } else {
                mesh.unpair(removed.id);
              }
              setState(() => _removing = null);
            },
          ),
      ],
    );
  }
}

class _ConvRow extends StatelessWidget {
  const _ConvRow({
    required this.thread,
    required this.isLast,
    required this.colors,
    required this.onTap,
    required this.onLongPress,
  });

  final types.Thread thread;
  final bool isLast;
  final tokens.Palette colors;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = thread;
    return Semantics(
      button: true,
      label:
          '${t.title}. ${t.hops == null
              ? 'No route'
              : t.hops == 0
              ? 'Direct'
              : 'Via ${t.via}'}',
      hint: t.group ? 'Hold to leave this group' : 'Hold to remove this phone',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: isLast
                  ? BorderSide.none
                  : BorderSide(color: colors.hair2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Avatar(initials: t.initials, hops: t.hops),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Display(t.title, size: 14, maxLines: 1),
                    const SizedBox(height: 1),
                    Body(t.preview, size: 11.5, dim: t.unread > 0 ? 1 : 2, maxLines: 1),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  t.unread > 0
                      ? Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(color: colors.ink, borderRadius: BorderRadius.circular(9)),
                          alignment: Alignment.center,
                          child: Mono('${t.unread}', size: 8.5, color: colors.paper),
                        )
                      : Mono(t.at, size: 9),
                  const SizedBox(height: 4),
                  HopChip(
                    hops: t.hops,
                    via: t.via,
                    label: t.group ? '${t.members!.length} in mesh' : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
