// Local notifications for arriving messages — ported from
// features/messaging/api/notify.ts.
//
// "Push" here is a misnomer worth being precise about: there is no server and
// no FCM, because there is no internet. A message arrives over Bluetooth and
// this posts a notification from the phone itself. That is strictly better
// for the offline story — nothing to register with, nothing to leak a token
// to.
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _channelId = 'messages';

final _plugin = FlutterLocalNotificationsPlugin();
bool _ready = false;

Future<bool> prepareNotifications() async {
  if (_ready) return true;
  try {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(AndroidNotificationChannel(
      _channelId,
      'Messages',
      importance: Importance.high,
      // Matches the direct-hop colour, so the notification belongs to the app.
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 60, 40, 60]),
    ));

    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));

    final granted = await android?.requestNotificationsPermission() ?? false;
    _ready = granted;
    return granted;
  } catch (_) {
    // Notifications are a courtesy. Never let them stop the mesh from running.
    return false;
  }
}

/// Post one notification for a message that just landed. Silent while the
/// app is in the foreground — the message is already on screen.
Future<void> notifyMessage({
  required String from,
  required String body,
  required String threadId,
  required int? hops,
}) async {
  if (!_ready) return;
  if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) return;
  try {
    await _plugin.show(
      threadId.hashCode,
      from,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Messages',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFFEE3E2B),
          // The route is part of the message here, not a detail.
          subText: hops != null ? 'Relayed · ${hops + 1} hops' : 'Direct',
        ),
      ),
      payload: threadId,
    );
  } catch (_) {
    // A failed notification must never take the message down with it.
  }
}
