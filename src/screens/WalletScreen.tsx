import { View, ScrollView, Pressable, StyleSheet } from 'react-native';
import { useTheme, radius, TOUCH_MIN } from '../styles/theme';
import { Display, Body, Mono, CoinMark } from '../components/Type';
import { MeshStatus, AppBar } from '../components/Chrome';
import RouteStrip from '../components/RouteStrip';
import { useMesh, walletFrom, OPENING_BALANCE } from '../store/mesh';

export default function WalletScreen({ onSend, onTap }: { onSend: () => void; onTap: () => void }) {
  const { c } = useTheme();
  const threads = useMesh((s) => s.threads);
  const peerCount = useMesh((s) => Object.keys(s.peers).length);
  const { balance, entries } = walletFrom(threads);

  return (
    <>
      <MeshStatus />
      <AppBar title="Wallet" sub="Echocoin · balance held on device" />
      <ScrollView contentContainerStyle={s.body} showsVerticalScrollIndicator={false}>
        <View style={[s.balance, { backgroundColor: c.card, borderColor: c.hair2 }]}>
          <Mono size={10} style={s.caps}>
            Balance
          </Mono>
          <View style={s.amtRow}>
            <CoinMark size={34} />
            <Display size={44} color={c.coin} style={s.tabular}>
              {balance.toFixed(2)}
            </Display>
          </View>
          <Mono size={8.5}>
            {`ECHOCOIN · OPENED AT ${OPENING_BALANCE.toFixed(2)} · ${peerCount} PEER${peerCount === 1 ? '' : 'S'} IN RANGE`}
          </Mono>
        </View>

        <View style={s.acts}>
          <Pressable
            onPress={onSend}
            accessibilityRole="button"
            style={[s.act, { backgroundColor: c.coin, borderColor: c.coin }]}
          >
            <Display size={14} color="#fff">
              Send
            </Display>
          </Pressable>
          <Pressable accessibilityRole="button" style={[s.act, { borderColor: c.hair }]}>
            <Display size={14}>Request</Display>
          </Pressable>
          <Pressable onPress={onTap} accessibilityRole="button" style={[s.act, { borderColor: c.hair }]}>
            <Display size={14}>Tap</Display>
          </Pressable>
        </View>

        <Mono size={10} style={s.caps}>
          Activity
        </Mono>

        {entries.length === 0 ? (
          <View style={[s.empty, { borderColor: c.hair2 }]}>
            <Body size={13} dim={2}>
              Nothing has moved yet. Send echocoin from a conversation and it will show up here
              with the route it took.
            </Body>
          </View>
        ) : (
          <View>
            {entries.map((e, i) => (
              <View
                key={e.id}
                style={[
                  s.row,
                  { borderBottomColor: c.hair2, borderBottomWidth: i === entries.length - 1 ? 0 : 1 },
                  e.reverted && { opacity: 0.55 },
                ]}
              >
                <Display
                  size={15}
                  color={e.reverted ? c.ink3 : e.amount > 0 ? c.coin : c.ink}
                  style={[s.amt, s.tabular, e.reverted && s.struck]}
                >
                  {e.amount > 0 ? '+' : '−'}
                  {Math.abs(e.amount).toFixed(2)}
                </Display>
                <View style={{ flex: 1, gap: 3 }}>
                  <Body size={12}>{e.who}</Body>
                  {e.hops ? (
                    <RouteStrip hops={e.hops} via={e.via} label={`VIA ${e.via?.toUpperCase()} · ${e.note}`} />
                  ) : (
                    <Mono size={8.5}>{e.reverted ? `TAKEN BACK · ${e.note}` : e.note}</Mono>
                  )}
                </View>
              </View>
            ))}
          </View>
        )}
      </ScrollView>
    </>
  );
}

const s = StyleSheet.create({
  body: { paddingHorizontal: 14, paddingTop: 12, paddingBottom: 24, gap: 12 },
  balance: { borderWidth: 1, borderRadius: radius.card, padding: 15, gap: 3 },
  amtRow: { flexDirection: 'row', alignItems: 'center', gap: 9 },
  empty: { borderWidth: 1, borderStyle: 'dashed', borderRadius: radius.card, padding: 16 },
  struck: { textDecorationLine: 'line-through' },
  acts: { flexDirection: 'row', gap: 7 },
  act: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingVertical: 10, borderRadius: 10, borderWidth: 1.5, minHeight: TOUCH_MIN },
  row: { flexDirection: 'row', gap: 10, alignItems: 'flex-start', paddingVertical: 10 },
  amt: { width: 74, textAlign: 'right' },
  tabular: { fontVariant: ['tabular-nums'] },
  caps: { textTransform: 'uppercase' },
});
