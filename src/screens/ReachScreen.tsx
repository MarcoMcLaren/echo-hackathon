import { useState } from 'react';
import { View, ScrollView, Pressable, StyleSheet } from 'react-native';
import { useTheme, TOUCH_MIN } from '../styles/theme';
import { Display, Body, Mono } from '../components/Type';
import { MeshStatus, AppBar } from '../components/Chrome';
import Avatar from '../components/Avatar';
import { HopChip } from '../components/Chip';
import ReachMap, { type MapNode } from '../features/messaging/components/ReachMap';
import RemoveSheet from '../features/messaging/components/RemoveSheet';
import { useMesh } from '../store/mesh';
import type { Thread } from '../store/types';

export default function ReachScreen({
  onOpen,
  onNewGroup,
}: {
  onOpen: (id: string) => void;
  onNewGroup: () => void;
}) {
  const { c, mode, cycle } = useTheme();
  const { status, error, peers, threads, contacts, stats, start, stop, unpair, forgetThread } =
    useMesh();
  const [removing, setRemoving] = useState<Thread | null>(null);

  const live = Object.keys(peers).length;

  const statusLine =
    status === 'live'
      ? `MESH LIVE · ${live} NODE${live === 1 ? '' : 'S'} IN RANGE · TAP TO STOP`
      : status === 'starting'
        ? 'STARTING MESH'
        : status === 'error'
          ? (error ?? 'MESH FAILED').toUpperCase()
          : 'MESH OFF · TAP TO START';

  // Everything in range goes on the map, but only people you have met are
  // named. The rest are nodes: they carry traffic and nothing else.
  const nodes: MapNode[] = Object.entries(peers).map(([id, p]) => ({
    id,
    name: contacts[id]?.name ?? p.display,
    hops: 0,
    stranger: !contacts[id],
  }));
  const strangers = nodes.filter((n) => n.stranger).length;

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
            ? `${Object.keys(contacts).length} contacts · ${strangers} relaying · ${stats.relayed} carried`
            : 'Mesh off · nothing is listening'
        }
        right={
          <View style={s.actions}>
            <Pressable
              onPress={cycle}
              hitSlop={14}
              accessibilityRole="button"
              accessibilityLabel={`Theme: ${mode}. Tap to change.`}
            >
              <Mono size={9}>{mode.toUpperCase()}</Mono>
            </Pressable>
            <Pressable
              onPress={onNewGroup}
              hitSlop={14}
              accessibilityRole="button"
              accessibilityLabel="New group"
              style={[s.plus, { borderColor: c.hair }]}
            >
              <Display size={17} dim={1}>
                +
              </Display>
            </Pressable>
          </View>
        }
      />
      <ScrollView contentContainerStyle={s.body} showsVerticalScrollIndicator={false}>
        <ReachMap nodes={nodes} />

        <Mono size={10} style={s.caps}>
          Conversations
        </Mono>

        {threads.length === 0 ? (
          <View style={[s.empty, { borderColor: c.hair2 }]}>
            <Body size={13} dim={2}>
              {status !== 'live'
                ? 'Tap the line above to start the mesh, then meet someone with a phone tap or a scanned code.'
                : strangers > 0
                  ? `${strangers} phone${strangers === 1 ? '' : 's'} in range ${strangers === 1 ? 'is' : 'are'} carrying messages for the mesh, but being nearby is not the same as knowing someone. Go to Meet and tap or scan a code to start a conversation.`
                  : 'Nobody yet. Go to Meet and hold the phones together, or scan a code, to add someone.'}
            </Body>
          </View>
        ) : null}

        <View>
          {threads.map((t, i) => (
            <Pressable
              key={t.id}
              onPress={() => onOpen(t.id)}
              onLongPress={() => setRemoving(t)}
              delayLongPress={400}
              accessibilityRole="button"
              accessibilityLabel={`${t.title}. ${t.hops === null ? 'No route' : t.hops === 0 ? 'Direct' : `Via ${t.via}`}`}
              accessibilityHint={t.group ? 'Hold to leave this group' : 'Hold to remove this phone'}
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

        {threads.length > 0 ? (
          <Mono size={8.5} style={{ alignSelf: 'center', marginTop: 6 }}>
            HOLD A CONVERSATION TO REMOVE IT
          </Mono>
        ) : null}
      </ScrollView>

      {removing ? (
        <RemoveSheet
          thread={removing}
          onCancel={() => setRemoving(null)}
          onConfirm={() => {
            // A group has no peer behind it, so there is nothing to block —
            // leaving is just forgetting it.
            if (removing.group) forgetThread(removing.id);
            else unpair(removing.id);
            setRemoving(null);
          }}
        />
      ) : null}
    </>
  );
}

const s = StyleSheet.create({
  body: { paddingHorizontal: 14, paddingTop: 12, paddingBottom: 20, gap: 12 },
  conv: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 10, minHeight: TOUCH_MIN },
  col: { flex: 1, minWidth: 0, gap: 1 },
  right: { alignItems: 'flex-end', gap: 4 },
  unread: { minWidth: 18, paddingHorizontal: 5, paddingVertical: 2, borderRadius: 9, alignItems: 'center' },
  actions: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  plus: { width: 30, height: 30, borderRadius: 15, borderWidth: 1.5, alignItems: 'center', justifyContent: 'center' },
  empty: { borderWidth: 1, borderStyle: 'dashed', borderRadius: 14, padding: 16 },
  caps: { textTransform: 'uppercase' },
});
