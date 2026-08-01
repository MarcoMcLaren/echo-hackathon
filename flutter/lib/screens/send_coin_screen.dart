// Port of src/screens/SendCoinScreen.tsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/avatar.dart';
import '../components/chip.dart';
import '../components/chrome.dart' show MeshStatus, EchoAppBar;
import '../components/type.dart';
import '../store/mesh_store.dart';
import '../store/mock.dart' as mock;
import '../store/theme_store.dart';
import '../styles/theme.dart' as tokens;

const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];

class SendCoinScreen extends StatefulWidget {
  const SendCoinScreen({super.key, required this.contactId, required this.onBack, required this.onQueued});

  final String contactId;
  final VoidCallback onBack;

  /// Land in the conversation, where the cancel window is visible. Returning
  /// to the tab list would hide the only control that can stop the send.
  final ValueChanged<String> onQueued;

  @override
  State<SendCoinScreen> createState() => _SendCoinScreenState();
}

class _SendCoinScreenState extends State<SendCoinScreen> {
  String _amount = '20.00';

  void _press(String k) {
    setState(() {
      if (k == '⌫') {
        _amount = _amount.length <= 1 ? '0' : _amount.substring(0, _amount.length - 1);
        return;
      }
      if (k == '.' && _amount.contains('.')) return;
      _amount = _amount == '0' ? k : _amount + k;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);

    final contact = mock.byId(widget.contactId);
    mock.Thread? thread;
    for (final t in mock.threads) {
      if (t.id == widget.contactId) {
        thread = t;
        break;
      }
    }
    final name = contact?.name ?? thread?.title ?? 'Contact';
    final initials = contact?.initials ?? thread?.initials ?? '··';
    // Mirrors the RN source's fallback chain exactly: `contact?.hops ??
    // thread?.hops ?? 0` collapses a genuine null (no route) on both sides to
    // the 0 default, so `hops` can never actually be null here — same as in
    // the original, whose `hops === null` branches are equally unreachable.
    final hops = contact?.hops ?? thread?.hops ?? 0;
    final via = contact?.via ?? thread?.via;

    final routeNote = hops == 0 ? 'SIGNED HERE · GOES DIRECT' : 'SIGNED HERE · RELAY CAN’T READ IT';

    return Column(
      children: [
        const MeshStatus(),
        EchoAppBar(title: 'Send echocoin', sub: 'Balance ${mock.balance.toStringAsFixed(2)}', onBack: widget.onBack),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.card,
                    border: Border.all(color: c.hair2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Avatar(initials: initials, hops: hops, size: 30),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Display(name, size: 14),
                            Mono(
                              hops == 0 ? 'IN BLUETOOTH RANGE' : 'REACHABLE VIA ${via?.toUpperCase()}',
                              size: 8.5,
                            ),
                          ],
                        ),
                      ),
                      HopChip(hops: hops, via: via, label: hops != 0 ? '$hops hop' : null),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CoinMark(size: 40, color: c.coin),
                      const SizedBox(width: 10),
                      Display(
                        _amount,
                        size: 52,
                        color: c.coin,
                        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 5.0;
                        final keyWidth = (constraints.maxWidth - gap * 2) / 3;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final k in _keys)
                              SizedBox(
                                width: keyWidth,
                                child: _KeypadButton(label: k, onTap: () => _press(k), colors: c),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Send $_amount',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () {
                      context.read<MeshStore>().queueCoin(widget.contactId, double.tryParse(_amount) ?? 0);
                      widget.onQueued(widget.contactId);
                    },
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 48),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.coin, borderRadius: BorderRadius.circular(10)),
                      child: Display('Send $_amount', size: 15, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  label: 'Or tap phones together',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 48),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: c.hair, width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Display('Or tap phones together', size: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Mono(routeNote, size: 8.5),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({required this.label, required this.onTap, required this.colors});

  final String label;
  final VoidCallback onTap;
  final tokens.Palette colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label == '⌫' ? 'Delete' : label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: colors.card,
            border: Border.all(color: colors.hair2),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Display(label, size: 21),
        ),
      ),
    );
  }
}
