// Port of src/screens/WalletScreen.tsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/chrome.dart' show MeshStatus, EchoAppBar;
import '../components/route_strip.dart';
import '../components/type.dart';
import '../store/mock.dart' as mock;
import '../store/theme_store.dart';
import '../styles/theme.dart' as tokens;

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, required this.onSend, required this.onTap});

  final VoidCallback onSend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);

    return Column(
      children: [
        const MeshStatus(),
        const EchoAppBar(title: 'Wallet', sub: 'Echocoin · balance held on device'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: c.hair2),
                  borderRadius: BorderRadius.circular(tokens.AppRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Mono('BALANCE', size: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CoinMark(size: 34, color: c.coin),
                          const SizedBox(width: 9),
                          Display(
                            mock.balance.toStringAsFixed(2),
                            size: 44,
                            color: c.coin,
                            style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                        ],
                      ),
                    ),
                    const Mono('ECHOCOIN · LAST SYNCED WITH 3 PEERS 2M AGO', size: 8.5),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Send',
                      onTap: onSend,
                      backgroundColor: c.coin,
                      borderColor: c.coin,
                      textColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _ActionButton(label: 'Request', onTap: null, borderColor: c.hair, textColor: c.ink),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _ActionButton(label: 'Tap', onTap: onTap, borderColor: c.hair, textColor: c.ink),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Mono('ACTIVITY', size: 10),
              const SizedBox(height: 12),
              for (var i = 0; i < mock.ledger.length; i++)
                _LedgerRow(entry: mock.ledger[i], isLast: i == mock.ledger.length - 1, colors: c),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final String label;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Display(label, size: 14, color: textColor),
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, required this.isLast, required this.colors});

  final mock.Entry entry;
  final bool isLast;
  final tokens.Palette colors;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final c = colors;
    final positive = e.amount > 0;
    final relayed = e.hops != null && e.hops != 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.hair2, width: isLast ? 0 : 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Display(
              '${positive ? '+' : '−'}${e.amount.abs().toStringAsFixed(2)}',
              size: 15,
              color: positive ? c.coin : c.ink,
              textAlign: TextAlign.right,
              style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Body(e.who, size: 12),
                const SizedBox(height: 3),
                relayed
                    ? RouteStrip(hops: e.hops, via: e.via, label: 'VIA ${e.via?.toUpperCase()} · ${e.note}')
                    : Mono(e.note, size: 8.5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
