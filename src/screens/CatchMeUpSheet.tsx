import { useEffect, useRef } from 'react';
import { View, Pressable, Animated, Easing, StyleSheet, ActivityIndicator } from 'react-native';
import { useTheme, radius, TOUCH_MIN } from '../styles/theme';
import { Display, Body, Mono } from '../components/Type';
import { useThreadSummary, SUMMARY_MODEL } from '../features/ai/hooks/useThreadSummary';
import type { Thread } from '../store/types';

/**
 * A small model, running here, summarising what arrived while you had no route.
 * The model name and "nothing left this device" stay on the sheet rather than
 * buried in settings — that claim is the reason this runs locally at all.
 */
export default function CatchMeUpSheet({
  thread,
  unread,
  onClose,
}: {
  thread: Thread;
  unread: number;
  onClose: () => void;
}) {
  const { c } = useTheme();
  const rise = useRef(new Animated.Value(0)).current;
  const started = useRef(false);
  const { lines, summarise, isReady, isGenerating, downloadProgress, done, tookMs, error } =
    useThreadSummary({ enabled: true });

  useEffect(() => {
    Animated.timing(rise, {
      toValue: 1,
      duration: 220,
      easing: Easing.bezier(0.2, 0.8, 0.2, 1),
      useNativeDriver: true,
    }).start();
  }, [rise]);

  // Run as soon as the model is in RAM; nobody wants a second button here.
  useEffect(() => {
    if (isReady && !started.current) {
      started.current = true;
      summarise(thread, unread);
    }
  }, [isReady, summarise, thread, unread]);

  const retry = () => {
    started.current = true;
    summarise(thread, unread);
  };

  const pct = Math.round((downloadProgress ?? 0) * 100);

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
          Catch me up · {SUMMARY_MODEL}
        </Mono>
        <Display size={23}>
          {unread} message{unread === 1 ? '' : 's'} while you were out of range.
        </Display>

        {error ? (
          <View style={{ gap: 10 }}>
            <Body size={12.5} color={c.direct}>
              The summary did not finish. Every message is still in the thread above.
            </Body>
            <Mono size={8.5}>{error.slice(0, 120).toUpperCase()}</Mono>
            <Pressable
              onPress={retry}
              accessibilityRole="button"
              style={[s.btn, { borderWidth: 1.5, borderColor: c.hair }]}
            >
              <Display size={14}>Try again</Display>
            </Pressable>
          </View>
        ) : !isReady ? (
          <View style={s.waiting}>
            <ActivityIndicator color={c.ink3} />
            <View style={{ flex: 1 }}>
              <Body size={12.5} dim={2}>
                {pct > 0 && pct < 100
                  ? 'Fetching the model once. After this it runs with no network at all.'
                  : 'Loading the model onto this phone.'}
              </Body>
              {pct > 0 && pct < 100 ? <Mono size={8.5}>{pct}%</Mono> : null}
            </View>
          </View>
        ) : (
          <View style={{ gap: 12 }}>
            {lines.map((line, i) => (
              <View key={i} style={s.point}>
                <View style={[s.tick, { backgroundColor: c.relay }]} />
                <Body size={12.5} style={{ flex: 1 }}>
                  {line}
                </Body>
              </View>
            ))}
            {isGenerating ? (
              <View style={s.waiting}>
                <ActivityIndicator color={c.ink3} size="small" />
                <Mono size={8.5}>READING {unread} MESSAGES</Mono>
              </View>
            ) : null}
          </View>
        )}

        <Mono size={8.5}>
          NOTHING LEFT THIS DEVICE{done && tookMs ? ` · ${(tookMs / 1000).toFixed(1)} S` : ''}
        </Mono>

        <Pressable onPress={onClose} accessibilityRole="button" style={[s.btn, { backgroundColor: c.ink }]}>
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
  point: { flexDirection: 'row', gap: 9, alignItems: 'flex-start' },
  tick: { width: 6, height: 6, borderRadius: 3, marginTop: 6 },
  waiting: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  btn: { borderRadius: 10, paddingVertical: 12, alignItems: 'center', justifyContent: 'center', minHeight: TOUCH_MIN },
  caps: { textTransform: 'uppercase' },
});
