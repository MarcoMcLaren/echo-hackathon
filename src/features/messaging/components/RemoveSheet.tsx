import { useEffect, useRef } from 'react';
import { View, Pressable, Animated, Easing, StyleSheet } from 'react-native';
import { useTheme, radius, TOUCH_MIN } from '../../../styles/theme';
import { Display, Body, Mono } from '../../../components/Type';
import type { Thread } from '../../../store/types';

/**
 * Removing someone deletes a conversation, so it asks first and says exactly
 * what will happen — including that it is reversible, which is the thing that
 * makes the decision easy.
 */
export default function RemoveSheet({
  thread,
  onCancel,
  onConfirm,
}: {
  thread: Thread;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  const { c } = useTheme();
  const rise = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(rise, {
      toValue: 1,
      duration: 200,
      easing: Easing.bezier(0.2, 0.8, 0.2, 1),
      useNativeDriver: true,
    }).start();
  }, [rise]);

  const isGroup = Boolean(thread.group);

  return (
    <View style={s.overlay} pointerEvents="box-none">
      <Pressable style={s.scrim} onPress={onCancel} accessibilityLabel="Keep this conversation" />
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

        <Display size={24}>{isGroup ? `Leave ${thread.title}?` : `Remove ${thread.title}?`}</Display>

        <Body size={13} dim={2}>
          {isGroup
            ? 'The conversation goes from this phone. The others keep theirs, and you can be added again.'
            : 'This deletes the conversation and stops the two phones connecting. Tap or scan to pair again whenever you want.'}
        </Body>

        <Pressable
          onPress={onConfirm}
          accessibilityRole="button"
          style={[s.btn, { backgroundColor: c.direct }]}
        >
          <Display size={15} color="#fff">
            {isGroup ? 'Leave group' : 'Remove'}
          </Display>
        </Pressable>

        <Pressable
          onPress={onCancel}
          accessibilityRole="button"
          style={[s.btn, s.ghost, { borderColor: c.hair }]}
        >
          <Display size={15}>Keep it</Display>
        </Pressable>

        {isGroup ? null : (
          <Mono size={8.5} style={{ alignSelf: 'center' }}>
            ECHOCOIN ALREADY SENT IS NOT UNDONE
          </Mono>
        )}
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
