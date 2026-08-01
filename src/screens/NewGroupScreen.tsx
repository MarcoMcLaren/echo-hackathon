import { useState } from 'react';
import { View, ScrollView, Pressable, TextInput, StyleSheet } from 'react-native';
import { useTheme, radius, TOUCH_MIN } from '../styles/theme';
import { Display, Body, Mono } from '../components/Type';
import { MeshStatus, AppBar, bottomInset } from '../components/Chrome';
import Avatar from '../components/Avatar';
import { useMesh } from '../store/mesh';

/**
 * A group is made from phones you can reach right now. There is no server
 * holding a roster, so everyone you pick has to be told — and being told is a
 * message like any other, which means it can arrive late or by relay.
 */
export default function NewGroupScreen({
  onBack,
  onCreated,
}: {
  onBack: () => void;
  onCreated: (threadId: string) => void;
}) {
  const { c } = useTheme();
  const peers = useMesh((s) => s.peers);
  const status = useMesh((s) => s.status);
  const createGroup = useMesh((s) => s.createGroup);

  const [name, setName] = useState('');
  const [picked, setPicked] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);

  const reachable = Object.entries(peers);
  const canCreate = name.trim().length > 0 && picked.length > 0 && !busy;

  const toggle = (id: string) =>
    setPicked((p) => (p.includes(id) ? p.filter((x) => x !== id) : [...p, id]));

  const create = async () => {
    if (!canCreate) return;
    setBusy(true);
    const id = await createGroup(name.trim(), picked);
    onCreated(id);
  };

  return (
    <>
      <MeshStatus right={status === 'live' ? 'MESH LIVE' : 'MESH OFF'} state={status} />
      <AppBar title="New group" sub="Pick from phones you can reach" onBack={onBack} />

      <ScrollView contentContainerStyle={s.body} showsVerticalScrollIndicator={false}>
        <TextInput
          value={name}
          onChangeText={setName}
          placeholder="Group name"
          placeholderTextColor={c.ink3}
          style={[s.field, { backgroundColor: c.card, borderColor: c.hair2, color: c.ink }]}
        />

        <Mono size={10} style={s.caps}>
          {reachable.length ? `${reachable.length} reachable now` : 'Nobody reachable'}
        </Mono>

        {reachable.length === 0 ? (
          <View style={[s.empty, { borderColor: c.hair2 }]}>
            <Body size={13} dim={2}>
              {status === 'live'
                ? 'No other phones in range yet. A group can only start with people you can reach — turn on Echo on another phone and it will appear here.'
                : 'Start the mesh from the Reach screen first, then the phones around you will show up here.'}
            </Body>
          </View>
        ) : (
          <View>
            {reachable.map(([id, p], i) => {
              const on = picked.includes(id);
              return (
                <Pressable
                  key={id}
                  onPress={() => toggle(id)}
                  accessibilityRole="checkbox"
                  accessibilityState={{ checked: on }}
                  accessibilityLabel={p.display}
                  style={({ pressed }) => [
                    s.row,
                    {
                      borderBottomColor: c.hair2,
                      borderBottomWidth: i === reachable.length - 1 ? 0 : 1,
                    },
                    pressed && { backgroundColor: c.hair2 },
                  ]}
                >
                  <Avatar initials={p.display.slice(0, 2).toUpperCase()} hops={0} />
                  <View style={{ flex: 1, minWidth: 0 }}>
                    <Display size={14}>{p.display}</Display>
                    <Mono size={8.5}>IN BLUETOOTH RANGE</Mono>
                  </View>
                  <View
                    style={[
                      s.tick,
                      { borderColor: on ? c.direct : c.hair, backgroundColor: on ? c.direct : 'transparent' },
                    ]}
                  >
                    {on ? (
                      <Display size={12} color={c.paper}>
                        ✓
                      </Display>
                    ) : null}
                  </View>
                </Pressable>
              );
            })}
          </View>
        )}
      </ScrollView>

      <View style={[s.foot, { paddingBottom: bottomInset + 16, borderTopColor: c.hair2, backgroundColor: c.card }]}>
        <Pressable
          onPress={create}
          disabled={!canCreate}
          accessibilityRole="button"
          style={[s.btn, { backgroundColor: canCreate ? c.ink : c.sunk }]}
        >
          <Display size={15} color={canCreate ? c.paper : c.ink3}>
            {busy ? 'Telling everyone…' : `Create with ${picked.length}`}
          </Display>
        </Pressable>
        <Mono size={8.5} style={{ alignSelf: 'center' }}>
          EVERYONE PICKED GETS TOLD OVER THE MESH
        </Mono>
      </View>
    </>
  );
}

const s = StyleSheet.create({
  body: { paddingHorizontal: 14, paddingTop: 12, paddingBottom: 20, gap: 12 },
  field: { borderWidth: 1, borderRadius: radius.card, paddingHorizontal: 14, paddingVertical: 12, fontSize: 15, minHeight: TOUCH_MIN },
  row: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 10, minHeight: TOUCH_MIN },
  tick: { width: 24, height: 24, borderRadius: 12, borderWidth: 1.5, alignItems: 'center', justifyContent: 'center' },
  empty: { borderWidth: 1, borderStyle: 'dashed', borderRadius: radius.card, padding: 16 },
  foot: { paddingHorizontal: 14, paddingTop: 12, gap: 8, borderTopWidth: 1 },
  btn: { borderRadius: 10, paddingVertical: 13, alignItems: 'center', justifyContent: 'center', minHeight: TOUCH_MIN },
  caps: { textTransform: 'uppercase' },
});
