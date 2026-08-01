// Port of src/screens/ReachScreen.tsx: mesh status + contact map + threads.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/avatar.dart';
import '../components/chip.dart';
import '../components/chrome.dart' show MeshStatus, MeshState, EchoAppBar;
import '../components/type.dart';
import '../features/messaging/reach_map.dart';
import '../features/messaging/types.dart' as transport;
import '../store/mesh_store.dart';
import '../store/mock.dart' as mock;
import '../store/theme_store.dart';
import '../styles/theme.dart' as tokens;

MeshState _chromeState(transport.MeshStatus status) => switch (status) {
  transport.MeshStatus.off => MeshState.off,
  transport.MeshStatus.starting => MeshState.starting,
  transport.MeshStatus.live => MeshState.live,
  transport.MeshStatus.error => MeshState.error,
};

class ReachScreen extends StatelessWidget {
  const ReachScreen({super.key, required this.onOpen});

  final ValueChanged<String> onOpen;

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
        'MESH LIVE · $live PEER${live == 1 ? '' : 'S'} · TAP TO STOP',
      transport.MeshStatus.starting => 'STARTING MESH',
      transport.MeshStatus.error => (mesh.error ?? 'MESH FAILED').toUpperCase(),
      transport.MeshStatus.off => 'MESH OFF · TAP TO START',
    };

    // Real peers when the mesh is up; the seeded demo when it isn't, so a
    // single phone still shows what the screen is for.
    final nodes =
        (mesh.status == transport.MeshStatus.live && mesh.peers.isNotEmpty)
        ? [
            for (final entry in mesh.peers.entries)
              MapNode(id: entry.key, name: entry.value.display, hops: 0),
          ]
        : [
            for (final contact in mock.contacts)
              MapNode(id: contact.id, name: contact.name, hops: contact.hops),
          ];

    final VoidCallback? onPress = switch (mesh.status) {
      transport.MeshStatus.live => mesh.stop,
      transport.MeshStatus.starting => null,
      transport.MeshStatus.off || transport.MeshStatus.error => mesh.start,
    };

    return Column(
      children: [
        MeshStatus(
          right: statusLine,
          state: _chromeState(mesh.status),
          onPress: onPress,
        ),
        EchoAppBar(
          title: 'Reach',
          sub: mesh.status == transport.MeshStatus.live
              ? '$live reachable · ${mesh.stats.relayed} relayed for others'
              : 'Mesh off · showing the demo set',
          right: Semantics(
            button: true,
            label: 'Theme: ${themeStore.mode.name}. Tap to change.',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: themeStore.cycle,
              child: Mono(themeStore.mode.name.toUpperCase(), size: 9),
            ),
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
              for (var i = 0; i < mesh.threads.length; i++)
                _ConvRow(
                  thread: mesh.threads[i],
                  isLast: i == mesh.threads.length - 1,
                  colors: c,
                  onTap: () => onOpen(mesh.threads[i].id),
                ),
            ],
          ),
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
  });

  final mock.Thread thread;
  final bool isLast;
  final tokens.Palette colors;
  final VoidCallback onTap;

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
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
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
