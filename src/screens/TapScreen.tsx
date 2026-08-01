import { useEffect, useRef, useState } from 'react';
import { View, Animated, Easing, Pressable, StyleSheet, AccessibilityInfo } from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { useTheme, motion, radius, TOUCH_MIN } from '../styles/theme';
import { Display, Body, Mono } from '../components/Type';
import { MeshStatus, AppBar, bottomInset } from '../components/Chrome';
import Avatar from '../components/Avatar';
import QrCode from '../features/vault/components/QrCode';

const CORE = 52;
const MAX = 150;

// What the other phone reads. Same payload either way, so NFC and QR are two
// doors into one pairing flow rather than two features.
const MY_PAIR_PAYLOAD = 'echo://pair?id=rf7k2m&k=9fA2c4Be71D0&n=Reon';
const MY_FINGERPRINT = '9FA2 C4BE 71D0';

type Mode = 'tap' | 'show' | 'scan';

export default function TapScreen() {
  const { c } = useTheme();
  const [mode, setMode] = useState<Mode>('tap');
  const [still, setStill] = useState(false);
  const [scanned, setScanned] = useState<string | null>(null);

  useEffect(() => {
    AccessibilityInfo.isReduceMotionEnabled().then(setStill);
    const sub = AccessibilityInfo.addEventListener('reduceMotionChanged', setStill);
    return () => sub.remove();
  }, []);

  const segs: { id: Mode; label: string }[] = [
    { id: 'tap', label: 'TAP' },
    { id: 'show', label: 'SHOW CODE' },
    { id: 'scan', label: 'SCAN' },
  ];

  return (
    <>
      <MeshStatus right={mode === 'tap' ? 'NFC READY' : 'CAMERA PAIRING'} />
      <AppBar title="Meet a phone" sub="Adds a contact and swaps keys" />

      <View style={s.segs}>
        {segs.map((sg) => {
          const on = sg.id === mode;
          return (
            <Pressable
              key={sg.id}
              onPress={() => {
                setMode(sg.id);
                setScanned(null);
              }}
              accessibilityRole="tab"
              accessibilityState={{ selected: on }}
              style={[
                s.seg,
                { borderColor: on ? c.ink : c.hair, backgroundColor: on ? c.ink : 'transparent' },
              ]}
            >
              <Mono size={9} color={on ? c.paper : c.ink2}>
                {sg.label}
              </Mono>
            </Pressable>
          );
        })}
      </View>

      {mode === 'tap' ? (
        <TapMode still={still} />
      ) : mode === 'show' ? (
        <ShowMode />
      ) : (
        <ScanMode scanned={scanned} onScan={setScanned} />
      )}

      <View style={[s.foot, { paddingBottom: bottomInset + 16 }]}>
        <View style={[s.paired, { backgroundColor: c.card, borderColor: c.direct }]}>
          <Avatar initials="SD" hops={0} size={30} />
          <View style={{ flex: 1 }}>
            <Mono size={9} dim={1}>
              PAIRED WITH SIPHO DLAMINI
            </Mono>
            <Mono size={8.5}>KEYS EXCHANGED · SCANNED CODE · 09:47</Mono>
          </View>
        </View>
      </View>
    </>
  );
}

/** NFC: the fastest path when both phones have the hardware. */
function TapMode({ still }: { still: boolean }) {
  return (
    <View style={s.zone}>
      <Sonar still={still} />
      <Display size={28} style={s.h}>
        Hold the phones back to back
      </Display>
      <Body size={13} dim={2} style={s.p}>
        Keep them together until both buzz. Keys are generated and stored on each phone — nothing is
        uploaded.
      </Body>
      <Mono size={9}>WAITING FOR THE OTHER PHONE</Mono>
      <Mono size={9} dim={2}>
        NO NFC ON ONE OF THEM? USE SHOW CODE
      </Mono>
    </View>
  );
}

/** The fallback half you hold up. */
function ShowMode() {
  const { c } = useTheme();
  return (
    <View style={s.zone}>
      <View style={[s.qrPlate, { borderColor: c.hair }]}>
        <QrCode value={MY_PAIR_PAYLOAD} size={196} />
      </View>
      <Display size={26} style={s.h}>
        Let the other phone scan this
      </Display>
      <Body size={13} dim={2} style={s.p}>
        Works on any phone with a camera. The code carries your public key, nothing else.
      </Body>
      <View style={[s.fp, { borderColor: c.hair2, backgroundColor: c.card }]}>
        <Mono size={10} dim={1}>
          {MY_FINGERPRINT}
        </Mono>
      </View>
      <Mono size={8.5}>CHECK THIS MATCHES ON THEIR SCREEN</Mono>
    </View>
  );
}

/** The fallback half that reads. */
function ScanMode({ scanned, onScan }: { scanned: string | null; onScan: (v: string) => void }) {
  const { c } = useTheme();
  const [permission, requestPermission] = useCameraPermissions();

  if (!permission) {
    return (
      <View style={s.zone}>
        <Mono size={10}>STARTING CAMERA</Mono>
      </View>
    );
  }

  if (!permission.granted) {
    return (
      <View style={s.zone}>
        <Display size={26} style={s.h}>
          Echo needs the camera to read a code
        </Display>
        <Body size={13} dim={2} style={s.p}>
          It is used only while this screen is open, and only to find a pairing code.
        </Body>
        <Pressable
          onPress={requestPermission}
          accessibilityRole="button"
          style={[s.btn, { backgroundColor: c.ink }]}
        >
          <Display size={15} color={c.paper}>
            Allow camera
          </Display>
        </Pressable>
      </View>
    );
  }

  if (scanned) {
    const ok = scanned.startsWith('echo://pair');
    return (
      <View style={s.zone}>
        <Display size={28} style={[s.h, { color: ok ? c.ink : c.direct }]}>
          {ok ? 'Code read' : 'That is not an Echo code'}
        </Display>
        <Body size={13} dim={2} style={s.p}>
          {ok
            ? 'Check the fingerprint matches what the other phone shows, then confirm.'
            : 'Point the camera at the code on the other phone’s Show code screen.'}
        </Body>
        {ok ? (
          <View style={[s.fp, { borderColor: c.hair2, backgroundColor: c.card }]}>
            <Mono size={10} dim={1}>
              {MY_FINGERPRINT}
            </Mono>
          </View>
        ) : null}
        <Pressable
          onPress={() => onScan('')}
          accessibilityRole="button"
          style={[s.btn, { backgroundColor: ok ? c.ink : 'transparent', borderWidth: ok ? 0 : 1.5, borderColor: c.hair }]}
        >
          <Display size={15} color={ok ? c.paper : c.ink}>
            {ok ? 'Add contact' : 'Scan again'}
          </Display>
        </Pressable>
      </View>
    );
  }

  return (
    <View style={s.zone}>
      <View style={[s.finder, { borderColor: c.hair }]}>
        <CameraView
          style={StyleSheet.absoluteFill}
          facing="back"
          barcodeScannerSettings={{ barcodeTypes: ['qr'] }}
          onBarcodeScanned={({ data }) => onScan(data)}
        />
        <View style={[s.bracket, s.tl, { borderColor: c.relay }]} />
        <View style={[s.bracket, s.tr, { borderColor: c.relay }]} />
        <View style={[s.bracket, s.bl, { borderColor: c.relay }]} />
        <View style={[s.bracket, s.br, { borderColor: c.relay }]} />
      </View>
      <Display size={26} style={s.h}>
        Point at their code
      </Display>
      <Mono size={9}>LOOKING FOR AN ECHO CODE</Mono>
    </View>
  );
}

/** Three staggered rings — the only looping animation in the app. It says
 *  "still listening", which is the one thing you need while holding two phones
 *  together. */
function Sonar({ still }: { still: boolean }) {
  const { c } = useTheme();
  const a = useRef(new Animated.Value(0)).current;
  const b = useRef(new Animated.Value(0)).current;
  const d = useRef(new Animated.Value(0)).current;
  const rings = [a, b, d];

  useEffect(() => {
    if (still) return;
    const loops = rings.map((v, i) =>
      Animated.loop(
        Animated.sequence([
          Animated.delay(i * motion.sonarStagger),
          Animated.timing(v, {
            toValue: 1,
            duration: motion.sonar,
            easing: Easing.bezier(0.2, 0.6, 0.3, 1),
            useNativeDriver: true,
          }),
          Animated.timing(v, { toValue: 0, duration: 0, useNativeDriver: true }),
        ])
      )
    );
    loops.forEach((l) => l.start());
    return () => loops.forEach((l) => l.stop());
  }, [still]);

  return (
    <View style={s.arcs}>
      {rings.map((v, i) => (
        <Animated.View
          key={i}
          style={[
            s.ring,
            {
              borderColor: c.coin,
              opacity: still ? 0.3 : v.interpolate({ inputRange: [0, 1], outputRange: [0.85, 0] }),
              transform: [
                { scale: still ? MAX / CORE : v.interpolate({ inputRange: [0, 1], outputRange: [1, MAX / CORE] }) },
              ],
            },
          ]}
        />
      ))}
      <View style={[s.core, { backgroundColor: c.coin }]}>
        <Display size={15} color="#fff">
          NFC
        </Display>
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  segs: { flexDirection: 'row', gap: 6, paddingHorizontal: 14, paddingTop: 12 },
  seg: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingVertical: 8, borderRadius: radius.pill, borderWidth: 1.5, minHeight: 36 },
  zone: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 16, paddingHorizontal: 26 },
  arcs: { width: MAX, height: MAX, alignItems: 'center', justifyContent: 'center' },
  ring: { position: 'absolute', width: CORE, height: CORE, borderRadius: CORE / 2, borderWidth: 1.5 },
  core: { width: CORE, height: CORE, borderRadius: CORE / 2, alignItems: 'center', justifyContent: 'center' },
  h: { textAlign: 'center', maxWidth: 260, lineHeight: 30 },
  p: { textAlign: 'center', maxWidth: 270 },
  qrPlate: { padding: 10, borderRadius: 12, borderWidth: 1, backgroundColor: '#FFFFFF' },
  fp: { paddingHorizontal: 12, paddingVertical: 6, borderRadius: 8, borderWidth: 1 },
  finder: { width: 210, height: 210, borderRadius: 14, borderWidth: 1, overflow: 'hidden', backgroundColor: '#000' },
  bracket: { position: 'absolute', width: 26, height: 26, borderWidth: 3 },
  tl: { top: 10, left: 10, borderRightWidth: 0, borderBottomWidth: 0, borderTopLeftRadius: 6 },
  tr: { top: 10, right: 10, borderLeftWidth: 0, borderBottomWidth: 0, borderTopRightRadius: 6 },
  bl: { bottom: 10, left: 10, borderRightWidth: 0, borderTopWidth: 0, borderBottomLeftRadius: 6 },
  br: { bottom: 10, right: 10, borderLeftWidth: 0, borderTopWidth: 0, borderBottomRightRadius: 6 },
  btn: { borderRadius: 10, paddingVertical: 12, paddingHorizontal: 22, alignItems: 'center', justifyContent: 'center', minHeight: TOUCH_MIN },
  foot: { paddingHorizontal: 14 },
  paired: { flexDirection: 'row', alignItems: 'center', gap: 9, padding: 10, borderRadius: 10, borderWidth: 1 },
});
