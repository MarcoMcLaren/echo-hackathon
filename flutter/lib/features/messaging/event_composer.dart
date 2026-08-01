// Compose a calendar event to send as a message. Port of
// src/features/messaging/components/EventComposer.tsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/type.dart';
import '../../store/theme_store.dart';
import '../../styles/theme.dart' as tokens;
import 'events.dart' show MeshEvent;

class _Slot {
  const _Slot(this.label, this.at);
  final String label;
  final int at;
}

/// Presets instead of a date picker. A picker means another native dependency
/// and a rebuild, and at a braai nobody is scrolling to a date — they mean
/// tonight, tomorrow, or the weekend.
List<_Slot> _presets() {
  final now = DateTime.now();
  int at(int addDays, int hour) {
    final d = DateTime(now.year, now.month, now.day + addDays, hour);
    return d.millisecondsSinceEpoch;
  }

  // DateTime.weekday is Monday=1..Sunday=7; mod 7 gives JS's Sunday=0..Saturday=6.
  final jsDay = now.weekday % 7;
  var daysToSaturday = (6 - jsDay + 7) % 7;
  if (daysToSaturday == 0) daysToSaturday = 7;

  return [
    _Slot('Tonight 18:00', at(0, 18)),
    _Slot('Tomorrow 14:00', at(1, 14)),
    _Slot('Saturday 14:00', at(daysToSaturday, 14)),
  ];
}

class EventComposer extends StatefulWidget {
  const EventComposer({super.key, required this.onCancel, required this.onSend});

  final VoidCallback onCancel;
  final ValueChanged<MeshEvent> onSend;

  @override
  State<EventComposer> createState() => _EventComposerState();
}

class _EventComposerState extends State<EventComposer> {
  late final List<_Slot> _slots = _presets();
  final _title = TextEditingController();
  final _where = TextEditingController();
  late int _when = _slots[0].at;

  @override
  void dispose() {
    _title.dispose();
    _where.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(tokens.Palette c, String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: c.ink3),
    filled: true,
    fillColor: c.paper,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.hair2)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.hair2)),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final ready = _title.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.hair2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Mono('NEW EVENT', size: 9),
          const SizedBox(height: 9),
          TextField(
            controller: _title,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: c.ink, fontSize: 13.5),
            decoration: _fieldDecoration(c, 'What is happening'),
          ),
          const SizedBox(height: 9),
          TextField(
            controller: _where,
            style: TextStyle(color: c.ink, fontSize: 13.5),
            decoration: _fieldDecoration(c, 'Where (optional)'),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              for (final slot in _slots)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: slot == _slots.last ? 0 : 6),
                    child: _SlotButton(
                      label: slot.label,
                      selected: slot.at == _when,
                      onTap: () => setState(() => _when = slot.at),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Cancel',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: widget.onCancel,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: tokens.touchMin),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: c.hair, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Display('Cancel', size: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  button: true,
                  enabled: ready,
                  label: 'Send event',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: ready
                        ? () => widget.onSend(
                            MeshEvent(
                              title: _title.text.trim(),
                              startsAt: _when,
                              location: _where.text.trim().isEmpty ? null : _where.text.trim(),
                            ),
                          )
                        : null,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: tokens.touchMin),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ready ? c.ink : c.sunk,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Display('Send event', size: 14, color: ready ? c.paper : c.ink3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    return Semantics(
      button: true,
      checked: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: tokens.touchMin),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.ink : Colors.transparent,
            border: Border.all(color: selected ? c.ink : c.hair, width: 1.5),
            borderRadius: BorderRadius.circular(tokens.AppRadius.pill),
          ),
          child: Mono(label.toUpperCase(), size: 8.5, color: selected ? c.paper : c.ink2),
        ),
      ),
    );
  }
}
