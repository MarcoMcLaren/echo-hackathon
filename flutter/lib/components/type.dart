// Text primitives. Port of src/components/Type.tsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/theme_store.dart';
import '../styles/theme.dart' as tokens;

Color _ink(int? dim, tokens.Palette c) => switch (dim) {
  3 => c.ink3,
  2 => c.ink2,
  _ => c.ink,
};

/// Signage face. Titles, balances, buttons, station labels.
class Display extends StatelessWidget {
  const Display(
    this.data, {
    super.key,
    this.size = 18,
    this.color,
    this.dim,
    this.style,
    this.maxLines,
    this.textAlign,
  });

  final String data;
  final double size;
  final Color? color;
  final int? dim;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    return Text(
      data,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: tokens.AppFont.display,
        fontSize: size,
        color: color ?? _ink(dim, c),
        letterSpacing: 0.2,
      ).merge(style),
    );
  }
}

/// Anything read as a sentence. Never below 12.5 inside a bubble.
class Body extends StatelessWidget {
  const Body(
    this.data, {
    super.key,
    this.size = 13,
    this.color,
    this.dim,
    this.style,
    this.maxLines,
    this.textAlign,
  });

  final String data;
  final double size;
  final Color? color;
  final int? dim;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    return Text(
      data,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: tokens.AppFont.body,
        fontSize: size,
        color: color ?? _ink(dim, c),
        height: 1.42,
      ).merge(style),
    );
  }
}

/// Everything the mesh reports about itself: hops, signal, times, amounts.
class Mono extends StatelessWidget {
  const Mono(
    this.data, {
    super.key,
    this.size = 9,
    this.color,
    this.dim = 3,
    this.style,
    this.maxLines,
    this.textAlign,
  });

  final String data;
  final double size;
  final Color? color;
  final int? dim;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    return Text(
      data,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: tokens.AppFont.mono,
        fontSize: size,
        color: color ?? _ink(dim, c),
        letterSpacing: size * 0.09,
      ).merge(style),
    );
  }
}

/// The echocoin mark: a ring with an E in it. Ultramarine, money only.
class CoinMark extends StatelessWidget {
  const CoinMark({super.key, this.size = 14, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final col = color ?? c.coin;
    final borderWidth = size * 0.09 < 1 ? 1.0 : size * 0.09;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: col, width: borderWidth),
      ),
      child: Text(
        'E',
        style: TextStyle(
          fontFamily: tokens.AppFont.display,
          fontSize: size * 0.62,
          height: 1,
          color: col,
        ),
      ),
    );
  }
}
