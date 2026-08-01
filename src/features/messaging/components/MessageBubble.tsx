import { View, StyleSheet } from 'react-native';
import { useTheme, radius } from '../../../styles/theme';
import { Body, Mono, Display, CoinMark } from '../../../components/Type';
import RouteStrip from '../../../components/RouteStrip';
import type { Msg } from '../../../store/mock';

/** Outgoing only. Incoming messages get a route strip instead. */
const stateLine = (m: Msg) => {
  if (m.state === 'queued') return 'QUEUED · NO ROUTE YET';
  // hops counts relays, so 0 relays is a direct hand-off and saying "1 HOP"
  // about it just reads as noise.
  const via = m.hops ? ` · ${m.hops + 1} HOPS` : '';
  return `${(m.state ?? 'sent').toUpperCase()}${via} · ${m.at}`;
};

export default function MessageBubble({
  msg,
  senderName,
  animate,
}: {
  msg: Msg;
  senderName?: string;
  animate?: boolean;
}) {
  const { c } = useTheme();
  const mine = msg.from === 'me';

  // Money is a first-class message, not an attachment.
  if (msg.coin != null) {
    return (
      <View style={[s.slot, mine && s.right]}>
        <View
          style={[
            s.coinCard,
            { borderColor: c.coin, backgroundColor: c.coin + '12' },
            mine ? s.coinRight : s.coinLeft,
          ]}
        >
          <Mono size={9} color={c.coin}>
            {mine ? 'SENT' : 'RECEIVED'}
          </Mono>
          <View style={s.amtRow}>
            <CoinMark size={22} />
            <Display size={27} color={c.coin}>
              {msg.coin.toFixed(2)}
            </Display>
          </View>
          <Mono size={8.5} color={c.coin} style={{ opacity: 0.8 }}>
            {msg.hops ? `SIGNED ON DEVICE · RELAYED VIA ${msg.via?.toUpperCase()}` : 'SIGNED ON DEVICE · DIRECT'}
          </Mono>
        </View>
        <View style={{ marginTop: 4 }}>
          {mine ? (
            <Mono size={8.5}>{stateLine(msg)}</Mono>
          ) : (
            <RouteStrip
              hops={msg.hops}
              via={msg.via}
              animate={animate}
              label={msg.hops ? `VIA ${msg.via?.toUpperCase()} · ${msg.at}` : `DIRECT · ${msg.at}`}
            />
          )}
        </View>
      </View>
    );
  }

  return (
    <View style={[s.slot, mine && s.right]}>
      {senderName && !mine ? (
        <Mono size={9} style={{ marginBottom: 3 }}>
          {senderName.toUpperCase()}
        </Mono>
      ) : null}
      <View
        style={[
          s.bub,
          mine
            ? { backgroundColor: c.bubbleOut, borderBottomRightRadius: radius.tail }
            : { backgroundColor: c.bubbleIn, borderColor: c.hair2, borderWidth: 1, borderBottomLeftRadius: radius.tail },
          msg.state === 'queued' && { opacity: 0.55 },
        ]}
      >
        <Body size={12.5} color={mine ? c.bubbleOutInk : c.ink}>
          {msg.text}
        </Body>
      </View>
      <View style={{ marginTop: 4 }}>
        {mine ? (
          <Mono size={8.5}>{stateLine(msg)}</Mono>
        ) : (
          <RouteStrip hops={msg.hops} via={msg.via} animate={animate} label={msg.hops ? `VIA ${msg.via?.toUpperCase()} · ${msg.at}` : `DIRECT · ${msg.at}`} />
        )}
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  slot: { alignItems: 'flex-start', marginBottom: 9, maxWidth: '86%' },
  right: { alignSelf: 'flex-end', alignItems: 'flex-end' },
  bub: { paddingHorizontal: 11, paddingVertical: 8, borderRadius: radius.bubble },
  coinCard: { borderWidth: 1.5, borderRadius: radius.bubble, padding: 12, gap: 7, minWidth: 200 },
  coinLeft: { borderBottomLeftRadius: radius.tail },
  coinRight: { borderBottomRightRadius: radius.tail },
  amtRow: { flexDirection: 'row', alignItems: 'center', gap: 7 },
});
