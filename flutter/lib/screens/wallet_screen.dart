// Ported from src/screens/WalletScreen.tsx.
import 'package:flutter/material.dart';
import '../store/app_store.dart';
import '../store/app_store_scope.dart';
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import '../widgets/chrome.dart';
import '../widgets/route_strip.dart';
import '../widgets/type.dart';
import '../models/types.dart';

class WalletScreen extends StatelessWidget {
  final VoidCallback onSend;
  final VoidCallback onTap;

  const WalletScreen({super.key, required this.onSend, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final store = AppStoreScope.of(context);
    final wallet = walletFrom(store.threads);

    return Column(
      children: [
        const MeshStatusBar(),
        const EchoAppBar(title: 'Wallet', sub: 'Echocoin · balance held on device'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: c.card,
                  border: Border.all(color: c.hair2),
                  borderRadius: BorderRadius.circular(EchoRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MonoText('BALANCE', size: 10),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const CoinMark(size: 34),
                          const SizedBox(width: 9),
                          Text(
                            wallet.balance.toStringAsFixed(2),
                            style: tabularNums(TextStyle(
                              fontFamily: EchoFont.display,
                              fontSize: 44,
                              color: c.coin,
                              letterSpacing: 0.2,
                            )),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    MonoText('ECHOCOIN · ${store.contacts.length} CONTACTS PAIRED', size: 8.5),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Send',
                      onPressed: onSend,
                      backgroundColor: c.coin,
                      borderColor: c.coin,
                      textColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _ActionButton(label: 'Request', onPressed: null, borderColor: c.hair),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _ActionButton(label: 'Tap', onPressed: onTap, borderColor: c.hair),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const MonoText('ACTIVITY', size: 10),
              const SizedBox(height: 4),
              if (wallet.entries.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.hair2, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(EchoRadius.card),
                  ),
                  child: const BodyText(
                    'Nothing has moved yet. Send or receive echocoin with a paired contact to see it here.',
                    size: 12.5,
                    dim: Dim.two,
                  ),
                )
              else
                for (var i = 0; i < wallet.entries.length; i++)
                  _LedgerRow(entry: wallet.entries[i], isLast: i == wallet.entries.length - 1),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color borderColor;
  final Color? textColor;

  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    required this.borderColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: touchMin),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DisplayText(label, size: 14, color: textColor),
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final Entry entry;
  final bool isLast;

  const _LedgerRow({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final positive = entry.amount > 0;
    // Mirrors the RN `e.hops ?` truthiness check: 0 and null both fall through
    // to the plain note, only hops >= 1 draws the RouteStrip.
    final showRoute = entry.hops != null && entry.hops! > 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: c.hair2, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              '${positive ? '+' : '−'}${entry.amount.abs().toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: tabularNums(TextStyle(
                fontFamily: EchoFont.display,
                fontSize: 15,
                color: positive ? c.coin : c.ink,
                letterSpacing: 0.2,
              )),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BodyText(entry.who, size: 12),
                const SizedBox(height: 3),
                if (showRoute)
                  RouteStrip(hops: entry.hops, via: entry.via, label: 'VIA ${entry.via?.toUpperCase()} · ${entry.note}')
                else
                  MonoText(entry.note, size: 8.5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
