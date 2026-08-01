// Local notifications for arriving messages.
//
// "Push" here is a misnomer worth being precise about: there is no server and
// no FCM, because there is no internet. A message arrives over the mesh and
// this posts a notification from the phone itself.
//
// Port intent of src/features/messaging/api/notify.ts. The real implementation
// is a platform-notification plugin (flutter_local_notifications or
// equivalent) that lands separately; this defines the contract MeshStore
// drives and a fake that records calls so tests can assert on them without a
// plugin channel.
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
