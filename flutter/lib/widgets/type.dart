// Typography — ported from src/components/Type.tsx.
import 'package:flutter/material.dart';
import '../theme/echo_theme.dart';
import '../theme/palette.dart';

enum Dim { one, two, three }

Color _ink(Dim? dim, Palette c) {
  switch (dim) {
    case Dim.three:
      return c.ink3;
    case Dim.two:
      return c.ink2;
    default:
      return c.ink;
  }
}

/// Signage face. Titles, balances, buttons, station labels.
class DisplayText extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  final Dim? dim;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  const DisplayText(
    this.text, {
    super.key,
    this.size = 18,
    this.color,
    this.dim,
    this.style,
    this.textAlign,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      style: TextStyle(
        fontFamily: EchoFont.display,
        fontSize: size,
        color: color ?? _ink(dim, c),
        letterSpacing: 0.2,
      ).merge(style),
    );
  }
}

/// Anything read as a sentence. Never below 12.5 inside a bubble.
class BodyText extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  final Dim? dim;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  const BodyText(this.text, {super.key, this.size = 13, this.color, this.dim, this.style, this.textAlign, this.maxLines});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      style: TextStyle(
        fontFamily: EchoFont.body,
        fontSize: size,
        color: color ?? _ink(dim, c),
        height: 1.42,
      ).merge(style),
    );
  }
}

/// Everything the mesh reports about itself: hops, signal, times, amounts.
class MonoText extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  final Dim? dim;
  final TextStyle? style;
  final int? maxLines;

  const MonoText(this.text, {super.key, this.size = 9, this.color, this.dim = Dim.three, this.style, this.maxLines});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      style: TextStyle(
        fontFamily: EchoFont.mono,
        fontSize: size,
        color: color ?? _ink(dim, c),
        letterSpacing: size * 0.09,
      ).merge(style),
    );
  }
}

/// The echocoin mark: a ring with an E in it. Ultramarine, money only.
class CoinMark extends StatelessWidget {
  final double size;
  final Color? color;

  const CoinMark({super.key, this.size = 14, this.color});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final col = color ?? c.coin;
    final borderWidth = size * 0.09 < 1 ? 1.0 : size * 0.09;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: col, width: borderWidth)),
      child: Text(
        'E',
        style: TextStyle(fontFamily: EchoFont.display, fontSize: size * 0.62, color: col, height: 1),
      ),
    );
  }
}

/// Numeric text set with tabular figures, matching RN's fontVariant tabular-nums.
TextStyle tabularNums(TextStyle style) => style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
