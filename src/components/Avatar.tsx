import { View } from 'react-native';
import { useTheme } from '../styles/theme';
import { Display } from './Type';
import type { Hops } from '../store/types';

/** The ring encodes hop distance, so reachability reads before the name does. */
export default function Avatar({
  initials,
  hops,
  size = 36,
}: {
  initials: string;
  hops: Hops;
  size?: number;
}) {
  const { c } = useTheme();
  const ring = hops === null ? null : hops === 0 ? c.direct : c.relay;
  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        backgroundColor: c.sunk,
        alignItems: 'center',
        justifyContent: 'center',
        opacity: hops === null ? 0.45 : 1,
        borderWidth: ring ? 2 : 0,
        borderColor: ring ?? 'transparent',
      }}
    >
      <Display size={size * 0.39} dim={2}>
        {initials}
      </Display>
    </View>
  );
}
