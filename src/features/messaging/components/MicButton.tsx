// Press and hold to talk. Slide up to lock, slide left to throw it away.
//
// Always in the composer, never swapped out for send: a landed transcript fills
// the draft, so a mic that hid itself on non-empty text could only ever be used
// once per message — no second sentence, no fixing one it got wrong.
// Gestures are PanResponder + Animated on the native driver — gesture-handler
// and reanimated are not in this build, and adding them means a new APK.
//
// Every gesture here has a tappable twin: locking is what makes Stop and Cancel
// reachable as ordinary buttons, and TalkBack's activate goes straight there.
import { useEffect, useRef } from 'react';
import { Animated, Easing, PanResponder, Pressable, StyleSheet, View } from 'react-native';
import { useTheme, TOUCH_MIN } from '../../../styles/theme';
import { Display, Mono } from '../../../components/Type';
import { gesturePhase, progressPercent } from '../../../utils/dictation';
import type { DictationPhase } from '../../ai/types';

type Props = {
  phase: DictationPhase;
  /** Model still loading, or dictation is unavailable on this phone. */
  disabled: boolean;
  /** Sentence-style, and already carries the state — "Loading model 42%". */
  label: string;
  /**
   * Set only while the speech model has not been opted into. The control then
   * offers that download instead of recording — a deliberate tap, never a side
   * effect of opening a chat.
   */
  onSetup?: () => void;
  /** 0..1 while that download runs, `null` when it is not running. */
  setupProgress?: number | null;
  onStart: () => void;
  onLock: () => void;
  onStop: () => void;
  onCancel: () => void;
};

/** The composer's round-button footprint, matched to `ChatScreen`'s `s.rbtn`. */
const SIZE = 40;

/** Enough slop to clear the 48 dp target without growing the composer row. */
const SLOP = (TOUCH_MIN - SIZE) / 2;
const hitSlop = { top: SLOP, bottom: SLOP, left: SLOP, right: SLOP };

export default function MicButton({
  phase,
  disabled,
  label,
  onSetup,
  setupProgress = null,
  onStart,
  onLock,
  onStop,
  onCancel,
}: Props) {
  const { c } = useTheme();

  // The PanResponder is built once, so it would otherwise hold the first
  // render's props forever.
  const live = useRef({ phase, disabled, onStart, onLock, onStop, onCancel });
  live.current = { phase, disabled, onStart, onLock, onStop, onCancel };

  // Gesture-local truth. Props lag by a render, and a release that lands before
  // the state commits would otherwise leave the microphone open forever.
  const take = useRef({ held: false, locked: false, cancelled: false });

  const pan = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () =>
        !live.current.disabled && live.current.phase === 'idle',
      onMoveShouldSetPanResponder: () => take.current.held,

      onPanResponderGrant: () => {
        take.current = { held: true, locked: false, cancelled: false };
        live.current.onStart();
      },

      onPanResponderMove: (_e, g) => {
        const t = take.current;
        if (!t.held || t.cancelled) return;

        const next = gesturePhase({ dx: g.dx, dy: g.dy }, t.locked);
        if (next === 'armed-cancel') {
          t.cancelled = true;
          live.current.onCancel();
        } else if (next === 'armed-lock') {
          t.locked = true;
          live.current.onLock();
        }
      },

      onPanResponderRelease: () => {
        const t = take.current;
        if (!t.held) return;
        t.held = false;
        // A locked take outliving the finger is the whole point of locking.
        if (t.cancelled || t.locked) return;
        live.current.onStop();
      },

      // The gesture was taken away — a call, a system sheet. Nobody is holding
      // the phone to their mouth any more, so keeping the take is a lie.
      onPanResponderTerminate: () => {
        const t = take.current;
        if (!t.held) return;
        t.held = false;
        if (t.cancelled || t.locked) return;
        live.current.onCancel();
      },
      onPanResponderTerminationRequest: () => false,
    })
  ).current;

  const pulse = useRef(new Animated.Value(1)).current;
  useEffect(() => {
    if (phase !== 'recording') return;

    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, {
          toValue: 1.14,
          duration: 520,
          easing: Easing.inOut(Easing.quad),
          useNativeDriver: true,
        }),
        Animated.timing(pulse, {
          toValue: 1,
          duration: 520,
          easing: Easing.inOut(Easing.quad),
          useNativeDriver: true,
        }),
      ])
    );
    loop.start();
    return () => {
      loop.stop();
      pulse.setValue(1);
    };
  }, [phase, pulse]);

  // Nothing to hold yet. Whisper is 224 MB, so the first interaction is a plain
  // tap that asks for it — an arrow, not a mic, because holding this does
  // nothing. A hold gesture that silently starts a quarter-gigabyte download is
  // not a gesture anyone consented to.
  if (onSetup) {
    const busy = setupProgress !== null;

    return (
      <Pressable
        onPress={onSetup}
        disabled={busy}
        hitSlop={hitSlop}
        accessibilityRole="button"
        accessibilityLabel={label}
        accessibilityState={{ disabled: busy, busy }}
        style={[s.btn, { borderColor: c.hair, opacity: busy ? 0.5 : 1 }]}
      >
        {busy ? (
          <Mono size={9} color={c.ink2}>
            {progressPercent(setupProgress)}
          </Mono>
        ) : (
          <Display size={15} dim={2}>
            ↓
          </Display>
        )}
      </Pressable>
    );
  }

  // Hands-free: the finger is gone, so both ways out have to be buttons.
  if (phase === 'locked') {
    return (
      <View style={s.locked}>
        <Pressable
          onPress={onCancel}
          hitSlop={hitSlop}
          accessibilityRole="button"
          accessibilityLabel="Discard this recording"
          style={[s.lbtn, { borderColor: c.hair, borderWidth: 1.5 }]}
        >
          <Mono size={8.5} color={c.ink2}>
            CANCEL
          </Mono>
        </Pressable>
        <Pressable
          onPress={onStop}
          hitSlop={hitSlop}
          accessibilityRole="button"
          accessibilityLabel="Stop recording and write it into the message"
          style={[s.lbtn, { backgroundColor: c.direct }]}
        >
          <Mono size={8.5} color="#fff">
            STOP
          </Mono>
        </Pressable>
      </View>
    );
  }

  const on = phase === 'recording';

  return (
    <Animated.View
      {...pan.panHandlers}
      accessible
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled, busy: phase === 'transcribing' }}
      // TalkBack turns a double tap into a click, which no PanResponder ever
      // sees. Start the take and lock it immediately, so the screen-reader path
      // lands on the Stop and Cancel buttons instead of a hold it cannot do.
      accessibilityActions={[{ name: 'activate', label: 'Start recording' }]}
      onAccessibilityAction={(e) => {
        if (e.nativeEvent.actionName !== 'activate' || disabled || phase !== 'idle') return;
        onStart();
        onLock();
      }}
      hitSlop={hitSlop}
      style={[
        s.btn,
        {
          backgroundColor: on ? c.direct : 'transparent',
          borderColor: on ? c.direct : c.hair,
          opacity: disabled ? 0.4 : 1,
          transform: [{ scale: pulse }],
        },
      ]}
    >
      <MicGlyph color={on ? '#fff' : c.ink2} />
    </Animated.View>
  );
}

/** Drawn, not an icon font or an emoji — the rest of the chrome is drawn too. */
function MicGlyph({ color }: { color: string }) {
  return (
    <View style={s.glyph}>
      <View style={[s.capsule, { backgroundColor: color }]} />
      <View style={[s.stem, { backgroundColor: color }]} />
      <View style={[s.base, { backgroundColor: color }]} />
    </View>
  );
}

const s = StyleSheet.create({
  btn: {
    width: SIZE,
    height: SIZE,
    borderRadius: SIZE / 2,
    borderWidth: 1.5,
    alignItems: 'center',
    justifyContent: 'center',
  },
  locked: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  lbtn: {
    height: SIZE,
    paddingHorizontal: 12,
    borderRadius: SIZE / 2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  glyph: { alignItems: 'center', justifyContent: 'center' },
  capsule: { width: 7, height: 11, borderRadius: 3.5 },
  stem: { width: 1.5, height: 3 },
  base: { width: 11, height: 1.5, borderRadius: 1 },
});
