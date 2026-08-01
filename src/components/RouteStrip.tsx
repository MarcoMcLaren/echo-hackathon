// THE SIGNATURE COMPONENT.
//
// A three-dot transit line showing the path a message actually took. Chat apps
// hide delivery behind a tick; here the path is the point, so the path is on
// screen. Flutter must match this pixel for pixel — dot sizes, segment length
// and hop colour. It is the screenshot that ends up in the pitch.
import { useEffect, useRef } from 'react';
import { View, Animated, Easing, StyleSheet } from 'react-native';
import { useTheme, motion } from '../styles/theme';
import { Mono } from './Type';
import type { Hops } from '../store/mock';

type Props = {
  hops: Hops;
  via?: string;
  label?: string;
  /** Draws itself left to right once, for a message that just landed. */
  animate?: boolean;
  big?: boolean;
};

export default function RouteStrip({ hops, via, label, animate, big }: Props) {
  const { c } = useTheme();
  const grow = useRef(new Animated.Value(animate ? 0 : 1)).current;

  useEffect(() => {
    if (!animate) return;
    Animated.timing(grow, {
      toValue: 1,
      duration: motion.routeDraw,
      easing: Easing.bezier(0.65, 0, 0.35, 1),
      useNativeDriver: true,
    }).start();
  }, [animate, grow]);

  const D = big ? 11 : 6;
  const SEG = big ? 34 : 14;
  const W = big ? 2.5 : 1.5;

  const unreachable = hops === null;
  const line = unreachable ? c.dim : hops === 0 ? c.direct : c.relay;
  const relayed = hops !== null && hops > 0;

  const dot = (fill: string, hollow?: boolean) => (
    <View
      style={{
        width: D,
        height: D,
        borderRadius: D / 2,
        backgroundColor: hollow ? c.paper : fill,
        borderWidth: hollow ? W : 0,
        borderColor: fill,
      }}
    />
  );
  const seg = <View style={{ width: SEG, height: W, backgroundColor: line }} />;

  return (
    <Animated.View
      style={[
        s.row,
        { opacity: unreachable ? 0.45 : 1 },
        animate && {
          transform: [{ scaleX: grow }],
          transformOrigin: 'left',
        },
      ]}
    >
      {/* sender ... relay ... you */}
      {dot(unreachable ? c.dim : c.direct)}
      {seg}
      {relayed ? (
        <>
          {dot(c.relay, true)}
          {seg}
        </>
      ) : null}
      {dot(unreachable ? c.dim : c.ink)}
      {label || via ? (
        <Mono size={big ? 10 : 8.5} style={{ marginLeft: 7 }}>
          {label ?? `VIA ${via!.toUpperCase()}`}
        </Mono>
      ) : null}
    </Animated.View>
  );
}

const s = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center' },
});
