import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  View,
  ScrollView,
  Pressable,
  TextInput,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { useTheme, radius, TOUCH_MIN } from '../styles/theme';
import { Display, Body, Mono, CoinMark } from '../components/Type';
import { MeshStatus, AppBar, bottomInset } from '../components/Chrome';
import { HopChip } from '../components/Chip';
import MessageBubble from '../features/messaging/components/MessageBubble';
import CatchMeUpSheet from './CatchMeUpSheet';
import { useMesh, SUMMARY_THRESHOLD } from '../store/mesh';
import { useShake } from '../hooks/useShake';
import EventComposer from '../features/messaging/components/EventComposer';
import {
  pickFromCamera,
  pickFromLibrary,
  chunkCount,
  MAX_IMAGE_CHARS,
} from '../features/messaging/api/attachments';
import { encodeEvent, saveToCalendar, type MeshEvent } from '../features/messaging/api/events';
import MicButton from '../features/messaging/components/MicButton';
import { useDictation, type StopOutcome } from '../features/ai/hooks/useDictation';
import { notifyFail, notifyOk, tick } from '../features/feedback/api';
import { mergeDraft, progressPercent } from '../utils/dictation';
import { downloadSpeechModel, speechModelReady } from '../services/models';

export default function ChatScreen({
  threadId,
  onBack,
  onSendCoin,
}: {
  threadId: string;
  onBack: () => void;
  onSendCoin: (contactId: string) => void;
}) {
  const { c } = useTheme();
  const threads = useMesh((s) => s.threads);
  const sendToMesh = useMesh((s) => s.send);
  const markRead = useMesh((s) => s.markRead);
  const pending = useMesh((s) => s.pending);
  const peers = useMesh((s) => s.peers);
  const me = useMesh((s) => s.me.deviceId);
  const peerName = (id: string) => peers[id]?.display ?? id;
  const cancelPending = useMesh((s) => s.cancelPending);
  const revertLastCoin = useMesh((s) => s.revertLastCoin);
  const [left, setLeft] = useState(0);
  const [note, setNote] = useState<string | null>(null);

  const holding = pending?.threadId === threadId ? pending : null;

  useEffect(() => {
    if (!holding) return setLeft(0);
    const tick = () => setLeft(Math.max(0, Math.ceil((holding.until - Date.now()) / 1000)));
    tick();
    const id = setInterval(tick, 200);
    return () => clearInterval(id);
  }, [holding]);

  useEffect(() => {
    if (!note) return;
    const id = setTimeout(() => setNote(null), 2600);
    return () => clearTimeout(id);
  }, [note]);
  const baseline = useRef(0);
  const thread = useMemo(() => threads.find((t) => t.id === threadId)!, [threads, threadId]);
  const [draft, setDraft] = useState('');
  const [summary, setSummary] = useState(false);
  const [attaching, setAttaching] = useState(false);
  const [composingEvent, setComposingEvent] = useState(false);
  const scroller = useRef<ScrollView>(null);

  // Whisper is 224 MB — closer to the LLM than to the vision models — so it is
  // opt-in, and opening a chat must never start that download or pull the model
  // into RAM. `null` while the marker file is still being read.
  const [speechReady, setSpeechReady] = useState<boolean | null>(null);
  const [speechProgress, setSpeechProgress] = useState<number | null>(null);

  // The download outlives the screen, so late setState has to be suppressed.
  const mounted = useRef(true);
  useEffect(() => {
    mounted.current = true;
    void speechModelReady().then((ready) => {
      if (mounted.current) setSpeechReady(ready);
    });
    return () => {
      mounted.current = false;
    };
  }, []);

  // Dictation is owned here rather than inside MicButton, so the hook's identity
  // survives every composer re-render rather than reloading Whisper.
  const applyTranscript = useCallback(async (outcome: StopOutcome) => {
    if (outcome.status === 'skipped') return;
    if (outcome.status === 'ok') {
      // Into the draft, never straight onto the mesh — you get to read it back
      // and fix it before anyone else sees it.
      setDraft((d) => mergeDraft(d, outcome.text));
      await notifyOk();
      return;
    }
    await notifyFail();
    // Four different failures, four different things to do about them.
    // Collapsing them into one message tells the user to try the same thing
    // again when the fix is to wait, or to speak for longer.
    setNote(
      outcome.status === 'short'
        ? 'Hold to talk'
        : outcome.status === 'empty'
          ? "Didn't catch that"
          : outcome.status === 'discarded'
            ? 'Still writing down the last one'
            : outcome.message ?? 'Could not write that down'
    );
  }, []);

  const dictation = useDictation({
    // The marker is what gates loading. `null` counts as not-yet, so the few
    // milliseconds before it resolves cannot start a fetch either.
    enabled: speechReady === true,
    onAutoStop: (o) => void applyTranscript(o),
  });
  const { start: startTake, lock: lockTake, stop: stopTake, cancel: cancelTake } = dictation;
  const recording = dictation.phase !== 'idle';

  const startDictation = useCallback(async () => {
    // Confirm the press now, not after the permission round trip.
    void tick();
    const outcome = await startTake();
    if (outcome.status === 'ok' || outcome.status === 'skipped') return;
    await notifyFail();
    setNote(
      outcome.status === 'failed'
        ? 'Could not open the microphone'
        : outcome.blocked
          ? 'Allow the microphone for Echo in Android Settings'
          : 'Echo needs the microphone to dictate'
    );
  }, [startTake]);

  const stopDictation = useCallback(async () => {
    await applyTranscript(await stopTake());
  }, [applyTranscript, stopTake]);

  const cancelDictation = useCallback(async () => {
    if ((await cancelTake()).status === 'skipped') return;
    await tick();
    setNote('Cancelled');
  }, [cancelTake]);

  const lockDictation = useCallback(() => {
    if (lockTake().status === 'ok') void tick();
  }, [lockTake]);

  // The only route to this download in the shipped app: nothing mounts
  // ModelPreloadScreen. It has to be a tap, because someone on mobile data
  // should not pay 224 MB for a feature they never asked for.
  const setUpDictation = useCallback(async () => {
    if (speechProgress !== null) return;
    void tick();
    setSpeechProgress(0);

    try {
      await downloadSpeechModel((p) => {
        if (mounted.current) setSpeechProgress(p);
      });
      if (mounted.current) {
        // Flips `enabled`, which is what finally loads the model.
        setSpeechReady(true);
        setNote('Dictation ready');
      }
      await notifyOk();
    } catch {
      if (mounted.current) setNote('Download failed — try again on wifi');
      await notifyFail();
    } finally {
      if (mounted.current) setSpeechProgress(null);
    }
  }, [speechProgress]);

  // Shake does whatever the visible control does: cancel what is still held,
  // otherwise take back the last payment that already went.
  //
  // Off while dictating: raising the phone to your mouth clears the 1.7 g
  // threshold, and the second branch reverts a payment with no confirmation.
  useShake(() => {
    if (holding) {
      cancelPending();
      setNote('Send cancelled');
    } else {
      revertLastCoin(threadId).then((did) =>
        setNote(did ? 'Last payment taken back' : 'Nothing to take back')
      );
    }
  }, !recording);

  // Never "Loading model 0%" on a model that already gave up.
  const dictationDown = Boolean(dictation.error) && !dictation.isReady;
  const setupNeeded = speechReady === false;
  const micLabel = setupNeeded
    ? speechProgress === null
      ? 'Set up dictation. A 224 megabyte download, once, then it works offline'
      : `Downloading dictation, ${progressPercent(speechProgress)} percent`
    : dictationDown
      ? 'Dictation unavailable'
      : speechReady === null
        ? 'Getting dictation ready'
        : !dictation.isReady
          ? `Loading model ${progressPercent(dictation.downloadProgress)}%`
          : dictation.phase === 'transcribing'
            ? 'Writing down what you said'
            : recording
              ? 'Recording. Release to put it in the message'
              : 'Hold to dictate a message';

  // Anything past this index arrived while the screen was open, so its route
  // strip draws itself rather than appearing already there.
  if (baseline.current === 0) baseline.current = thread.messages.length;

  // Held from the moment the screen opened. Clearing the badge immediately
  // would also remove the offer to summarise what you have not read yet.
  const backlog = useRef(thread.unread ?? 0);
  useEffect(() => {
    if (thread.unread) markRead(threadId);
  }, [markRead, threadId, thread.unread]);

  const send = () => {
    const text = draft.trim();
    if (!text) return;
    setDraft('');
    sendToMesh(threadId, text);
    requestAnimationFrame(() => scroller.current?.scrollToEnd({ animated: true }));
  };

  const attachPhoto = async (from: 'library' | 'camera') => {
    setAttaching(false);
    const picked = from === 'camera' ? await pickFromCamera() : await pickFromLibrary();
    if (!picked) return;
    if (picked.bytes > MAX_IMAGE_CHARS) {
      setNote('That photo is too big to send over the mesh');
      return;
    }
    setNote(`Sending photo in ${chunkCount(picked.bytes)} parts`);
    sendToMesh(threadId, picked.dataUri, 'image');
    requestAnimationFrame(() => scroller.current?.scrollToEnd({ animated: true }));
  };

  const sendEvent = (event: MeshEvent) => {
    setComposingEvent(false);
    sendToMesh(threadId, encodeEvent(event), 'event');
    requestAnimationFrame(() => scroller.current?.scrollToEnd({ animated: true }));
  };

  const addToCalendar = async (event: MeshEvent) => {
    const result = await saveToCalendar(event);
    setNote(
      result.ok
        ? 'Added to your calendar'
        : result.reason === 'denied'
          ? 'Echo needs calendar permission to add it'
          : result.reason === 'no-calendar'
            ? 'No calendar on this phone can be written to'
            : 'Could not add it to the calendar'
    );
  };

  const sub = thread.group
    ? `${thread.members!.length} members · 3 reachable`
    : thread.hops === null
      ? 'No route · messages queue here'
      : thread.hops === 0
        ? 'Direct · in Bluetooth range'
        : `${thread.hops + 1} hops · via ${thread.via}`;

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <MeshStatus />
      <AppBar
        title={thread.title}
        sub={sub}
        onBack={onBack}
        right={<HopChip hops={thread.hops} via={thread.via} />}
      />

      <ScrollView
        ref={scroller}
        contentContainerStyle={s.body}
        showsVerticalScrollIndicator={false}
        onContentSizeChange={() => scroller.current?.scrollToEnd({ animated: false })}
      >
        {thread.group ? (
          <ReachBar members={(thread.members ?? []).filter((id) => id !== me)} peers={peers} />
        ) : null}

        <Mono size={8.5} style={s.day}>
          TODAY
        </Mono>

        {thread.messages.map((m, i) => (
          <MessageBubble
            key={m.id}
            msg={m}
            // The name rides with the message, so it works for a sender two
            // hops away who is not a peer of this phone.
            senderName={thread.group ? m.fromName ?? peerName(m.from) : undefined}
            animate={i >= baseline.current}
            onSaveEvent={addToCalendar}
          />
        ))}

        {backlog.current >= SUMMARY_THRESHOLD ? (
          <Pressable
            onPress={() => setSummary(true)}
            accessibilityRole="button"
            accessibilityLabel={`Summarise ${backlog.current} unread messages on this phone`}
            style={[s.catch, { borderColor: c.hair, backgroundColor: c.card }]}
          >
            <Display size={13}>Catch me up · {backlog.current} unread</Display>
          </Pressable>
        ) : null}
      </ScrollView>

      {holding ? (
        <View style={[s.undo, { backgroundColor: c.coin }]}>
          <View style={{ flex: 1 }}>
            <Mono size={9} color="#fff">
              SENDING {holding.amount.toFixed(2)} IN {left}s
            </Mono>
            <Mono size={8.5} color="#fff" style={{ opacity: 0.75 }}>
              OR SHAKE THE PHONE
            </Mono>
          </View>
          <Pressable
            onPress={() => {
              cancelPending();
              setNote('Send cancelled');
            }}
            accessibilityRole="button"
            style={s.undoBtn}
          >
            <Display size={14} color="#fff">
              Cancel
            </Display>
          </Pressable>
        </View>
      ) : null}

      {note ? (
        <View style={[s.note, { backgroundColor: c.ink }]}>
          <Mono size={9} color={c.paper}>
            {note.toUpperCase()}
          </Mono>
        </View>
      ) : null}

      {recording ? (
        <View style={[s.note, { backgroundColor: c.direct }]} accessibilityLiveRegion="polite">
          <Mono size={9} color="#fff">
            {dictation.phase === 'transcribing'
              ? 'WRITING IT DOWN'
              : dictation.phase === 'locked'
                ? 'RECORDING HANDS FREE'
                : 'RECORDING · UP TO LOCK · LEFT TO CANCEL'}
          </Mono>
        </View>
      ) : null}

      {/* A 40 dp circle with an arrow in it explains nothing on its own, and
          the price has to be visible before the tap, not after it. */}
      {setupNeeded ? (
        <View style={[s.note, { backgroundColor: c.ink }]}>
          <Mono size={9} color={c.paper}>
            {speechProgress === null
              ? 'SET UP DICTATION · 224 MB'
              : `DOWNLOADING DICTATION · ${progressPercent(speechProgress)}%`}
          </Mono>
        </View>
      ) : null}

      {/* A disabled 40 dp circle explains nothing on its own. The hook reloads
          on mount, so leaving the thread and coming back is the retry. */}
      {dictationDown ? (
        <View style={[s.note, { backgroundColor: c.ink }]}>
          <Mono size={9} color={c.paper}>
            DICTATION UNAVAILABLE · LEAVE AND COME BACK TO RETRY
          </Mono>
        </View>
      ) : null}

      {composingEvent ? (
        <EventComposer onCancel={() => setComposingEvent(false)} onSend={sendEvent} />
      ) : null}

      {attaching ? (
        <View style={[s.attachRow, { backgroundColor: c.card, borderTopColor: c.hair2 }]}>
          <Pressable onPress={() => attachPhoto('camera')} accessibilityRole="button" style={[s.attach, { borderColor: c.hair }]}>
            <Display size={13}>Take a photo</Display>
          </Pressable>
          <Pressable onPress={() => attachPhoto('library')} accessibilityRole="button" style={[s.attach, { borderColor: c.hair }]}>
            <Display size={13}>Choose photo</Display>
          </Pressable>
          <Pressable
            onPress={() => {
              setAttaching(false);
              setComposingEvent(true);
            }}
            accessibilityRole="button"
            style={[s.attach, { borderColor: c.hair }]}
          >
            <Display size={13}>Event</Display>
          </Pressable>
        </View>
      ) : null}

      <View
        style={[s.composer, { backgroundColor: c.card, borderTopColor: c.hair2, paddingBottom: bottomInset + 9 }]}
      >
        <Pressable
          onPress={() => setAttaching((a) => !a)}
          accessibilityRole="button"
          accessibilityLabel="Attach a photo or an event"
          style={[s.rbtn, { borderWidth: 1.5, borderColor: c.hair }]}
        >
          <Display size={17} dim={1}>
            {attaching ? '×' : '+'}
          </Display>
        </Pressable>
        <Pressable
          onPress={() => onSendCoin(thread.id)}
          accessibilityRole="button"
          accessibilityLabel="Send echocoin"
          style={[s.rbtn, { borderWidth: 1.5, borderColor: c.coin }]}
        >
          <CoinMark size={15} />
        </Pressable>
        <TextInput
          value={draft}
          onChangeText={setDraft}
          onSubmitEditing={send}
          placeholder={thread.group ? `Message ${thread.title}` : 'Message'}
          placeholderTextColor={c.ink3}
          returnKeyType="send"
          style={[s.field, { backgroundColor: c.paper, borderColor: c.hair2, color: c.ink }]}
        />
        {/* The mic never leaves. Handing its slot to send the moment a
            transcript lands made dictation single-shot: you could not add a
            second sentence, or re-say one Whisper got wrong. Four controls
            costs the field ~136 dp on a 360 dp screen; that trade is the
            feature. */}
        <MicButton
          phase={dictation.phase}
          disabled={dictationDown || !dictation.isReady}
          label={micLabel}
          onSetup={setupNeeded ? () => void setUpDictation() : undefined}
          setupProgress={speechProgress}
          onStart={() => void startDictation()}
          onLock={lockDictation}
          onStop={() => void stopDictation()}
          onCancel={() => void cancelDictation()}
        />
        {/* Send steps aside for the length of a take: locking turns the mic
            into two buttons, and a fifth control would leave the field under
            60 dp right when the user is watching it fill up. */}
        {draft.trim() && !recording ? (
          <Pressable
            onPress={send}
            accessibilityRole="button"
            accessibilityLabel="Send message"
            style={[s.rbtn, { backgroundColor: c.ink }]}
          >
            <Display size={15} color={c.paper}>
              ↑
            </Display>
          </Pressable>
        ) : null}
      </View>

      {summary ? (
        <CatchMeUpSheet thread={thread} unread={backlog.current} onClose={() => setSummary(false)} />
      ) : null}
    </KeyboardAvoidingView>
  );
}

/**
 * Who can actually hear you right now, before you type. Counted from the
 * group's real membership against the peers currently in range — a group whose
 * members are all away should say so rather than imply an audience.
 */
function ReachBar({
  members,
  peers,
}: {
  members: string[];
  peers: Record<string, { display: string }>;
}) {
  const { c } = useTheme();
  const reachable = members.filter((id) => peers[id]);
  const away = members.length - reachable.length;

  return (
    <View style={[s.reachbar, { backgroundColor: c.card, borderColor: c.hair2 }]}>
      <View style={s.pips}>
        {members.map((id) => (
          <View key={id} style={[s.pip, { backgroundColor: peers[id] ? c.direct : c.dim }]} />
        ))}
      </View>
      <View style={{ flex: 1 }}>
        <Mono size={8.5} dim={2}>
          {reachable.length} REACHABLE · {away} OUT OF REACH
        </Mono>
        <Mono size={8.5}>
          {away === 0
            ? 'EVERYONE GETS THIS NOW'
            : reachable.length === 0
              ? 'NOBODY IS IN RANGE — THIS WILL WAIT'
              : `${away} GET${away === 1 ? 'S' : ''} IT WHEN THEY ARE BACK`}
        </Mono>
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  body: { paddingHorizontal: 14, paddingTop: 12, paddingBottom: 16 },
  day: { alignSelf: 'center', marginBottom: 8 },
  reachbar: { flexDirection: 'row', alignItems: 'center', gap: 8, padding: 9, borderRadius: 10, borderWidth: 1, marginBottom: 12 },
  pips: { flexDirection: 'row', gap: 3 },
  pip: { width: 7, height: 7, borderRadius: 4 },
  catch: { alignSelf: 'center', borderWidth: 1.5, borderRadius: radius.pill, paddingHorizontal: 14, paddingVertical: 7, marginTop: 6, minHeight: 36, justifyContent: 'center' },
  attachRow: { flexDirection: 'row', gap: 7, paddingHorizontal: 12, paddingVertical: 10, borderTopWidth: 1 },
  attach: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingVertical: 10, borderRadius: 10, borderWidth: 1.5, minHeight: 44 },
  undo: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 14, paddingVertical: 10 },
  undoBtn: { paddingHorizontal: 14, paddingVertical: 8, minHeight: 40, justifyContent: 'center' },
  note: { alignSelf: 'center', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 14, marginBottom: 8 },
  composer: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 12, paddingVertical: 9, borderTopWidth: 1 },
  field: { flex: 1, borderWidth: 1, borderRadius: 18, paddingHorizontal: 12, paddingVertical: 8, fontSize: 12.5, minHeight: 40 },
  rbtn: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
});
