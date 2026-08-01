// Local notifications for arriving messages.
//
// "Push" here is a misnomer worth being precise about: there is no server and
// no FCM, because there is no internet. A message arrives over Bluetooth and
// this posts a notification from the phone itself. That is strictly better for
// the offline story — nothing to register with, nothing to leak a token to.
import { AppState, Platform } from 'react-native';
import * as Notifications from 'expo-notifications';

let ready = false;

/** Foreground alerts are suppressed — you are already looking at the thread. */
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: AppState.currentState !== 'active',
    shouldShowList: true,
    shouldPlaySound: false,
    shouldSetBadge: false,
  }),
});

export async function prepareNotifications(): Promise<boolean> {
  if (ready) return true;
  try {
    if (Platform.OS === 'android') {
      await Notifications.setNotificationChannelAsync('messages', {
        name: 'Messages',
        importance: Notifications.AndroidImportance.HIGH,
        // Matches the direct-hop colour, so the notification belongs to the app.
        lightColor: '#EE3E2B',
        vibrationPattern: [0, 60, 40, 60],
      });
    }

    const existing = await Notifications.getPermissionsAsync();
    const granted =
      existing.granted || (await Notifications.requestPermissionsAsync()).granted;
    ready = granted;
    return granted;
  } catch {
    // Notifications are a courtesy. Never let them stop the mesh from running.
    return false;
  }
}

/**
 * Post one notification for a message that just landed. Silent while the app is
 * in the foreground — the message is already on screen.
 */
export async function notifyMessage(opts: {
  from: string;
  body: string;
  threadId: string;
  hops: number | null;
}): Promise<void> {
  if (!ready || AppState.currentState === 'active') return;
  try {
    await Notifications.scheduleNotificationAsync({
      content: {
        title: opts.from,
        body: opts.body,
        // The route is part of the message here, not a detail.
        subtitle: opts.hops ? `Relayed · ${opts.hops + 1} hops` : 'Direct',
        data: { threadId: opts.threadId },
      },
      trigger: null, // now
    });
  } catch {
    // A failed notification must never take the message down with it.
  }
}
