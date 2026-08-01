// Who can I get to right now — answered before the list answers "who said what".
// Drawn with Views rather than SVG so we add no native dependency: a line is a
// thin View rotated about its left edge.
import { useState } from 'react';
import { View, StyleSheet, LayoutChangeEvent } from 'react-native';
import { useTheme } from '../../../styles/theme';
import { Mono } from '../../../components/Type';

type P = { x: number; y: number };

function Line({ a, b, color, w = 3 }: { a: P; b: P; color: string; w?: number }) {
  const len = Math.hypot(b.x - a.x, b.y - a.y);
  const angle = Math.atan2(b.y - a.y, b.x - a.x);
  return (
    <View
      style={{
        position: 'absolute',
        left: a.x,
        top: a.y - w / 2,
        width: len,
        height: w,
        borderRadius: w / 2,
        backgroundColor: color,
        transformOrigin: 'left center',
        transform: [{ rotate: `${angle}rad` }],
      }}
    />
  );
}

function Station({ at, color, fill, r = 5.5 }: { at: P; color: string; fill?: string; r?: number }) {
  return (
    <View
      style={{
        position: 'absolute',
        left: at.x - r,
        top: at.y - r,
        width: r * 2,
        height: r * 2,
        borderRadius: r,
        backgroundColor: fill ?? color,
        borderWidth: fill ? 3 : 0,
        borderColor: color,
      }}
    />
  );
}

function Label({ at, text, faint }: { at: P; text: string; faint?: boolean }) {
  return (
    <View style={{ position: 'absolute', left: at.x - 40, top: at.y, width: 80, alignItems: 'center' }}>
      <Mono size={8} style={{ opacity: faint ? 0.55 : 1 }}>
        {text}
      </Mono>
    </View>
  );
}

const H = 178;
const R1 = 52; // direct BLE reach
const R2 = 86; // edge of the mesh, one hop out

function Ring({ at, r, color }: { at: P; r: number; color: string }) {
  return (
    <View
      style={[
        s.ring,
        { left: at.x - r, top: at.y - r, width: r * 2, height: r * 2, borderRadius: r, borderColor: color },
      ]}
    />
  );
}

export type MapNode = {
  id: string;
  name: string;
  hops: number | null;
  /** A phone in range you have never met. It relays; it is not a contact. */
  stranger?: boolean;
};

/**
 * Positions are geometry, not decoration: a direct peer sits inside your radio
 * ring, a relayed one sits outside it but hangs off the peer that carries it,
 * and an unreachable one sits beyond everything with no line at all. Reading
 * the picture should tell you the same thing as reading the hop count.
 */
export default function ReachMap({ nodes }: { nodes: MapNode[] }) {
  const { c } = useTheme();
  const [w, setW] = useState(0);
  const onLayout = (e: LayoutChangeEvent) => setW(e.nativeEvent.layout.width);

  const cx = w / 2;
  const you: P = { x: cx, y: H - 46 };

  const direct = nodes.filter((n) => n.hops === 0);
  const relayed = nodes.filter((n) => n.hops !== null && n.hops > 0);
  const gone = nodes.filter((n) => n.hops === null);

  // Direct peers fan across the top of the inner ring.
  const place = (i: number, count: number, radius: number): P => {
    const spread = Math.PI * 0.62;
    const a = count === 1 ? -Math.PI / 2 : -Math.PI / 2 - spread / 2 + (spread * i) / (count - 1);
    return { x: you.x + Math.cos(a) * radius, y: you.y + Math.sin(a) * radius };
  };

  const directAt = direct.map((_, i) => place(i, direct.length, R1 - 6));
  // Each relayed peer hangs off a direct one — the phone actually carrying it.
  const relayedAt = relayed.map((_, i) => {
    const anchor = directAt[i % Math.max(1, directAt.length)] ?? you;
    const dx = anchor.x - you.x;
    return {
      x: Math.max(28, Math.min(w - 28, anchor.x + (dx >= 0 ? 74 : -74))),
      y: Math.max(20, anchor.y - 34),
    };
  });

  return (
    <View style={{ height: H, overflow: 'hidden' }} onLayout={onLayout}>
      {w > 0 && (
        <>
          <Ring at={you} r={R1} color={c.hair} />
          <Ring at={you} r={R2} color={c.hair2} />

          {directAt.map((p, i) => (
            <Line key={`dl${i}`} a={you} b={p} color={direct[i].stranger ? c.hair : c.direct} />
          ))}
          {relayedAt.map((p, i) => (
            <Line
              key={`rl${i}`}
              a={directAt[i % Math.max(1, directAt.length)] ?? you}
              b={p}
              color={c.relay}
            />
          ))}

          {directAt.map((p, i) => (
            <Station
              key={`ds${i}`}
              at={p}
              // A stranger is drawn hollow and grey: present, carrying traffic,
              // but not someone you know.
              color={direct[i].stranger ? c.dim : c.direct}
              fill={c.paper}
            />
          ))}
          {relayedAt.map((p, i) => (
            <Station key={`rs${i}`} at={p} color={c.relay} fill={c.paper} />
          ))}
          {gone.map((_, i) => (
            <Station
              key={`gs${i}`}
              at={{ x: Math.min(w - 24, you.x + 118 + i * 22), y: you.y - 4 }}
              color={c.dim}
              r={5}
            />
          ))}
          <Station at={you} color={c.ink} r={7} />

          <Label at={{ x: you.x, y: you.y + 11 }} text="YOU" />
          {directAt.map((p, i) => (
            <Label
              key={`dt${i}`}
              at={{ x: p.x, y: p.y - 21 }}
              // Strangers are not named. You have not met them, and showing a
              // device model would imply you had.
              text={direct[i].stranger ? 'NODE' : label(direct[i].name)}
              faint={direct[i].stranger}
            />
          ))}
          {relayedAt.map((p, i) => (
            <Label key={`rt${i}`} at={{ x: p.x, y: p.y - 21 }} text={label(relayed[i].name)} />
          ))}
          {gone.map((n, i) => (
            <Label
              key={`gt${i}`}
              at={{ x: Math.min(w - 24, you.x + 118 + i * 22), y: you.y + 10 }}
              text={label(n.name)}
              faint
            />
          ))}
        </>
      )}
    </View>
  );
}

const label = (name: string) => name.split(' ')[0].toUpperCase().slice(0, 8);

const s = StyleSheet.create({
  ring: { position: 'absolute', borderWidth: 1, borderStyle: 'dashed' },
});
