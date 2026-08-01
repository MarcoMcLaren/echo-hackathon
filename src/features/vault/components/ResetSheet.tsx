import { useEffect, useRef, useState } from 'react';
import { View, Pressable, Animated, Easing, StyleSheet } from 'react-native';
import { useTheme, radius, TOUCH_MIN } from '../../../styles/theme';
import { Display, Body, Mono } from '../../../components/Type';

/**
 * Wiping the phone is not undoable, so it says exactly what goes and asks
 * twice — once by opening this, once by pressing the red button. The second
 * press is the one that means it.
 */
export default function ResetSheet({
  onCancel,
  onConfirm,
}: {
  onCancel: () => void;
  onConfirm: () => void;
}) {
  const { c } = useTheme();
  const rise = useRef(new Animated.Value(0)).current;
  const [armed, setArmed] = useState(false);

  useEffect(() => {
    Animated.timing(rise, {
      toValue: 1,
      duration: 200,
      easing: Easing.bezier(0.2, 0.8, 0.2, 1),
      useNativeDriver: true,
    }).start();
  }, [rise]);

  return (
    <View style={s.overlay} pointerEvents="box-none">
      <Pressable style={s.scrim} onPress={onCancel} accessibilityLabel="Keep everything" />
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

        <Display size={26}>Reset this phone?</Display>

        <Body size={13} dim={2}>
          Your name, your key, your contacts and every conversation go. This phone gets a brand new
          identity, so to everyone who paired with it you become a stranger — they will have to add
          you again.
        </Body>

        <View style={{ gap: 4 }}>
          <Mono size={8.5}>· NAME AND KEY REPLACED</Mono>
          <Mono size={8.5}>· ALL CONTACTS FORGOTTEN</Mono>
          <Mono size={8.5}>· ALL MESSAGES AND ECHOCOIN HISTORY GONE</Mono>
        </View>

        <Pressable
          onPress={() => (armed ? onConfirm() : setArmed(true))}
          accessibilityRole="button"
          style={[s.btn, { backgroundColor: armed ? c.direct : 'transparent', borderWidth: armed ? 0 : 1.5, borderColor: c.direct }]}
        >
          <Display size={15} color={armed ? '#fff' : c.direct}>
            {armed ? 'Yes, erase everything' : 'Reset'}
          </Display>
        </Pressable>

        <Pressable onPress={onCancel} accessibilityRole="button" style={[s.btn, s.ghost, { borderColor: c.hair }]}>
          <Display size={15}>Keep everything</Display>
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
    paddingBottom: 24,
    gap: 12,
  },
  grab: { width: 34, height: 3, borderRadius: 2, alignSelf: 'center', marginBottom: 2 },
  btn: { borderRadius: 10, paddingVertical: 13, alignItems: 'center', justifyContent: 'center', minHeight: TOUCH_MIN },
  ghost: { borderWidth: 1.5 },
});
