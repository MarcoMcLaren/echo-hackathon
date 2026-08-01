import { View, ScrollView, Pressable, StyleSheet } from 'react-native';
import { useTheme, TOUCH_MIN } from '../styles/theme';
import { Display, Body, Mono } from '../components/Type';
import { MeshStatus, AppBar } from '../components/Chrome';
import Avatar from '../components/Avatar';
import { HopChip } from '../components/Chip';
import ReachMap, { type MapNode } from '../features/messaging/components/ReachMap';
import { useMesh } from '../store/mesh';
import { contacts as demoContacts } from '../store/mock';

export default function ReachScreen({ onOpen }: { onOpen: (id: string) => void }) {
  const { c, mode, cycle } = useTheme();
  const { status, error, peers, threads, stats, start, stop } = useMesh();

  const live = Object.keys(peers).length;

  const statusLine =
    status === 'live'
      ? `MESH LIVE · ${live} PEER${live === 1 ? '' : 'S'} · TAP TO STOP`
      : status === 'starting'
        ? 'STARTING MESH'
        : status === 'error'
          ? (error ?? 'MESH FAILED').toUpperCase()
          : 'MESH OFF · TAP TO START';

  // Real peers when the mesh is up; the seeded demo when it isn't, so a single
  // phone still shows what the screen is for.
  const nodes: MapNode[] =
    status === 'live' && Object.keys(peers).length > 0
      ? Object.entries(peers).map(([id, p]) => ({ id, name: p.display, hops: 0 }))
      : demoContacts.map((p) => ({ id: p.id, name: p.name, hops: p.hops }));

  return (
    <>
      <MeshStatus
        right={statusLine}
        state={status}
        onPress={status === 'live' ? stop : status === 'starting' ? undefined : start}
      />
      <AppBar
        title="Reach"
        sub={
          status === 'live'
            ? `${live} reachable · ${stats.relayed} relayed for others`
            : 'Mesh off · showing the demo set'
        }
        right={
          <Pressable
            onPress={cycle}
            hitSlop={14}
            accessibilityRole="button"
            accessibilityLabel={`Theme: ${mode}. Tap to change.`}
          >
            <Mono size={9}>{mode.toUpperCase()}</Mono>
          </Pressable>
        }
      />
      <ScrollView contentContainerStyle={s.body} showsVerticalScrollIndicator={false}>
        <ReachMap nodes={nodes} />

        <Mono size={10} style={s.caps}>
          Conversations
        </Mono>

        <View>
          {threads.map((t, i) => (
            <Pressable
              key={t.id}
              onPress={() => onOpen(t.id)}
              accessibilityRole="button"
              accessibilityLabel={`${t.title}. ${t.hops === null ? 'No route' : t.hops === 0 ? 'Direct' : `Via ${t.via}`}`}
              style={({ pressed }) => [
                s.conv,
                { borderBottomColor: c.hair2, borderBottomWidth: i === threads.length - 1 ? 0 : 1 },
                pressed && { backgroundColor: c.hair2 },
              ]}
            >
              <Avatar initials={t.initials} hops={t.hops} />
              <View style={s.col}>
                <Display size={14}>{t.title}</Display>
                <Body size={11.5} dim={t.unread ? 1 : 2} numberOfLines={1}>
                  {t.preview}
                </Body>
              </View>
              <View style={s.right}>
                {t.unread ? (
                  <View style={[s.unread, { backgroundColor: c.ink }]}>
                    <Mono size={8.5} color={c.paper}>
                      {t.unread}
                    </Mono>
                  </View>
                ) : (
                  <Mono size={9}>{t.at}</Mono>
                )}
                <HopChip
                  hops={t.hops}
                  via={t.via}
                  label={t.group ? `${t.members!.length} in mesh` : undefined}
                />
              </View>
            </Pressable>
          ))}
        </View>
      </ScrollView>
    </>
  );
}

const s = StyleSheet.create({
  body: { paddingHorizontal: 14, paddingTop: 12, paddingBottom: 20, gap: 12 },
  conv: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 10, minHeight: TOUCH_MIN },
  col: { flex: 1, minWidth: 0, gap: 1 },
  right: { alignItems: 'flex-end', gap: 4 },
  unread: { minWidth: 18, paddingHorizontal: 5, paddingVertical: 2, borderRadius: 9, alignItems: 'center' },
  caps: { textTransform: 'uppercase' },
});
