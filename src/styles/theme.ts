// Echo design tokens.
//
// The three signal colours are ONE SCALE, not three accents:
//   direct -> relay -> dim  encodes hop distance (here / routed / unreachable).
// `coin` sits outside that scale because money is not a distance. It must never
// be used for signal or state, and nothing else may use it.
import { createContext, useContext } from 'react';

export type Palette = {
  paper: string;
  card: string;
  sunk: string;
  ink: string;
  ink2: string;
  ink3: string;
  hair: string;
  hair2: string;
  direct: string;
  relay: string;
  dim: string;
  coin: string;
  bubbleIn: string;
  bubbleOut: string;
  bubbleOutInk: string;
};

export const light: Palette = {
  paper: '#E6EAE7',
  card: '#FFFFFF',
  sunk: '#DCE2DE',
  ink: '#0D1A16',
  ink2: '#54635D',
  ink3: '#8C9791',
  hair: 'rgba(13,26,22,0.16)',
  hair2: 'rgba(13,26,22,0.08)',
  direct: '#EE3E2B',
  relay: '#F2A007',
  dim: '#8C9791',
  coin: '#2340D6',
  bubbleIn: '#FFFFFF',
  bubbleOut: '#0D1A16',
  bubbleOutInk: '#F2F5F3',
};

export const dark: Palette = {
  paper: '#0C1714',
  card: '#142521',
  sunk: '#0A120F',
  ink: '#E8EDEA',
  ink2: '#9CACA5',
  ink3: '#6E7D77',
  hair: 'rgba(232,237,234,0.18)',
  hair2: 'rgba(232,237,234,0.08)',
  direct: '#FF5B47',
  relay: '#FFBB33',
  dim: '#6E7D77',
  coin: '#6E8CFF',
  bubbleIn: '#1C2F2A',
  bubbleOut: '#E8EDEA',
  bubbleOutInk: '#0C1714',
};

// Android ships Roboto Condensed and Droid Sans Mono, so the DIN/signage role and
// the utility role both render for real without bundling font files (which would
// need expo-font and a new dev-client APK). Swap in Archivo Narrow + JetBrains
// Mono when we next rebuild.
export const font = {
  display: 'sans-serif-condensed',
  displayMedium: 'sans-serif-condensed-light',
  body: 'sans-serif',
  mono: 'monospace',
} as const;

export const space = { xs: 4, s: 8, m: 12, l: 16, xl: 24, xxl: 40 } as const;

export const radius = {
  bubble: 13,
  tail: 4,
  card: 14,
  sheet: 18,
  pill: 20,
} as const;

/** Every control clears this. Nav tabs and keypad keys run larger. */
export const TOUCH_MIN = 48;

export const motion = {
  routeDraw: 420,
  arrive: 180,
  sonar: 2600,
  sonarStagger: 650,
} as const;

export type Mode = 'system' | 'light' | 'dark';

export const ThemeContext = createContext<{
  c: Palette;
  isDark: boolean;
  mode: Mode;
  cycle: () => void;
}>({
  c: light,
  isDark: false,
  mode: 'system',
  cycle: () => {},
});

export const useTheme = () => useContext(ThemeContext);
