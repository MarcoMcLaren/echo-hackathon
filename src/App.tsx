import { useCallback, useEffect, useMemo, useState } from 'react';
import { BackHandler, View, useColorScheme } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { ThemeContext, light, dark, type Mode } from './styles/theme';
import { Screen, BottomNav, type Tab } from './components/Chrome';
import ReachScreen from './screens/ReachScreen';
import ChatScreen from './screens/ChatScreen';
import WalletScreen from './screens/WalletScreen';
import TapScreen from './screens/TapScreen';
import SendCoinScreen from './screens/SendCoinScreen';
import LockScreen from './screens/LockScreen';
import NewGroupScreen from './screens/NewGroupScreen';
import SetupScreen from './screens/SetupScreen';
import { useMesh } from './store/mesh';
import ReadScreen from './screens/ReadScreen';
// Side-effect import: this module calls initExecutorch(), which is the only
// thing that registers the ExecuTorch resource fetcher. Without it every model
// load fails with ResourceFetcherAdapterNotInitialized — an error the library
// logs but never surfaces through the hook, so the UI would hang on 0% forever.
import './services/models';

// Hand-rolled navigation: three tabs and a one-deep stack. react-navigation would
// pull in react-native-screens + safe-area-context, which means a new dev-client
// APK; this way the whole UI hot-reloads on the build we already have.
type Route =
  | { name: 'chat'; id: string }
  | { name: 'send'; id: string }
  | { name: 'newgroup' }
  | null;

export default function App() {
  // Follows the system by default; the header control overrides it so dark mode
  // is always reachable on a demo phone whatever the OS is set to.
  const system = useColorScheme();
  const [mode, setMode] = useState<Mode>('system');
  const [tab, setTab] = useState<Tab>('reach');
  const [route, setRoute] = useState<Route>(null);
  // Once past the door it stays open for the life of the launch — re-prompting
  // every time you glance at another app would make the mesh unusable.
  const [unlocked, setUnlocked] = useState(false);
  const ready = useMesh((s) => s.ready);
  // Switching tabs mid-read unmounts ReadScreen, and executorch's cleanup
  // throws ModelGenerating if inference is still running. Lock the nav instead.
  const [readBusy, setReadBusy] = useState(false);

  const isDark = mode === 'system' ? system === 'dark' : mode === 'dark';

  const theme = useMemo(
    () => ({
      c: isDark ? dark : light,
      isDark,
      mode,
      cycle: () => setMode((m) => (m === 'system' ? 'light' : m === 'light' ? 'dark' : 'system')),
    }),
    [isDark, mode]
  );

  const back = useCallback(() => setRoute(null), []);

  // Claim this phone's identity before anything can ask for it — the pairing
  // code has to encode a real device id even if the mesh is never started.
  useEffect(() => {
    useMesh.getState().init();
  }, []);

  useEffect(() => {
    const sub = BackHandler.addEventListener('hardwareBackPress', () => {
      if (route) {
        back();
        return true;
      }
      return false;
    });
    return () => sub.remove();
  }, [route, back]);

  // Nothing behind the lock is rendered until it opens, so a shoulder-surfer
  // can't read a thread off the screen behind a modal.
  if (!unlocked) {
    return (
      <ThemeContext.Provider value={theme}>
        <LockScreen onUnlocked={() => setUnlocked(true)} />
        <StatusBar style={isDark ? 'light' : 'dark'} />
      </ThemeContext.Provider>
    );
  }

  // Never set up, or just reset: ask for a name before anything else. This is
  // also what mints the phone's id, so there is no identity to leak beforehand.
  if (!ready) {
    return (
      <ThemeContext.Provider value={theme}>
        <SetupScreen />
        <StatusBar style={isDark ? 'light' : 'dark'} />
      </ThemeContext.Provider>
    );
  }

  return (
    <ThemeContext.Provider value={theme}>
      <Screen>
        <View style={{ flex: 1 }}>
          {route?.name === 'chat' ? (
            <ChatScreen
              threadId={route.id}
              onBack={back}
              onSendCoin={(id) => setRoute({ name: 'send', id })}
            />
          ) : route?.name === 'send' ? (
            <SendCoinScreen
              contactId={route.id}
              onBack={back}
              onQueued={(id) => setRoute({ name: 'chat', id })}
            />
          ) : route?.name === 'newgroup' ? (
            <NewGroupScreen
              onBack={back}
              onCreated={(id) => setRoute({ name: 'chat', id })}
            />
          ) : tab === 'reach' ? (
            <ReachScreen
              onOpen={(id) => setRoute({ name: 'chat', id })}
              onNewGroup={() => setRoute({ name: 'newgroup' })}
            />
          ) : tab === 'wallet' ? (
            <WalletScreen
              // Money goes to a conversation, so send starts by choosing one.
              // Reach is that list; there is no separate contact picker.
              onSend={() => setTab('reach')}
              onTap={() => setTab('tap')}
            />
          ) : tab === 'tap' ? (
            <TapScreen />
          ) : tab === 'read' ? (
            <ReadScreen onBusyChange={setReadBusy} />
          ) : null}
        </View>

        {route ? null : <BottomNav tab={tab} onTab={setTab} disabled={readBusy} />}
      </Screen>
      <StatusBar style={isDark ? 'light' : 'dark'} />
    </ThemeContext.Provider>
  );
}
