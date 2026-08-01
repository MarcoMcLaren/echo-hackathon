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
import ReadScreen from './screens/ReadScreen';
// Side-effect import: this module calls initExecutorch(), which is the only
// thing that registers the ExecuTorch resource fetcher. Without it every model
// load fails with ResourceFetcherAdapterNotInitialized — an error the library
// logs but never surfaces through the hook, so the UI would hang on 0% forever.
import './services/models';

// Hand-rolled navigation: three tabs and a one-deep stack. react-navigation would
// pull in react-native-screens + safe-area-context, which means a new dev-client
// APK; this way the whole UI hot-reloads on the build we already have.
type Route = { name: 'chat'; id: string } | { name: 'send'; id: string } | null;

export default function App() {
  // Follows the system by default; the header control overrides it so dark mode
  // is always reachable on a demo phone whatever the OS is set to.
  const system = useColorScheme();
  const [mode, setMode] = useState<Mode>('system');
  const [tab, setTab] = useState<Tab>('reach');
  const [route, setRoute] = useState<Route>(null);
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
            <SendCoinScreen contactId={route.id} onBack={back} />
          ) : tab === 'reach' ? (
            <ReachScreen onOpen={(id) => setRoute({ name: 'chat', id })} />
          ) : tab === 'wallet' ? (
            <WalletScreen
              onSend={() => setRoute({ name: 'send', id: 'naledi' })}
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
