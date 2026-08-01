// A group is made from phones you can reach right now. There is no server
// holding a roster, so everyone you pick has to be told — and being told is a
// message like any other, which means it can arrive late or by relay. Port
// of src/screens/NewGroupScreen.tsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/avatar.dart';
import '../components/chrome.dart' show EchoAppBar, MeshState, MeshStatus;
import '../components/type.dart';
import '../features/messaging/types.dart' as transport;
import '../store/mesh_store.dart';
import '../store/theme_store.dart';
import '../styles/theme.dart' as tokens;

MeshState _chromeState(transport.MeshStatus status) => switch (status) {
  transport.MeshStatus.off => MeshState.off,
  transport.MeshStatus.starting => MeshState.starting,
  transport.MeshStatus.live => MeshState.live,
  transport.MeshStatus.error => MeshState.error,
};

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key, required this.onBack, required this.onCreated});

  final VoidCallback onBack;
  final ValueChanged<String> onCreated;

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _name = TextEditingController();
  final _picked = <String>{};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    setState(() {
      if (!_picked.remove(id)) _picked.add(id);
    });
  }

  Future<void> _create(MeshStore mesh) async {
    if (_name.text.trim().isEmpty || _picked.isEmpty || _busy) return;
    setState(() => _busy = true);
    final id = await mesh.createGroup(_name.text.trim(), _picked.toList());
    if (!mounted) return;
    widget.onCreated(id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final mesh = context.watch<MeshStore>();
    // People you have met, not phones that happen to be nearby. A group of
    // strangers is not a group.
    final reachable = [
      for (final contact in mesh.contacts.values)
        (id: contact.id, name: contact.name, inRange: mesh.peers.containsKey(contact.id)),
    ];
    final canCreate = _name.text.trim().isNotEmpty && _picked.isNotEmpty && !_busy;

    return Column(
      children: [
        MeshStatus(
          right: mesh.status == transport.MeshStatus.live ? 'MESH LIVE' : 'MESH OFF',
          state: _chromeState(mesh.status),
        ),
        EchoAppBar(title: 'New group', sub: 'Pick from phones you can reach', onBack: widget.onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            children: [
              TextField(
                controller: _name,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: c.ink, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Group name',
                  hintStyle: TextStyle(color: c.ink3),
                  filled: true,
                  fillColor: c.card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.AppRadius.card),
                    borderSide: BorderSide(color: c.hair2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.AppRadius.card),
                    borderSide: BorderSide(color: c.hair2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Mono(
                (reachable.isNotEmpty
                        ? '${reachable.length} contact${reachable.length == 1 ? '' : 's'}'
                        : 'No contacts')
                    .toUpperCase(),
                size: 10,
              ),
              const SizedBox(height: 12),
              if (reachable.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.hair2),
                    borderRadius: BorderRadius.circular(tokens.AppRadius.card),
                  ),
                  child: Body(
                    mesh.status == transport.MeshStatus.live
                        ? 'A group is made from people you have met. Go to Meet and tap '
                              'phones together, or scan a code, then come back.'
                        : 'Start the mesh from the Reach screen, then meet someone from the '
                              'Meet tab. Groups are built from contacts, not from whoever '
                              'happens to be nearby.',
                    size: 13,
                    dim: 2,
                  ),
                )
              else
                for (var i = 0; i < reachable.length; i++)
                  _PeerRow(
                    id: reachable[i].id,
                    display: reachable[i].name,
                    inRange: reachable[i].inRange,
                    selected: _picked.contains(reachable[i].id),
                    isLast: i == reachable.length - 1,
                    colors: c,
                    onTap: () => _toggle(reachable[i].id),
                  ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(14, 12, 14, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.hair2))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: true,
                enabled: canCreate,
                label: _busy ? 'Telling everyone' : 'Create with ${_picked.length}',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: canCreate ? () => _create(mesh) : null,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: tokens.touchMin),
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: canCreate ? c.ink : c.sunk,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Display(
                      _busy ? 'Telling everyone…' : 'Create with ${_picked.length}',
                      size: 15,
                      color: canCreate ? c.paper : c.ink3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Mono('EVERYONE PICKED GETS TOLD OVER THE MESH', size: 8.5),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeerRow extends StatelessWidget {
  const _PeerRow({
    required this.id,
    required this.display,
    required this.inRange,
    required this.selected,
    required this.isLast,
    required this.colors,
    required this.onTap,
  });

  final String id;
  final String display;
  final bool inRange;
  final bool selected;
  final bool isLast;
  final tokens.Palette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Semantics(
      button: true,
      checked: selected,
      label: '$display. ${inRange ? 'In range' : 'Out of range'}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: tokens.touchMin),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: isLast ? BorderSide.none : BorderSide(color: c.hair2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Avatar(
                initials: display.substring(0, display.length < 2 ? display.length : 2).toUpperCase(),
                hops: inRange ? 0 : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Display(display, size: 14),
                    Mono(inRange ? 'IN RANGE' : 'OUT OF RANGE — WILL GET IT LATER', size: 8.5),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? c.direct : c.hair, width: 1.5),
                  color: selected ? c.direct : Colors.transparent,
                ),
                child: selected ? Display('✓', size: 12, color: c.paper) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
