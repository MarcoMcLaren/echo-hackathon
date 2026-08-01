import { useState } from 'react';
import { View, Pressable, StyleSheet } from 'react-native';
import { useTheme, radius, TOUCH_MIN } from '../styles/theme';
import { Display, Body, Mono, CoinMark } from '../components/Type';
import { MeshStatus, AppBar, bottomInset } from '../components/Chrome';
import Avatar from '../components/Avatar';
import { HopChip } from '../components/Chip';
import { balance, byId, threads } from '../store/mock';
import { useMesh } from '../store/mesh';

const KEYS = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];

export default function SendCoinScreen({
  contactId,
  onBack,
  onQueued,
}: {
  contactId: string;
  onBack: () => void;
  /** Land in the conversation, where the cancel window is visible. Returning to
   *  the tab list would hide the only control that can stop the send. */
  onQueued: (threadId: string) => void;
}) {
  const { c } = useTheme();
  const queueCoin = useMesh((s) => s.queueCoin);
  const [amount, setAmount] = useState('20.00');

  const contact = byId(contactId);
  const thread = threads.find((t) => t.id === contactId);
  const name = contact?.name ?? thread?.title ?? 'Contact';
  const initials = contact?.initials ?? thread?.initials ?? '··';
  const hops = contact?.hops ?? thread?.hops ?? 0;
  const via = contact?.via ?? thread?.via;

  const press = (k: string) => {
    setAmount((a) => {
      if (k === '⌫') return a.length <= 1 ? '0' : a.slice(0, -1);
      if (k === '.' && a.includes('.')) return a;
      return a === '0' ? k : a + k;
    });
  };

  const routeNote =
    hops === null
      ? 'QUEUES UNTIL A ROUTE OPENS'
      : hops === 0
        ? 'SIGNED HERE · GOES DIRECT'
        : 'SIGNED HERE · RELAY CAN’T READ IT';

  return (
    <>
      <MeshStatus />
      <AppBar title="Send echocoin" sub={`Balance ${balance.toFixed(2)}`} onBack={onBack} />

      <View style={s.body}>
        <View style={[s.to, { backgroundColor: c.card, borderColor: c.hair2 }]}>
          <Avatar initials={initials} hops={hops} size={30} />
          <View style={{ flex: 1 }}>
            <Display size={14}>{name}</Display>
            <Mono size={8.5}>
              {hops === null ? 'NO ROUTE RIGHT NOW' : hops === 0 ? 'IN BLUETOOTH RANGE' : `REACHABLE VIA ${via?.toUpperCase()}`}
            </Mono>
          </View>
          <HopChip hops={hops} via={via} label={hops ? `${hops} hop` : undefined} />
        </View>

        <View style={s.big}>
          <CoinMark size={40} />
          <Display size={52} color={c.coin} style={s.tabular}>
            {amount}
          </Display>
        </View>

        <View style={s.keys}>
          {KEYS.map((k) => (
            <Pressable
              key={k}
              onPress={() => press(k)}
              accessibilityRole="button"
              accessibilityLabel={k === '⌫' ? 'Delete' : k}
              style={({ pressed }) => [
                s.key,
                { backgroundColor: pressed ? c.sunk : c.card, borderColor: c.hair2 },
              ]}
            >
              <Display size={21}>{k}</Display>
            </Pressable>
          ))}
        </View>

        <View style={s.foot}>
          <Pressable
            onPress={() => {
              queueCoin(contactId, Number(amount) || 0);
              onQueued(contactId);
            }}
            accessibilityRole="button"
            style={[s.btn, { backgroundColor: c.coin }]}
          >
            <Display size={15} color="#fff">
              Send {amount}
            </Display>
          </Pressable>
          <Pressable accessibilityRole="button" style={[s.btn, s.ghost, { borderColor: c.hair }]}>
            <Display size={15}>Or tap phones together</Display>
          </Pressable>
          <Mono size={8.5} style={{ alignSelf: 'center' }}>
            {routeNote}
          </Mono>
        </View>
      </View>
    </>
  );
}

const s = StyleSheet.create({
  body: { flex: 1, paddingHorizontal: 14, paddingTop: 12, paddingBottom: bottomInset + 16, gap: 12 },
  to: { flexDirection: 'row', alignItems: 'center', gap: 9, padding: 10, borderRadius: 10, borderWidth: 1 },
  big: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 10, paddingVertical: 10 },
  keys: { flexDirection: 'row', flexWrap: 'wrap', gap: 5 },
  key: { width: '31.8%', alignItems: 'center', justifyContent: 'center', paddingVertical: 12, borderRadius: 9, borderWidth: 1, minHeight: TOUCH_MIN },
  foot: { marginTop: 'auto', gap: 8 },
  btn: { borderRadius: 10, paddingVertical: 12, alignItems: 'center', justifyContent: 'center', minHeight: TOUCH_MIN },
  ghost: { borderWidth: 1.5 },
  tabular: { fontVariant: ['tabular-nums'] },
});
