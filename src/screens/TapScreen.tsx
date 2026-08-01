import { useEffect, useRef, useState } from 'react';
import { View, Animated, Easing, Pressable, StyleSheet, AccessibilityInfo } from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { useTheme, motion, radius, TOUCH_MIN } from '../styles/theme';
import { Display, Body, Mono } from '../components/Type';
import { MeshStatus, AppBar, bottomInset } from '../components/Chrome';
import QrCode from '../features/vault/components/QrCode';
import ResetSheet from '../features/vault/components/ResetSheet';
import { useMesh } from '../store/mesh';

const CORE = 52;
const MAX = 150;

// What the other phone reads. Same payload either way, so NFC and QR are two
// doors into one pairing flow rather than two features.
const pairPayload = (deviceId: string, display: string) =>
  `echo://pair?id=${encodeURIComponent(deviceId)}&n=${encodeURIComponent(display)}`;

/** "1 NODES IN RANGE" is the kind of thing people notice on a demo screen. */
const plural = (n: number, word: string) => `${n} ${word}${n === 1 ? '' : 'S'}`;

/** Something short a human can read aloud and compare against the other screen. */
const fingerprintOf = (deviceId: string) =>
  (deviceId.toUpperCase().padEnd(12, '0').match(/.{1,4}/g) ?? []).slice(0, 3).join(' ');

/** Never throws — a camera will happily hand us any barcode in the room. */
function readPairPayload(raw: string): { id: string; name: string } | null {
  if (!raw.startsWith('echo://pair')) return null;
  const query = raw.slice(raw.indexOf('?') + 1);
  const params = new URLSearchParams(query);
  const id = params.get('id');
  if (!id) return null;
  return { id, name: params.get('n') || id };
}

type Mode = 'tap' | 'show' | 'scan';

export default function TapScreen() {
  const { c } = useTheme();
  const peers = useMesh((s) => s.peers);
  const contacts = useMesh((s) => s.contacts);
  const me = useMesh((s) => s.me);
  const resetApp = useMesh((s) => s.resetApp);
  const reachable = Object.entries(peers);
  const [mode, setMode] = useState<Mode>('tap');
  const [confirmReset, setConfirmReset] = useState(false);
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
      <MeshStatus right={mode === 'tap' ? 'PAIR IN PERSON' : 'CAMERA PAIRING'} />
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
        <TapMode still={still} onPick={setMode} />
      ) : mode === 'show' ? (
        <ShowMode />
      ) : (
        <ScanMode scanned={scanned} onScan={setScanned} />
      )}

      <View style={[s.foot, { paddingBottom: bottomInset + 16 }]}>
        <View style={[s.paired, { backgroundColor: c.card, borderColor: c.hair2 }]}>
          <View style={{ flex: 1 }}>
            <Mono size={9} dim={1}>
              {`YOU ARE ${me.display.toUpperCase()} · ${fingerprintOf(me.deviceId)}`}
            </Mono>
            <Mono size={8.5}>
              {`${plural(Object.keys(contacts).length, 'CONTACT')} · ${plural(reachable.length, 'NODE')} IN RANGE`}
            </Mono>
          </View>
          <Pressable
            onPress={() => setConfirmReset(true)}
            accessibilityRole="button"
            accessibilityLabel="Reset this phone"
            hitSlop={10}
          >
            <Mono size={9} color={c.direct}>
              RESET
            </Mono>
          </Pressable>
        </View>
      </View>

      {confirmReset ? (
        <ResetSheet onCancel={() => setConfirmReset(false)} onConfirm={resetApp} />
      ) : null}
    </>
  );
}

/**
 * Meeting a phone is a physical act, so this stays the first thing you see —
 * but the exchange itself goes through the camera, and the screen says so.
 *
 * It used to promise "hold them back to back until both buzz", which is Android
 * Beam: an NDEF push between two phones. Google deprecated that in Android 10
 * and removed it in Android 14, so on any phone this app targets there is no
 * such thing to wait for. Claiming otherwise left a screen that said NFC READY
 * over nothing at all. Still hold the phones together — one shows, one reads.
 */
function TapMode({ still, onPick }: { still: boolean; onPick: (m: Mode) => void }) {
  const { c } = useTheme();
  return (
    <View style={s.zone}>
      <Sonar still={still} />
      <Display size={28} style={s.h}>
        Hold the phones together
      </Display>
      <Body size={13} dim={2} style={s.p}>
        One of you shows a code and the other reads it. Keys are generated and stored on each phone
        — nothing is uploaded.
      </Body>
      <View style={s.pick}>
        <Pressable
          onPress={() => onPick('show')}
          accessibilityRole="button"
          style={[s.btn, s.half, { backgroundColor: c.ink }]}
        >
          <Display size={14} color={c.paper}>
            Show mine
          </Display>
        </Pressable>
        <Pressable
          onPress={() => onPick('scan')}
          accessibilityRole="button"
          style={[s.btn, s.half, s.ghost, { borderColor: c.hair }]}
        >
          <Display size={14}>Read theirs</Display>
        </Pressable>
      </View>
      <Mono size={8.5} dim={2}>
        WHOEVER READS THE CODE ADDS THE CONTACT
      </Mono>
    </View>
  );
}

/** The fallback half you hold up. Encodes this phone, not a placeholder. */
function ShowMode() {
  const { c } = useTheme();
  const me = useMesh((s) => s.me);

  return (
    <View style={s.zone}>
      <View style={[s.qrPlate, { borderColor: c.hair }]}>
        <QrCode value={pairPayload(me.deviceId, me.display)} size={196} />
      </View>
      <Display size={26} style={s.h}>
        Let the other phone scan this
      </Display>
      <Body size={13} dim={2} style={s.p}>
        Works on any phone with a camera. The code carries who this phone is, nothing else.
      </Body>
      <View style={[s.fp, { borderColor: c.hair2, backgroundColor: c.card }]}>
        <Mono size={10} dim={1}>
          {fingerprintOf(me.deviceId)}
        </Mono>
      </View>
      <Mono size={8.5}>CHECK THIS MATCHES ON THEIR SCREEN</Mono>
    </View>
  );
}

/** The fallback half that reads. */
function ScanMode({ scanned, onScan }: { scanned: string | null; onScan: (v: string) => void }) {
  const { c } = useTheme();
  const pair = useMesh((s) => s.pair);
  const contacts = useMesh((s) => s.contacts);
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
    const theirs = readPairPayload(scanned);
    const ok = theirs !== null;
    return (
      <View style={s.zone}>
        <Display size={28} style={[s.h, { color: ok ? c.ink : c.direct }]}>
          {ok ? theirs.name : 'That is not an Echo code'}
        </Display>
        <Body size={13} dim={2} style={s.p}>
          {ok
            ? 'Check this fingerprint matches the one on their screen, then confirm.'
            : 'Point the camera at the code on the other phone’s Show code screen.'}
        </Body>
        {ok ? (
          <View style={[s.fp, { borderColor: c.hair2, backgroundColor: c.card }]}>
            {/* Theirs, not ours — comparing our own code to itself proves nothing. */}
            <Mono size={10} dim={1}>
              {fingerprintOf(theirs.id)}
            </Mono>
          </View>
        ) : null}
        {ok && contacts[theirs.id] ? (
          <Mono size={8.5} color={c.relay}>
            ALREADY IN YOUR CONTACTS
          </Mono>
        ) : null}

        <Pressable
          onPress={() => {
            // Scanning the code is the whole point: it is what turns a phone
            // that was merely in range into someone you can talk to.
            if (ok) pair(theirs.id, theirs.name);
            onScan('');
          }}
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
        <Display size={13} color="#fff">
          MEET
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
  pick: { flexDirection: 'row', gap: 10, alignSelf: 'stretch' },
  half: { flex: 1, paddingHorizontal: 8 },
  ghost: { borderWidth: 1.5 },
  foot: { paddingHorizontal: 14 },
  paired: { flexDirection: 'row', alignItems: 'center', gap: 9, padding: 10, borderRadius: 10, borderWidth: 1 },
});
