import { View, Image, Pressable, StyleSheet } from 'react-native';
import { useTheme, radius, TOUCH_MIN } from '../../../styles/theme';
import { Body, Mono, Display, CoinMark } from '../../../components/Type';
import RouteStrip from '../../../components/RouteStrip';
import { formatWhen, type MeshEvent } from '../api/events';
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
  onSaveEvent,
}: {
  msg: Msg;
  senderName?: string;
  animate?: boolean;
  onSaveEvent?: (event: MeshEvent) => void;
}) {
  const { c } = useTheme();
  const mine = msg.from === 'me';

  // A photo carries its own frame; a bubble around it would be noise.
  if (msg.image) {
    return (
      <View style={[s.slot, mine && s.right]}>
        {senderName && !mine ? (
          <Mono size={9} style={{ marginBottom: 3 }}>
            {senderName.toUpperCase()}
          </Mono>
        ) : null}
        <Image
          source={{ uri: msg.image }}
          style={[s.photo, { borderColor: c.hair2 }]}
          resizeMode="cover"
          accessibilityLabel="Photo"
        />
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

  // An event you can act on. Saving it to the phone's calendar is a separate
  // tap — a received message should never write to someone's calendar itself.
  if (msg.event) {
    return (
      <View style={[s.slot, mine && s.right]}>
        {senderName && !mine ? (
          <Mono size={9} style={{ marginBottom: 3 }}>
            {senderName.toUpperCase()}
          </Mono>
        ) : null}
        <View style={[s.eventCard, { borderColor: c.hair, backgroundColor: c.card }]}>
          <Mono size={9} dim={3}>
            EVENT
          </Mono>
          <Display size={19}>{msg.event.title}</Display>
          <Mono size={9} dim={2}>
            {formatWhen(msg.event).toUpperCase()}
          </Mono>
          {msg.event.location ? (
            <Body size={12} dim={2}>
              {msg.event.location}
            </Body>
          ) : null}
          <Pressable
            onPress={() => onSaveEvent?.(msg.event!)}
            accessibilityRole="button"
            style={[s.eventBtn, { borderColor: c.ink }]}
          >
            <Display size={13}>Add to calendar</Display>
          </Pressable>
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

  // Money is a first-class message, not an attachment.
  if (msg.coin != null) {
    const tone = msg.reverted ? c.ink3 : c.coin;
    return (
      <View style={[s.slot, mine && s.right]}>
        <View
          style={[
            s.coinCard,
            { borderColor: tone, backgroundColor: msg.reverted ? 'transparent' : c.coin + '12' },
            mine ? s.coinRight : s.coinLeft,
            msg.reverted && s.dashed,
          ]}
        >
          <Mono size={9} color={tone}>
            {msg.reverted
              ? 'TAKEN BACK'
              : msg.pending
                ? 'SENDING'
                : msg.state === 'queued'
                  ? 'WAITING FOR A ROUTE'
                  : mine
                    ? 'SENT'
                    : 'RECEIVED'}
          </Mono>
          <View style={s.amtRow}>
            <CoinMark size={22} color={tone} />
            <Display
              size={27}
              color={tone}
              style={msg.reverted ? { textDecorationLine: 'line-through' } : undefined}
            >
              {msg.coin.toFixed(2)}
            </Display>
          </View>
          <Mono size={8.5} color={tone} style={{ opacity: 0.8 }}>
            {msg.reverted
              ? 'RETURNED · THE OTHER PHONE IS TOLD WHEN A ROUTE OPENS'
              : msg.hops
                ? `SIGNED ON DEVICE · RELAYED VIA ${msg.via?.toUpperCase()}`
                : 'SIGNED ON DEVICE · DIRECT'}
          </Mono>
        </View>
        <View style={{ marginTop: 4 }}>
          {msg.pending ? null : mine ? (
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
  dashed: { borderStyle: 'dashed' },
  photo: { width: 220, height: 220, borderRadius: radius.bubble, borderWidth: 1 },
  eventCard: { borderWidth: 1.5, borderRadius: radius.card, padding: 13, gap: 5, minWidth: 220 },
  eventBtn: {
    marginTop: 6,
    borderWidth: 1.5,
    borderRadius: 9,
    paddingVertical: 9,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: TOUCH_MIN - 8,
  },
  coinLeft: { borderBottomLeftRadius: radius.tail },
  coinRight: { borderBottomRightRadius: radius.tail },
  amtRow: { flexDirection: 'row', alignItems: 'center', gap: 7 },
});
