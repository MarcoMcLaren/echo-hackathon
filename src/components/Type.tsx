import { Text, TextProps, StyleSheet } from 'react-native';
import { font, useTheme } from '../styles/theme';

type Props = TextProps & { size?: number; color?: string; dim?: 1 | 2 | 3 };

const ink = (dim: 1 | 2 | 3 | undefined, c: any) =>
  dim === 3 ? c.ink3 : dim === 2 ? c.ink2 : c.ink;

/** Signage face. Titles, balances, buttons, station labels. */
export function Display({ size = 18, color, dim, style, ...p }: Props) {
  const { c } = useTheme();
  return (
    <Text
      {...p}
      style={[
        { fontFamily: font.display, fontSize: size, color: color ?? ink(dim, c), letterSpacing: 0.2 },
        style,
      ]}
    />
  );
}

/** Anything read as a sentence. Never below 12.5 inside a bubble. */
export function Body({ size = 13, color, dim, style, ...p }: Props) {
  const { c } = useTheme();
  return (
    <Text
      {...p}
      style={[{ fontFamily: font.body, fontSize: size, color: color ?? ink(dim, c), lineHeight: size * 1.42 }, style]}
    />
  );
}

/** Everything the mesh reports about itself: hops, signal, times, amounts. */
export function Mono({ size = 9, color, dim = 3, style, ...p }: Props) {
  const { c } = useTheme();
  return (
    <Text
      {...p}
      style={[
        {
          fontFamily: font.mono,
          fontSize: size,
          color: color ?? ink(dim, c),
          letterSpacing: size * 0.09,
        },
        style,
      ]}
    />
  );
}

/** The echocoin mark: a ring with an E in it. Ultramarine, money only. */
export function CoinMark({ size = 14, color }: { size?: number; color?: string }) {
  const { c } = useTheme();
  const col = color ?? c.coin;
  return (
    <Text
      style={{
        fontFamily: font.display,
        fontSize: size * 0.62,
        lineHeight: size,
        width: size,
        height: size,
        borderRadius: size / 2,
        borderWidth: Math.max(1, size * 0.09),
        borderColor: col,
        color: col,
        textAlign: 'center',
        overflow: 'hidden',
      }}
    >
      E
    </Text>
  );
}

export const t = StyleSheet.create({
  caps: { textTransform: 'uppercase' },
});
