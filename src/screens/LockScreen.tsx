import { useCallback, useEffect, useRef, useState } from 'react';
import { View, Pressable, Animated, Easing, StyleSheet, AccessibilityInfo } from 'react-native';
import { useTheme, TOUCH_MIN } from '../styles/theme';
import { Display, Body, Mono } from '../components/Type';
import { bottomInset } from '../components/Chrome';
import { unlock, enableLock, isLockEnabled, hasBiometricHardware } from '../features/vault/api/lock';

type Phase =
  | 'checking'
  | 'prompting' // lock is on, waiting for the owner
  | 'locked' // they declined or it failed
  | 'offer' // lock is off — ask before creating anything
  | 'error';

/**
 * The door. Nothing behind it renders until the device owner has proved who
 * they are — a phone left unlocked on a table is exactly the case this covers.
 *
 * On a phone with no fingerprint or PIN set up there is nothing to verify, so
 * this offers rather than insists. Turning the lock on is a deliberate tap,
 * because that is the point where Android may ask the user to enrol a
 * fingerprint, and no app should spring that on someone.
 */
export default function LockScreen({ onUnlocked }: { onUnlocked: () => void }) {
  const { c } = useTheme();
  const [phase, setPhase] = useState<Phase>('checking');
  const [detail, setDetail] = useState<string | null>(null);
  const [hasHardware, setHasHardware] = useState(true);
  const [still, setStill] = useState(false);
  const pulse = useRef(new Animated.Value(0)).current;
  const ran = useRef(false);

  const attemptUnlock = useCallback(async () => {
    setPhase('prompting');
    const result = await unlock();
    if (result.ok) return onUnlocked();
    if (result.reason === 'error') {
      setDetail(result.message ?? null);
      setPhase('error');
    } else {
      setPhase('locked');
    }
  }, [onUnlocked]);

  useEffect(() => {
    AccessibilityInfo.isReduceMotionEnabled().then(setStill);
    if (ran.current) return;
    ran.current = true;
    (async () => {
      setHasHardware(await hasBiometricHardware());
      if (await isLockEnabled()) await attemptUnlock();
      else setPhase('offer');
    })();
  }, [attemptUnlock]);

  const turnOn = async () => {
    setPhase('checking');
    const created = await enableLock();
    if (!created.ok) {
      setDetail(created.message ?? null);
      setPhase(created.reason === 'error' ? 'error' : 'offer');
      return;
    }
    await attemptUnlock();
  };

  useEffect(() => {
    const busy = phase === 'checking' || phase === 'prompting';
    if (still || !busy) return;
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, { toValue: 1, duration: 900, easing: Easing.inOut(Easing.quad), useNativeDriver: true }),
        Animated.timing(pulse, { toValue: 0, duration: 900, easing: Easing.inOut(Easing.quad), useNativeDriver: true }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [phase, still, pulse]);

  const busy = phase === 'checking' || phase === 'prompting';
  const bad = phase === 'error';

  const heading =
    phase === 'offer'
      ? 'Lock Echo to this phone'
      : phase === 'locked'
        ? 'Locked'
        : bad
          ? 'Could not unlock'
          : 'Unlock Echo';

  const blurb =
    phase === 'offer'
      ? hasHardware
        ? 'Ask for a fingerprint or face every time Echo opens, so an unlocked phone on a table is not an open inbox.'
        : 'This phone has no fingerprint or face set up, so there is nothing for Echo to check. Add a screen lock in Settings to use this.'
      : phase === 'locked'
        ? 'Echo stays locked until you confirm it is you.'
        : bad
          ? 'The phone would not complete the check. Make sure a screen lock is set up, then try again.'
          : 'Use your fingerprint or face. Your messages, keys and wallet stay on this phone.';

  return (
    <View style={[s.wrap, { backgroundColor: c.paper }]}>
      <View style={s.mid}>
        <Animated.View
          style={[
            s.mark,
            {
              borderColor: bad ? c.direct : c.ink,
              opacity: still || !busy ? 1 : pulse.interpolate({ inputRange: [0, 1], outputRange: [0.45, 1] }),
            },
          ]}
        >
          <Display size={26} color={bad ? c.direct : c.ink}>
            ◉
          </Display>
        </Animated.View>

        <Display size={34} style={s.h}>
          {heading}
        </Display>
        <Body size={13.5} dim={2} style={s.p}>
          {blurb}
        </Body>
        {bad && detail ? <Mono size={8.5}>{detail.slice(0, 90).toUpperCase()}</Mono> : null}
      </View>

      <View style={s.foot}>
        {phase === 'offer' && hasHardware ? (
          <Pressable onPress={turnOn} accessibilityRole="button" style={[s.btn, { backgroundColor: c.ink }]}>
            <Display size={15} color={c.paper}>
              Turn on unlock
            </Display>
          </Pressable>
        ) : null}

        {phase === 'locked' || bad ? (
          <Pressable onPress={attemptUnlock} accessibilityRole="button" style={[s.btn, { backgroundColor: c.ink }]}>
            <Display size={15} color={c.paper}>
              Try again
            </Display>
          </Pressable>
        ) : null}

        {phase === 'offer' ? (
          <Pressable onPress={onUnlocked} accessibilityRole="button" style={[s.btn, s.ghost, { borderColor: c.hair }]}>
            <Display size={15}>{hasHardware ? 'Not now' : 'Continue without a lock'}</Display>
          </Pressable>
        ) : null}

        <Mono size={8.5} style={{ alignSelf: 'center' }}>
          HARDWARE-BACKED · KEYS NEVER LEAVE THIS PHONE
        </Mono>
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  wrap: { flex: 1, justifyContent: 'space-between', paddingHorizontal: 28, paddingTop: 60 },
  mid: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 18 },
  mark: { width: 84, height: 84, borderRadius: 42, borderWidth: 2, alignItems: 'center', justifyContent: 'center' },
  h: { textAlign: 'center' },
  p: { textAlign: 'center', maxWidth: 300 },
  // This screen renders outside <Screen>, so it carries its own bottom inset.
  foot: { gap: 10, paddingBottom: bottomInset + 24 },
  btn: { borderRadius: 10, paddingVertical: 13, alignItems: 'center', justifyContent: 'center', minHeight: TOUCH_MIN },
  ghost: { borderWidth: 1.5 },
});
