// Ported from src/screens/SendCoinScreen.tsx.
import 'package:flutter/material.dart';
import '../models/mock.dart' as mock;
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import '../widgets/avatar.dart';
import '../widgets/chip.dart';
import '../widgets/chrome.dart';
import '../widgets/type.dart';

const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];

class SendCoinScreen extends StatefulWidget {
  final String contactId;
  final VoidCallback onBack;

  const SendCoinScreen({super.key, required this.contactId, required this.onBack});

  @override
  State<SendCoinScreen> createState() => _SendCoinScreenState();
}

class _SendCoinScreenState extends State<SendCoinScreen> {
  String amount = '20.00';

  void _press(String k) {
    setState(() {
      if (k == '⌫') {
        amount = amount.length <= 1 ? '0' : amount.substring(0, amount.length - 1);
        return;
      }
      if (k == '.' && amount.contains('.')) return;
      amount = amount == '0' ? k : amount + k;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;

    final contact = mock.byId(widget.contactId);
    final thread = mock.threadById(widget.contactId);
    final name = contact?.name ?? thread?.title ?? 'Contact';
    final initials = contact?.initials ?? thread?.initials ?? '··';
    // Matches the RN `contact?.hops ?? thread?.hops ?? 0` chain verbatim,
    // including its quirk: a contact with hops: null (no route) falls through
    // to 0 here rather than staying null, if its thread fallback is also null.
    final int? hops = contact?.hops ?? thread?.hops ?? 0;
    final via = contact?.via ?? thread?.via;

    final routeNote = hops == null
        ? 'QUEUES UNTIL A ROUTE OPENS'
        : hops == 0
            ? 'SIGNED HERE · GOES DIRECT'
            : 'SIGNED HERE · RELAY CAN’T READ IT';

    return Column(
      children: [
        const MeshStatusBar(),
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
                    children: [
                      Avatar(initials: initials, hops: hops, size: 30),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DisplayText(name, size: 14),
                            MonoText(
                              hops == null
                                  ? 'NO ROUTE RIGHT NOW'
                                  : hops == 0
                                      ? 'IN BLUETOOTH RANGE'
                                      : 'REACHABLE VIA ${via?.toUpperCase()}',
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CoinMark(size: 40),
                        const SizedBox(width: 10),
                        Text(
                          amount,
                          style: tabularNums(TextStyle(
                            fontFamily: EchoFont.display,
                            fontSize: 52,
                            color: c.coin,
                            letterSpacing: 0.2,
                          )),
                        ),
                      ],
                    ),
                  ),
                ),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final k in _keys)
                      SizedBox(
                        width: (MediaQuery.sizeOf(context).width - 28 - 10) / 3,
                        child: _KeypadKey(label: k, onPressed: () => _press(k)),
                      ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: touchMin),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: c.coin, borderRadius: BorderRadius.circular(10)),
                  child: DisplayText('Send $amount', size: 15, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: touchMin),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border.all(color: c.hair, width: 1.5), borderRadius: BorderRadius.circular(10)),
                  child: const DisplayText('Or tap phones together', size: 15),
                ),
                const SizedBox(height: 8),
                MonoText(routeNote, size: 8.5),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KeypadKey extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _KeypadKey({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    return Semantics(
      button: true,
      label: label == '⌫' ? 'Delete' : label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: touchMin),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: c.card,
            border: Border.all(color: c.hair2),
            borderRadius: BorderRadius.circular(9),
          ),
          child: DisplayText(label, size: 21),
        ),
      ),
    );
  }
}
