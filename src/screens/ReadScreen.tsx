// "Read that" — point the phone at text, tap once, hear it read back.
//
// The whole round trip is on-device: expo-camera snapshot -> executorch OCR ->
// OS text-to-speech. Speech is the real output; the transcript panel is there
// for sighted onlookers and for the demo.
import { useCallback, useEffect, useRef, useState } from 'react';
import { AppState, Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { useTheme, radius, TOUCH_MIN } from '../styles/theme';
import { Display, Body, Mono } from '../components/Type';
import { MeshStatus, AppBar } from '../components/Chrome';
import { useReadText } from '../features/ai/hooks/useReadText';
import {
  maxSpeechChars,
  notifyFail,
  notifyOk,
  speak,
  stopSpeaking,
  tick,
} from '../features/feedback/api';

const NOTHING = 'No text found.';
const BROKE = "Couldn't read that.";
const UNAVAILABLE = 'Reader unavailable.';

type Props = {
  /** Lets the shell lock navigation while a read is in flight — unmounting
   *  mid-read makes executorch's cleanup throw ModelGenerating. */
  onBusyChange?: (busy: boolean) => void;
};

export default function ReadScreen({ onBusyChange }: Props) {
  const [permission, requestPermission, getPermission] = useCameraPermissions();
  // Granting permission in Android Settings does not remount us, so without
  // this the screen stays stuck on the denied branch after the user returns.
  useEffect(() => {
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'active') void getPermission();
    });
    return () => sub.remove();
  }, [getPermission]);

  // Bumping this remounts Reader, which is the only way to make useOCR retry a
  // failed load — the controller reloads on mount.
  const [attempt, setAttempt] = useState(0);
  const retry = useCallback(() => setAttempt((a) => a + 1), []);

  const header = <AppBar title="Read that" sub="Point at text and tap to hear it" />;

  if (!permission) {
    return (
      <>
        <MeshStatus right="ON-DEVICE OCR" state="starting" />
        {header}
        <View style={s.zone}>
          <Mono size={10}>STARTING CAMERA</Mono>
        </View>
      </>
    );
  }

  if (!permission.granted) {
    return (
      <>
        <MeshStatus right="CAMERA BLOCKED" state="error" />
        {header}
        <View style={s.zone}>
          <Display size={26} style={s.h}>
            Echo needs the camera to read text
          </Display>
          <Body size={13} dim={2} style={s.p}>
            {permission.canAskAgain
              ? 'It is used only while this screen is open. Nothing leaves the phone.'
              : 'Camera access was turned off. Enable it for Echo in Android Settings › Apps › Echo › Permissions, then come back.'}
          </Body>
          {permission.canAskAgain ? (
            <PrimaryButton label="Allow camera" onPress={requestPermission} />
          ) : null}
        </View>
      </>
    );
  }

  return <Reader key={attempt} onRetry={retry} onBusyChange={onBusyChange} />;
}

/** Split out so a retry can remount it — and so the OCR models only ever load
 *  once camera permission is actually granted. */
function Reader({
  onRetry,
  onBusyChange,
}: {
  onRetry: () => void;
  onBusyChange?: (busy: boolean) => void;
}) {
  const { c } = useTheme();
  const camera = useRef<CameraView>(null);
  const [camReady, setCamReady] = useState(false);
  const [camError, setCamError] = useState(false);
  const [capturing, setCapturing] = useState(false);
  const { isReady, isBusy, downloadProgress, error, transcript, read } =
    useReadText(maxSpeechChars);

  const mounted = useRef(true);
  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
      void stopSpeaking();
    };
  }, []);

  // Capturing and inferring are separate waits; the shell cares about both.
  const busy = capturing || isBusy;
  useEffect(() => {
    onBusyChange?.(busy);
  }, [busy, onBusyChange]);
  useEffect(
    () => () => {
      onBusyChange?.(false);
    },
    [onBusyChange]
  );

  const loadFailed = Boolean(error) && !isReady;

  // Speech is the primary channel, so a dead model must be heard, not just
  // shown in red. Announce each distinct failure once.
  const announced = useRef<string | null>(null);
  useEffect(() => {
    if (!loadFailed || announced.current === error) return;
    announced.current = error;
    void (async () => {
      await notifyFail();
      await speak(UNAVAILABLE);
    })();
  }, [loadFailed, error]);

  // A ref, not state: two taps in one event batch both see the same render.
  const latch = useRef(false);
  const canRead = isReady && !busy && camReady && !camError;
  const pct = Math.round(downloadProgress * 100);

  const onRead = useCallback(async () => {
    if (latch.current || !canRead) return;
    const cam = camera.current;
    if (!cam) {
      // Enabled button with no camera would otherwise be a silent dead tap.
      await notifyFail();
      await speak(BROKE);
      return;
    }

    latch.current = true;
    setCapturing(true);
    try {
      await tick();
      const shot = await cam.takePictureAsync({
        quality: 0.6,
        shutterSound: false,
        // skipProcessing stays off deliberately: on Android it hands back the
        // sensor frame without EXIF rotation applied, so OCR would be reading a
        // sideways image. One user-initiated shot can afford the processing.
      });
      if (!shot?.uri) throw new Error('Capture returned no image');

      const outcome = await read(shot.uri);
      // Left the tab mid-read: staying silent beats buzzing and talking over
      // whatever screen the user is on now.
      if (!mounted.current || outcome.status === 'skipped') return;
      if (outcome.status === 'failed') {
        await notifyFail();
        await speak(BROKE);
        return;
      }
      // Empty text is a successful read that found no words — a different
      // outcome from failure, so it keeps the success haptic.
      await notifyOk();
      await speak(outcome.result.text || NOTHING);
    } catch {
      if (!mounted.current) return;
      await notifyFail();
      await speak(BROKE);
    } finally {
      latch.current = false;
      if (mounted.current) setCapturing(false);
    }
  }, [canRead, read]);

  let buttonLabel: string;
  if (loadFailed || camError) buttonLabel = 'Reader unavailable';
  else if (!isReady) buttonLabel = `Loading model ${pct}%`;
  else if (!camReady) buttonLabel = 'Starting camera';
  else if (busy) buttonLabel = 'Reading…';
  else buttonLabel = 'Read that';

  let statusRight: string;
  if (loadFailed || camError) statusRight = 'READER UNAVAILABLE';
  else if (!isReady) statusRight = `LOADING MODEL ${pct}%`;
  else statusRight = 'ON-DEVICE OCR · OFFLINE';

  let panelHead: string;
  if (error) panelHead = 'ERROR';
  else if (transcript === null) panelHead = 'NOTHING READ YET';
  else panelHead = 'LAST READ';

  let panelBody: string;
  if (error) panelBody = error;
  else if (transcript === null) panelBody = 'Point at a sign, a label or a page.';
  else panelBody = transcript || NOTHING;

  return (
    <>
      <MeshStatus
        right={statusRight}
        state={loadFailed || camError ? 'error' : isReady ? 'live' : 'starting'}
      />
      <AppBar title="Read that" sub="Point at text and tap to hear it" />

      <View style={[s.preview, { borderColor: c.hair }]}>
        <CameraView
          ref={camera}
          style={StyleSheet.absoluteFill}
          facing="back"
          animateShutter={false}
          onCameraReady={() => setCamReady(true)}
          onMountError={() => setCamError(true)}
        />
      </View>

      <View style={[s.panel, { backgroundColor: c.card, borderColor: c.hair2 }]}>
        <Mono size={8.5} style={s.caps}>
          {panelHead}
        </Mono>
        {/* No accessibilityLiveRegion here on purpose: TalkBack would recite
            the transcript at the same time expo-speech is reading it. */}
        <ScrollView style={s.scroll} contentContainerStyle={s.scrollBody}>
          <Body size={15} dim={transcript ? undefined : 2} color={error ? c.direct : undefined}>
            {panelBody}
          </Body>
        </ScrollView>
      </View>

      <View style={s.foot}>
        {loadFailed || camError ? (
          <PrimaryButton label="Retry" onPress={onRetry} />
        ) : (
          <Pressable
            onPress={onRead}
            disabled={!canRead}
            accessibilityRole="button"
            accessibilityLabel={buttonLabel}
            accessibilityState={{ disabled: !canRead, busy }}
            style={[s.read, { backgroundColor: canRead ? c.ink : c.sunk }]}
          >
            <Display size={19} color={canRead ? c.paper : c.ink3}>
              {buttonLabel}
            </Display>
          </Pressable>
        )}
      </View>
    </>
  );
}

function PrimaryButton({ label, onPress }: { label: string; onPress: () => void }) {
  const { c } = useTheme();
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={label}
      style={[s.read, { backgroundColor: c.ink }]}
    >
      <Display size={19} color={c.paper}>
        {label}
      </Display>
    </Pressable>
  );
}

const s = StyleSheet.create({
  zone: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 16, paddingHorizontal: 26 },
  h: { textAlign: 'center', maxWidth: 260, lineHeight: 30 },
  p: { textAlign: 'center', maxWidth: 270 },
  preview: {
    flex: 1,
    margin: 14,
    borderRadius: radius.card,
    borderWidth: 1,
    overflow: 'hidden',
    backgroundColor: '#000',
  },
  panel: {
    marginHorizontal: 14,
    padding: 12,
    borderRadius: radius.card,
    borderWidth: 1,
    gap: 6,
    maxHeight: 148,
  },
  caps: { textTransform: 'uppercase' },
  scroll: { flexGrow: 0 },
  scrollBody: { paddingRight: 4 },
  foot: { paddingHorizontal: 14, paddingTop: 12, paddingBottom: 12 },
  read: {
    borderRadius: radius.card,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: Math.max(68, TOUCH_MIN),
  },
});
