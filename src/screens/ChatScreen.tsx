import { useMemo, useRef, useState } from 'react';
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
import { useMesh } from '../store/mesh';

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
  const baseline = useRef(0);
  const thread = useMemo(() => threads.find((t) => t.id === threadId)!, [threads, threadId]);
  const [draft, setDraft] = useState('');
  const [summary, setSummary] = useState(false);
  const scroller = useRef<ScrollView>(null);

  // Anything past this index arrived while the screen was open, so its route
  // strip draws itself rather than appearing already there.
  if (baseline.current === 0) baseline.current = thread.messages.length;

  const send = () => {
    const text = draft.trim();
    if (!text) return;
    setDraft('');
    sendToMesh(threadId, text);
    requestAnimationFrame(() => scroller.current?.scrollToEnd({ animated: true }));
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
            senderName={thread.group ? byId(m.from)?.name.split(' ')[0] : undefined}
            animate={i >= baseline.current}
          />
        ))}

        {thread.group ? (
          <Pressable
            onPress={() => setSummary(true)}
            accessibilityRole="button"
            style={[s.catch, { borderColor: c.hair, backgroundColor: c.card }]}
          >
            <Display size={13}>Catch me up · 41 new</Display>
          </Pressable>
        ) : null}
      </ScrollView>

      <View
        style={[s.composer, { backgroundColor: c.card, borderTopColor: c.hair2, paddingBottom: bottomInset + 9 }]}
      >
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

      {summary ? <CatchMeUpSheet onClose={() => setSummary(false)} /> : null}
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
  composer: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 12, paddingVertical: 9, borderTopWidth: 1 },
  field: { flex: 1, borderWidth: 1, borderRadius: 18, paddingHorizontal: 12, paddingVertical: 8, fontSize: 12.5, minHeight: 40 },
  rbtn: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
});
