// Ported from src/screens/NewGroupScreen.tsx (post ff3f159: the member picker
// draws from contacts only, not raw nearby strangers, even if a stranger is
// in range).
//
// A group is made from phones you can reach right now. There is no server
// holding a roster, so everyone you pick has to be told — and being told is a
// message like any other, which means it can arrive late or by relay.
import 'package:flutter/material.dart';

import '../features/vault/contacts.dart';
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import '../widgets/avatar.dart';
import '../widgets/chrome.dart';
import '../widgets/type.dart';

class NewGroupScreen extends StatefulWidget {
  /// id -> contact. People you have met, not phones that happen to be nearby.
  final Map<String, Contact> contacts;
  /// ids currently in Bluetooth range — drives the "IN RANGE" /
  /// "OUT OF RANGE — WILL GET IT LATER" per-row label.
  final Set<String> reachableIds;
  final VoidCallback onBack;
  /// Wired to the store's createGroup by a later integration pass — this
  /// screen just collects a name and the selected contact ids.
  final void Function(String name, List<String> memberIds) onCreate;

  const NewGroupScreen({
    super.key,
    required this.contacts,
    required this.reachableIds,
    required this.onBack,
    required this.onCreate,
  });

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _name = TextEditingController();
  final Set<String> _picked = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _name.removeListener(_onChanged);
    _name.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    setState(() {
      if (!_picked.remove(id)) _picked.add(id);
    });
  }

  void _create() {
    if (!_canCreate) return;
    setState(() => _busy = true);
    widget.onCreate(_name.text.trim(), _picked.toList());
  }

  bool get _canCreate => _name.text.trim().isNotEmpty && _picked.isNotEmpty && !_busy;

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final contacts = widget.contacts.values.toList();

    return Column(
      children: [
        EchoAppBar(title: 'New group', sub: 'Pick from phones you can reach', onBack: widget.onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            children: [
              TextField(
                controller: _name,
                style: TextStyle(fontSize: 15, color: c.ink),
                decoration: InputDecoration(
                  hintText: 'Group name',
                  hintStyle: TextStyle(color: c.ink3),
                  filled: true,
                  fillColor: c.card,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  constraints: const BoxConstraints(minHeight: touchMin),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(EchoRadius.card), borderSide: BorderSide(color: c.hair2)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(EchoRadius.card), borderSide: BorderSide(color: c.hair2)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(EchoRadius.card), borderSide: BorderSide(color: c.hair2)),
                ),
              ),
              const SizedBox(height: 12),
              MonoText(
                contacts.isEmpty ? 'No contacts' : '${contacts.length} contact${contacts.length == 1 ? '' : 's'}',
                size: 10,
              ),
              const SizedBox(height: 12),
              if (contacts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.hair2),
                    borderRadius: BorderRadius.circular(EchoRadius.card),
                  ),
                  child: const BodyText(
                    'A group is made from people you have met. Go to Meet and tap phones together, or scan a code, then come back.',
                    size: 13,
                    dim: Dim.two,
                  ),
                )
              else
                for (var i = 0; i < contacts.length; i++) _ContactRow(
                    contact: contacts[i],
                    inRange: widget.reachableIds.contains(contacts[i].id),
                    on: _picked.contains(contacts[i].id),
                    showDivider: i != contacts.length - 1,
                    onTap: () => _toggle(contacts[i].id),
                  ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(14, 12, 14, 16 + MediaQuery.paddingOf(context).bottom),
          decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.hair2, width: 1))),
          child: Column(
            children: [
              Semantics(
                button: true,
                enabled: _canCreate,
                label: 'Create with ${_picked.length}',
                child: GestureDetector(
                  onTap: _create,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: touchMin),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(color: _canCreate ? c.ink : c.sunk, borderRadius: BorderRadius.circular(10)),
                    child: DisplayText(
                      _busy ? 'Telling everyone…' : 'Create with ${_picked.length}',
                      size: 15,
                      color: _canCreate ? c.paper : c.ink3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const MonoText('EVERYONE PICKED GETS TOLD OVER THE MESH', size: 8.5),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final Contact contact;
  final bool inRange;
  final bool on;
  final bool showDivider;
  final VoidCallback onTap;

  const _ContactRow({
    required this.contact,
    required this.inRange,
    required this.on,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final initials = contact.name.trim().isEmpty
        ? '??'
        : contact.name.trim().substring(0, contact.name.trim().length >= 2 ? 2 : 1).toUpperCase();

    return Semantics(
      button: true,
      checked: on,
      label: '${contact.name}. ${inRange ? 'In range' : 'Out of range'}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: touchMin),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: showDivider ? Border(bottom: BorderSide(color: c.hair2)) : null,
          ),
          child: Row(
            children: [
              Avatar(initials: initials, hops: inRange ? 0 : null),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DisplayText(contact.name, size: 14),
                    MonoText(inRange ? 'IN RANGE' : 'OUT OF RANGE — WILL GET IT LATER', size: 8.5),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: on ? c.direct : c.hair, width: 1.5),
                  color: on ? c.direct : Colors.transparent,
                ),
                child: on ? DisplayText('✓', size: 12, color: c.paper) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
