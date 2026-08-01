import { useEffect, useRef } from 'react';
import { View, Pressable, Animated, Easing, StyleSheet } from 'react-native';
import { useTheme, radius } from '../styles/theme';
import { Display, Body, Mono } from '../components/Type';
import { summary } from '../store/mock';

/**
 * The local model summarises what you missed while you had no route.
 * The model name and "nothing left this device" stay on the sheet, not buried in
 * settings — the claim of on-device is worth nothing if the UI doesn't show it.
 */
export default function CatchMeUpSheet({ onClose }: { onClose: () => void }) {
  const { c } = useTheme();
  const rise = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(rise, {
      toValue: 1,
      duration: 220,
      easing: Easing.bezier(0.2, 0.8, 0.2, 1),
      useNativeDriver: true,
    }).start();
  }, [rise]);

  return (
    <View style={s.overlay} pointerEvents="box-none">
      <Pressable style={s.scrim} onPress={onClose} accessibilityLabel="Close summary" />
      <Animated.View
        style={[
          s.sheet,
          {
            backgroundColor: c.card,
            borderColor: c.hair,
            opacity: rise,
            transform: [{ translateY: rise.interpolate({ inputRange: [0, 1], outputRange: [40, 0] }) }],
          },
        ]}
      >
        <View style={[s.grab, { backgroundColor: c.hair }]} />
        <Mono size={10} style={s.caps}>
          Catch me up · {summary.model}
        </Mono>
        <Display size={23}>{summary.count} messages while you were out of range.</Display>

        <View style={{ gap: 12 }}>
          {summary.points.map((p) => (
            <View key={p.k} style={s.point}>
              <Mono size={8.5} style={s.k}>
                {p.k}
              </Mono>
              <Body size={12.5} style={{ flex: 1 }}>
                {p.text}
              </Body>
            </View>
          ))}
        </View>

        <Mono size={8.5}>NOTHING LEFT THIS DEVICE · {summary.took}</Mono>

        <Pressable
          onPress={onClose}
          accessibilityRole="button"
          style={[s.btn, { backgroundColor: c.ink }]}
        >
          <Display size={14} color={c.paper}>
            Back to chat
          </Display>
        </Pressable>
      </Animated.View>
    </View>
  );
}

const s = StyleSheet.create({
  overlay: { position: 'absolute', top: 0, right: 0, bottom: 0, left: 0, justifyContent: 'flex-end' },
  scrim: { position: 'absolute', top: 0, right: 0, bottom: 0, left: 0, backgroundColor: 'rgba(13,26,22,0.45)' },
  sheet: {
    borderTopLeftRadius: radius.sheet,
    borderTopRightRadius: radius.sheet,
    borderWidth: 1,
    padding: 16,
    paddingBottom: 22,
    gap: 12,
  },
  grab: { width: 34, height: 3, borderRadius: 2, alignSelf: 'center', marginBottom: 2 },
  point: { flexDirection: 'row', gap: 9 },
  k: { width: 38, paddingTop: 3 },
  btn: { borderRadius: 10, paddingVertical: 12, alignItems: 'center', minHeight: 48, justifyContent: 'center' },
  caps: { textTransform: 'uppercase' },
});
