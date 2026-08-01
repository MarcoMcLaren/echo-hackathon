import { useState } from 'react';
import { View, TextInput, Pressable, StyleSheet, KeyboardAvoidingView, Platform } from 'react-native';
import { useTheme, radius, TOUCH_MIN } from '../styles/theme';
import { Display, Body, Mono } from '../components/Type';
import { bottomInset } from '../components/Chrome';
import { useMesh } from '../store/mesh';

const MAX = 24;

/**
 * First launch. One question, because it is the only thing we cannot work out
 * for ourselves: what other people should call this phone. The id is minted
 * here too, so a fresh setup is genuinely a fresh identity rather than the same
 * phone wearing a new label.
 */
export default function SetupScreen() {
  const { c } = useTheme();
  const createIdentity = useMesh((s) => s.createIdentity);
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);

  const trimmed = name.trim();
  const ok = trimmed.length > 0 && !busy;

  const go = async () => {
    if (!ok) return;
    setBusy(true);
    await createIdentity(trimmed);
  };

  return (
    <KeyboardAvoidingView
      style={[s.wrap, { backgroundColor: c.paper }]}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <View style={s.mid}>
        <Mono size={10} style={s.caps}>
          Set up Echo
        </Mono>
        <Display size={40} style={s.h}>
          What should people call you?
        </Display>
        <Body size={14} dim={2} style={s.p}>
          This is the name on your pairing code, and the name in other people’s chats. Nothing
          leaves this phone until you tap or scan with someone.
        </Body>

        <TextInput
          value={name}
          onChangeText={(t) => setName(t.slice(0, MAX))}
          placeholder="Your name"
          placeholderTextColor={c.ink3}
          autoFocus
          returnKeyType="done"
          onSubmitEditing={go}
          accessibilityLabel="Your name"
          style={[s.field, { backgroundColor: c.card, borderColor: c.hair, color: c.ink }]}
        />
        <Mono size={8.5}>{`${trimmed.length}/${MAX}`}</Mono>
      </View>

      <View style={[s.foot, { paddingBottom: bottomInset + 24 }]}>
        <Pressable
          onPress={go}
          disabled={!ok}
          accessibilityRole="button"
          accessibilityState={{ disabled: !ok }}
          style={[s.btn, { backgroundColor: ok ? c.ink : c.sunk }]}
        >
          <Display size={16} color={ok ? c.paper : c.ink3}>
            {busy ? 'Setting up…' : 'Start'}
          </Display>
        </Pressable>
        <Mono size={8.5} style={{ alignSelf: 'center' }}>
          A NEW KEY IS MADE FOR THIS PHONE AND NEVER LEAVES IT
        </Mono>
      </View>
    </KeyboardAvoidingView>
  );
}

const s = StyleSheet.create({
  wrap: { flex: 1, justifyContent: 'space-between', paddingHorizontal: 26, paddingTop: 90 },
  mid: { flex: 1, gap: 14 },
  h: { lineHeight: 42 },
  p: { maxWidth: 330 },
  field: {
    borderWidth: 1.5,
    borderRadius: radius.card,
    paddingHorizontal: 16,
    paddingVertical: 14,
    fontSize: 20,
    marginTop: 6,
    minHeight: 56,
  },
  foot: { gap: 12 },
  btn: { borderRadius: 10, paddingVertical: 15, alignItems: 'center', justifyContent: 'center', minHeight: TOUCH_MIN },
  caps: { textTransform: 'uppercase' },
});
