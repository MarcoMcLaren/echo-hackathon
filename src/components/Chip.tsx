import { View, StyleSheet } from 'react-native';
import { useTheme } from '../styles/theme';
import { Mono } from './Type';
import type { Hops } from '../store/types';

/** Hop state as a pill. Colour comes from the one signal scale. */
export function HopChip({ hops, via, label }: { hops: Hops; via?: string; label?: string }) {
  const { c } = useTheme();
  const col = hops === null ? c.dim : hops === 0 ? c.direct : c.relay;
  const text = label ?? (hops === null ? 'No route' : hops === 0 ? 'Direct' : `Via ${via ?? 'relay'}`);
  return (
    <View style={[s.chip, { backgroundColor: col + '22' }]}>
      <Mono size={8.5} color={col} style={s.caps}>
        {text}
      </Mono>
    </View>
  );
}

export function CoinChip({ label }: { label: string }) {
  const { c } = useTheme();
  return (
    <View style={[s.chip, { backgroundColor: c.coin + '1F' }]}>
      <Mono size={8.5} color={c.coin} style={s.caps}>
        {label}
      </Mono>
    </View>
  );
}

const s = StyleSheet.create({
  chip: { paddingHorizontal: 6, paddingVertical: 2, borderRadius: 3 },
  caps: { textTransform: 'uppercase' },
});
