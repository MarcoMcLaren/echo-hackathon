// Echo design tokens. Port of src/styles/theme.ts.
//
// The three signal colours are ONE SCALE, not three accents:
//   direct -> relay -> dim  encodes hop distance (here / routed / unreachable).
// `coin` sits outside that scale because money is not a distance. It must never
// be used for signal or state, and nothing else may use it.
import 'package:flutter/material.dart';

@immutable
class Palette {
  final Color paper;
  final Color card;
  final Color sunk;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color hair;
  final Color hair2;
  final Color direct;
  final Color relay;
  final Color dim;
  final Color coin;
  final Color bubbleIn;
  final Color bubbleOut;
  final Color bubbleOutInk;

  const Palette({
    required this.paper,
    required this.card,
    required this.sunk,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.hair,
    required this.hair2,
    required this.direct,
    required this.relay,
    required this.dim,
    required this.coin,
    required this.bubbleIn,
    required this.bubbleOut,
    required this.bubbleOutInk,
  });
}

const light = Palette(
  paper: Color(0xFFE6EAE7),
  card: Color(0xFFFFFFFF),
  sunk: Color(0xFFDCE2DE),
  ink: Color(0xFF0D1A16),
  ink2: Color(0xFF54635D),
  ink3: Color(0xFF8C9791),
  hair: Color(0x290D1A16),
  hair2: Color(0x140D1A16),
  direct: Color(0xFFEE3E2B),
  relay: Color(0xFFF2A007),
  dim: Color(0xFF8C9791),
  coin: Color(0xFF2340D6),
  bubbleIn: Color(0xFFFFFFFF),
  bubbleOut: Color(0xFF0D1A16),
  bubbleOutInk: Color(0xFFF2F5F3),
);

const dark = Palette(
  paper: Color(0xFF0C1714),
  card: Color(0xFF142521),
  sunk: Color(0xFF0A120F),
  ink: Color(0xFFE8EDEA),
  ink2: Color(0xFF9CACA5),
  ink3: Color(0xFF6E7D77),
  hair: Color(0x2EE8EDEA),
  hair2: Color(0x14E8EDEA),
  direct: Color(0xFFFF5B47),
  relay: Color(0xFFFFBB33),
  dim: Color(0xFF6E7D77),
  coin: Color(0xFF6E8CFF),
  bubbleIn: Color(0xFF1C2F2A),
  bubbleOut: Color(0xFFE8EDEA),
  bubbleOutInk: Color(0xFF0C1714),
);

// Android ships Roboto Condensed and Droid Sans Mono, so the DIN/signage role
// and the utility role both render for real without bundling font assets.
// Swap in Archivo Narrow + JetBrains Mono when we next rebuild.
class AppFont {
  static const display = 'sans-serif-condensed';
  static const displayMedium = 'sans-serif-condensed-light';
  static const body = 'sans-serif';
  static const mono = 'monospace';
}

class AppSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 40.0;
}

class AppRadius {
  static const bubble = 13.0;
  static const tail = 4.0;
  static const card = 14.0;
  static const sheet = 18.0;
  static const pill = 20.0;
}

/// Every control clears this. Nav tabs and keypad keys run larger.
const double touchMin = 48;

class AppMotion {
  static const routeDraw = Duration(milliseconds: 420);
  static const arrive = Duration(milliseconds: 180);
  static const sonar = Duration(milliseconds: 2600);
  static const sonarStagger = Duration(milliseconds: 650);
}
