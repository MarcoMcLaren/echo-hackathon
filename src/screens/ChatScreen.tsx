import { useEffect, useMemo, useRef, useState } from 'react';
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
import { byId } from '../store/mock';
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
  const peerName = (id: string) => peers[id]?.display ?? id;
  const cancelPending = useMesh((s) => s.cancelPending);
  const revertLastCoin = useMesh((s) => s.revertLastCoin);
  const [left, setLeft] = useState(0);
  const [note, setNote] = useState<string | null>(null);

  const holding = pending?.threadId === threadId ? pending : null;

  // Shake does whatever the visible control does: cancel what is still held,
  // otherwise take back the last payment that already went.
  useShake(() => {
    if (holding) {
      cancelPending();
      setNote('Send cancelled');
    } else {
      revertLastCoin(threadId).then((did) =>
        setNote(did ? 'Last payment taken back' : 'Nothing to take back')
      );
    }
  });

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
        {thread.group ? <ReachBar /> : null}

        <Mono size={8.5} style={s.day}>
          TODAY
        </Mono>

        {thread.messages.map((m, i) => (
          <MessageBubble
            key={m.id}
            msg={m}
            senderName={
              thread.group ? byId(m.from)?.name.split(' ')[0] ?? peerName(m.from) : undefined
            }
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
      </View>

      {summary ? (
        <CatchMeUpSheet thread={thread} unread={backlog.current} onClose={() => setSummary(false)} />
      ) : null}
    </KeyboardAvoidingView>
  );
}

/** Who can actually hear you right now, before you type. */
function ReachBar() {
  const { c } = useTheme();
  const pips = [c.direct, c.direct, c.relay, c.dim];
  return (
    <View style={[s.reachbar, { backgroundColor: c.card, borderColor: c.hair2 }]}>
      <View style={s.pips}>
        {pips.map((p, i) => (
          <View key={i} style={[s.pip, { backgroundColor: p }]} />
        ))}
      </View>
      <View style={{ flex: 1 }}>
        <Mono size={8.5} dim={2}>
          2 DIRECT · 1 VIA THABO · 1 OUT OF REACH
        </Mono>
        <Mono size={8.5}>SIPHO GETS IT WHEN HE’S BACK</Mono>
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
