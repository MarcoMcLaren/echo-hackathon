import { useState } from 'react';
import { View, Pressable, TextInput, StyleSheet } from 'react-native';
import { useTheme, radius, TOUCH_MIN } from '../../../styles/theme';
import { Display, Mono } from '../../../components/Type';
import type { MeshEvent } from '../api/events';

/**
 * Presets instead of a date picker. A picker means another native dependency
 * and a rebuild, and at a braai nobody is scrolling to a date — they mean
 * tonight, tomorrow, or the weekend.
 */
function presets(): { label: string; at: number }[] {
  const now = new Date();
  const at = (addDays: number, hour: number) => {
    const d = new Date(now);
    d.setDate(d.getDate() + addDays);
    d.setHours(hour, 0, 0, 0);
    return d.getTime();
  };
  const daysToSaturday = (6 - now.getDay() + 7) % 7 || 7;
  return [
    { label: 'Tonight 18:00', at: at(0, 18) },
    { label: 'Tomorrow 14:00', at: at(1, 14) },
    { label: 'Saturday 14:00', at: at(daysToSaturday, 14) },
  ];
}

export default function EventComposer({
  onCancel,
  onSend,
}: {
  onCancel: () => void;
  onSend: (event: MeshEvent) => void;
}) {
  const { c } = useTheme();
  const slots = presets();
  const [title, setTitle] = useState('');
  const [where, setWhere] = useState('');
  const [when, setWhen] = useState(slots[0].at);

  const ready = title.trim().length > 0;

  return (
    <View style={[s.wrap, { backgroundColor: c.card, borderTopColor: c.hair2 }]}>
      <Mono size={9} style={s.caps}>
        New event
      </Mono>

      <TextInput
        value={title}
        onChangeText={setTitle}
        placeholder="What is happening"
        placeholderTextColor={c.ink3}
        style={[s.field, { backgroundColor: c.paper, borderColor: c.hair2, color: c.ink }]}
      />
      <TextInput
        value={where}
        onChangeText={setWhere}
        placeholder="Where (optional)"
        placeholderTextColor={c.ink3}
        style={[s.field, { backgroundColor: c.paper, borderColor: c.hair2, color: c.ink }]}
      />

      <View style={s.slots}>
        {slots.map((sl) => {
          const on = sl.at === when;
          return (
            <Pressable
              key={sl.label}
              onPress={() => setWhen(sl.at)}
              accessibilityRole="radio"
              accessibilityState={{ selected: on }}
              style={[
                s.slot,
                { borderColor: on ? c.ink : c.hair, backgroundColor: on ? c.ink : 'transparent' },
              ]}
            >
              <Mono size={8.5} color={on ? c.paper : c.ink2}>
                {sl.label.toUpperCase()}
              </Mono>
            </Pressable>
          );
        })}
      </View>

      <View style={s.row}>
        <Pressable onPress={onCancel} accessibilityRole="button" style={[s.btn, s.ghost, { borderColor: c.hair }]}>
          <Display size={14}>Cancel</Display>
        </Pressable>
        <Pressable
          onPress={() => ready && onSend({ title: title.trim(), startsAt: when, location: where.trim() || undefined })}
          disabled={!ready}
          accessibilityRole="button"
          style={[s.btn, { backgroundColor: ready ? c.ink : c.sunk, flex: 1 }]}
        >
          <Display size={14} color={ready ? c.paper : c.ink3}>
            Send event
          </Display>
        </Pressable>
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  wrap: { padding: 14, gap: 9, borderTopWidth: 1 },
  field: { borderWidth: 1, borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, fontSize: 13.5, minHeight: 44 },
  slots: { flexDirection: 'row', gap: 6 },
  slot: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingVertical: 8, borderRadius: radius.pill, borderWidth: 1.5, minHeight: 36 },
  row: { flexDirection: 'row', gap: 8 },
  btn: { borderRadius: 10, paddingVertical: 11, paddingHorizontal: 18, alignItems: 'center', justifyContent: 'center', minHeight: TOUCH_MIN },
  ghost: { borderWidth: 1.5 },
  caps: { textTransform: 'uppercase' },
});
