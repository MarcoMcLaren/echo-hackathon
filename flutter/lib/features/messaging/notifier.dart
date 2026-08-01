// Local notifications for arriving messages.
//
// "Push" here is a misnomer worth being precise about: there is no server and
// no FCM, because there is no internet. A message arrives over the mesh and
// this posts a notification from the phone itself.
//
// Port intent of src/features/messaging/api/notify.ts. This defines the
// contract MeshStore drives, a fake that records calls so tests can assert
// on them without a plugin channel, an in-app [BannerMeshNotifier] that
// surfaces the same event as a SnackBar, and the real
// [LocalNotificationsMeshNotifier] that posts an actual Android notification
// when the banner can't be seen.
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotifyPayload {
  const NotifyPayload({
    required this.from,
    required this.body,
    required this.threadId,
    required this.hops,
  });

  final String from;
  final String body;
  final String threadId;
  final int? hops;
}

abstract class MeshNotifier {
  /// Requests whatever permission the platform needs. Called once the mesh
  /// turns on — asking earlier makes no sense to someone who hasn't opted in.
  Future<void> prepare();

  /// Post one notification for a message that just landed. A real
  /// implementation stays silent while the app is in the foreground.
  Future<void> notify(NotifyPayload payload);
}

/// Headless fake: records every call instead of touching a platform channel,
/// so MeshStore's notification triggers can be asserted on in tests.
class MockMeshNotifier implements MeshNotifier {
  bool prepared = false;
  final List<NotifyPayload> sent = [];

  @override
  Future<void> prepare() async {
    prepared = true;
  }

  @override
  Future<void> notify(NotifyPayload payload) async {
    sent.add(payload);
  }
}

/// Surfaces an arriving message as an in-app SnackBar via the app's
/// [ScaffoldMessengerState]. This is the whole "local notification" while the
/// app is open — a platform notification plugin would take over for the
/// backgrounded case, which is native work this build doesn't have.
class BannerMeshNotifier implements MeshNotifier {
  BannerMeshNotifier(this._messengerKey);

  final GlobalKey<ScaffoldMessengerState> _messengerKey;

  @override
  Future<void> prepare() async {}

  @override
  Future<void> notify(NotifyPayload payload) async {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${payload.from}: ${payload.body}'),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}

/// Posts a real Android notification for a message that arrives while the
/// app isn't in the foreground. When it is, delegates to [BannerMeshNotifier]
/// instead — a resumed session shouldn't get a system-tray notification for
/// something already visible on screen.
///
/// The only import site for package:flutter_local_notifications.
class LocalNotificationsMeshNotifier implements MeshNotifier {
  LocalNotificationsMeshNotifier(GlobalKey<ScaffoldMessengerState> messengerKey)
    : _banner = BannerMeshNotifier(messengerKey);

  static const _channelId = 'mesh_messages';
  static const _channelName = 'Mesh messages';

  final BannerMeshNotifier _banner;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _prepared = false;
  int _nextId = 0;

  @override
  Future<void> prepare() async {
    if (_prepared) return;
    _prepared = true;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> notify(NotifyPayload payload) async {
    final foregrounded = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (foregrounded) {
      await _banner.notify(payload);
      return;
    }

    await prepare();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Messages arriving over the offline mesh',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      id: _nextId++,
      title: payload.from,
      body: payload.body,
      notificationDetails: details,
    );
  }
}
