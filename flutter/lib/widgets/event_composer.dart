// Ported from src/features/messaging/components/EventComposer.tsx.
//
// Presets instead of a date picker. A picker means another native dependency
// and a rebuild, and at a braai nobody is scrolling to a date — they mean
// tonight, tomorrow, or the weekend. Bottom-sheet animation matches
// CatchMeUpSheet (see lib/screens/catch_me_up_sheet.dart) for consistency
// with the rest of the app's sheets.
import 'package:flutter/material.dart';

import '../features/messaging/events.dart';
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import 'type.dart';

class _Preset {
  final String label;
  final int at;
  const _Preset(this.label, this.at);
}

/// Ports RN's `(6 - now.getDay() + 7) % 7 || 7` "days to Saturday" formula.
/// JS `getDay()` is 0=Sun..6=Sat; Dart's `DateTime.weekday` is 1=Mon..7=Sun,
/// but `weekday % 7` maps Dart's Sunday (7) back to 0 and leaves every other
/// day unchanged, landing exactly on JS's numbering — so the same formula
/// applies unmodified. The `|| 7` (RN) / `== 0 ? 7` (here) means "today"
/// never counts: if today is already Saturday this always picks next
/// Saturday, not this one.
List<_Preset> _presets() {
  final now = DateTime.now();
  int at(int addDays, int hour) => DateTime(now.year, now.month, now.day + addDays, hour, 0, 0, 0).millisecondsSinceEpoch;

  final jsDay = now.weekday % 7;
  final rawDaysToSaturday = (6 - jsDay + 7) % 7;
  final daysToSaturday = rawDaysToSaturday == 0 ? 7 : rawDaysToSaturday;

  return [
    _Preset('Tonight 18:00', at(0, 18)),
    _Preset('Tomorrow 14:00', at(1, 14)),
    _Preset('Saturday 14:00', at(daysToSaturday, 14)),
  ];
}

class EventComposer extends StatefulWidget {
  final ValueChanged<MeshEvent> onSend;
  final VoidCallback onClose;

  const EventComposer({super.key, required this.onSend, required this.onClose});

  @override
  State<EventComposer> createState() => _EventComposerState();
}

class _EventComposerState extends State<EventComposer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rise;
  late final List<_Preset> _slots;

  final _title = TextEditingController();
  final _where = TextEditingController();
  late int _when;

  @override
  void initState() {
    super.initState();
    _slots = _presets();
    _when = _slots.first.at;
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _rise = CurvedAnimation(parent: _controller, curve: const Cubic(0.2, 0.8, 0.2, 1));
    _controller.forward();
    _title.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _title.removeListener(_onChanged);
    _title.dispose();
    _where.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final where = _where.text.trim();
    widget.onSend(MeshEvent(title: title, startsAt: _when, location: where.isEmpty ? null : where));
  }

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final ready = _title.text.trim().isNotEmpty;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Semantics(
              label: 'Cancel new event',
              child: Container(color: const Color.fromRGBO(13, 26, 22, 0.45)),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: _rise,
            builder: (context, child) => Opacity(
              opacity: _rise.value,
              child: Transform.translate(offset: Offset(0, 40 * (1 - _rise.value)), child: child),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
              decoration: BoxDecoration(
                color: c.card,
                border: Border(top: BorderSide(color: c.hair2)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(EchoRadius.sheet),
                  topRight: Radius.circular(EchoRadius.sheet),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.hair, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 10),
                  const MonoText('NEW EVENT', size: 9),
                  const SizedBox(height: 9),
                  _field(c, _title, 'What is happening'),
                  const SizedBox(height: 9),
                  _field(c, _where, 'Where (optional)'),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      for (final slot in _slots) ...[
                        Expanded(child: _SlotChip(slot: slot, on: slot.at == _when, onTap: () => setState(() => _when = slot.at))),
                        if (slot != _slots.last) const SizedBox(width: 6),
                      ],
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Semantics(
                        button: true,
                        label: 'Cancel',
                        child: GestureDetector(
                          onTap: widget.onClose,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: touchMin),
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(border: Border.all(color: c.hair, width: 1.5), borderRadius: BorderRadius.circular(10)),
                            child: const DisplayText('Cancel', size: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          button: true,
                          enabled: ready,
                          label: 'Send event',
                          child: GestureDetector(
                            onTap: ready ? _send : null,
                            child: Container(
                              constraints: const BoxConstraints(minHeight: touchMin),
                              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: ready ? c.ink : c.sunk, borderRadius: BorderRadius.circular(10)),
                              child: DisplayText('Send event', size: 14, color: ready ? c.paper : c.ink3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(Palette c, TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: TextStyle(fontSize: 13.5, color: c.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.ink3),
        filled: true,
        fillColor: c.paper,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(minHeight: 44),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.hair2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.hair2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.hair2)),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  final _Preset slot;
  final bool on;
  final VoidCallback onTap;
  const _SlotChip({required this.slot, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    return Semantics(
      button: true,
      selected: on,
      label: slot.label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(EchoRadius.pill),
            border: Border.all(color: on ? c.ink : c.hair, width: 1.5),
            color: on ? c.ink : Colors.transparent,
          ),
          child: MonoText(slot.label.toUpperCase(), size: 8.5, color: on ? c.paper : c.ink2),
        ),
      ),
    );
  }
}
