import { ReactNode } from 'react';
import { View, StatusBar, Pressable, StyleSheet, Dimensions } from 'react-native';
import { useTheme, TOUCH_MIN, space } from '../styles/theme';
import { Display, Mono } from './Type';

const TOP = StatusBar.currentHeight ?? 24;

// Android 15 draws us edge to edge, so the window already covers the navigation
// bar and there is no gap to measure. Reading the real inset needs
// react-native-safe-area-context, which is native and would mean a new
// dev-client APK — swap to it at the next rebuild. Until then reserve 48dp, the
// tallest Android nav bar (3-button); gesture bars are 24dp and just get a
// little extra room rather than covering anything.
const NAV_BAR_MAX = 48;
const screenH = Dimensions.get('screen').height;
const windowH = Dimensions.get('window').height;
const measured = Math.round(screenH - windowH - TOP);
const BOTTOM = measured > 0 ? Math.min(NAV_BAR_MAX, measured) : NAV_BAR_MAX;

export function Screen({ children }: { children: ReactNode }) {
  const { c } = useTheme();
  return <View style={[s.screen, { backgroundColor: c.paper, paddingTop: TOP }]}>{children}</View>;
}

/** The mesh states its own conditions at the top of every screen. No clock —
 *  the real one is two millimetres above it. */
export function MeshStatus({
  right = 'NO SIM · WI-FI OFF · BLE ON',
  state = 'live',
  onPress,
}: {
  right?: string;
  state?: 'off' | 'starting' | 'live' | 'error';
  onPress?: () => void;
}) {
  const { c } = useTheme();
  const dot = state === 'live' ? c.direct : state === 'starting' ? c.relay : c.dim;
  const body = (
    <View style={s.status}>
      <View style={[s.live, { backgroundColor: dot }]} />
      <Mono size={9} color={state === 'error' ? c.direct : undefined} numberOfLines={1}>
        {right}
      </Mono>
    </View>
  );
  if (!onPress) return body;
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={`Mesh ${state}. ${right}`}>
      {body}
    </Pressable>
  );
}

export function AppBar({
  title,
  sub,
  onBack,
  right,
}: {
  title: string;
  sub?: string;
  onBack?: () => void;
  right?: ReactNode;
}) {
  const { c } = useTheme();
  return (
    <View style={[s.bar, { borderBottomColor: c.hair2 }]}>
      {onBack ? (
        <Pressable onPress={onBack} hitSlop={12} style={s.back} accessibilityRole="button" accessibilityLabel="Back">
          <Display size={22} dim={2}>
            ‹
          </Display>
        </Pressable>
      ) : null}
      <View style={{ flex: 1, minWidth: 0 }}>
        <Display size={21} numberOfLines={1}>
          {title}
        </Display>
        {sub ? (
          <Mono size={9} style={s.caps} numberOfLines={1}>
            {sub}
          </Mono>
        ) : null}
      </View>
      {right ? <View style={s.barRight}>{right}</View> : null}
    </View>
  );
}

export type Tab = 'reach' | 'wallet' | 'tap';

export function BottomNav({ tab, onTab }: { tab: Tab; onTab: (t: Tab) => void }) {
  const { c } = useTheme();
  const items: { id: Tab; glyph: string; label: string }[] = [
    { id: 'reach', glyph: '◎', label: 'REACH' },
    { id: 'wallet', glyph: '◍', label: 'WALLET' },
    { id: 'tap', glyph: '⌁', label: 'MEET' },
  ];
  return (
    <View style={[s.nav, { backgroundColor: c.card, borderTopColor: c.hair2 }]}>
      {items.map((it) => {
        const on = it.id === tab;
        return (
          <Pressable
            key={it.id}
            onPress={() => onTab(it.id)}
            accessibilityRole="tab"
            accessibilityState={{ selected: on }}
            accessibilityLabel={it.label}
            style={[s.navItem, { borderTopColor: on ? c.direct : 'transparent' }]}
          >
            <Display size={16} color={on ? c.ink : c.ink3}>
              {it.glyph}
            </Display>
            <Mono size={8.5} color={on ? c.ink : c.ink3}>
              {it.label}
            </Mono>
          </Pressable>
        );
      })}
    </View>
  );
}

const s = StyleSheet.create({
  screen: { flex: 1 },
  status: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 14, paddingTop: 6, paddingBottom: 2 },
  live: { width: 6, height: 6, borderRadius: 3 },
  bar: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 14, paddingTop: 4, paddingBottom: 12, borderBottomWidth: 1 },
  back: { width: 22, alignItems: 'flex-start' },
  barRight: { flexShrink: 0, alignItems: 'flex-end', paddingLeft: 4 },
  caps: { textTransform: 'uppercase' },
  nav: { flexDirection: 'row', borderTopWidth: 1, paddingBottom: BOTTOM },
  navItem: { flex: 1, alignItems: 'center', gap: 1, paddingTop: 8, paddingBottom: 12, minHeight: TOUCH_MIN, borderTopWidth: 2 },
});

export { space, BOTTOM as bottomInset };
