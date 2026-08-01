// Live app state — ported from src/store/mesh.ts, minus the transport.
// There is no Flutter equivalent of expo-nearby-connections, so this store
// only ever operates the way RN's own store behaves on a solo device with no
// peers: sends land locally as 'queued', nothing gets relayed. start()/stop()
// simulate the off -> starting -> live status transition RN shows, since
// there's nothing real to start without a transport.
import 'package:flutter/foundation.dart';
import '../models/mock.dart' as mock;
import '../utils/relay.dart';

enum MeshStatus { off, starting, live }

class Stats {
  final int sent;
  final int delivered;
  final int relayed;
  final int dropped;
  const Stats({this.sent = 0, this.delivered = 0, this.relayed = 0, this.dropped = 0});

  Stats copyWith({int? sent, int? delivered, int? relayed, int? dropped}) => Stats(
        sent: sent ?? this.sent,
        delivered: delivered ?? this.delivered,
        relayed: relayed ?? this.relayed,
        dropped: dropped ?? this.dropped,
      );
}

class AppStore extends ChangeNotifier {
  final String deviceId = 'me';
  MeshStatus status = MeshStatus.off;
  Stats stats = const Stats();
  final SeenCache _seen = SeenCache();
  int _counter = 0;

  final List<mock.Thread> threads = mock.seedThreads();

  mock.Thread? threadById(String id) {
    for (final t in threads) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> start() async {
    if (status == MeshStatus.live || status == MeshStatus.starting) return;
    status = MeshStatus.starting;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 700));
    status = MeshStatus.live;
    notifyListeners();
  }

  void stop() {
    status = MeshStatus.off;
    notifyListeners();
  }

  /// Ports store/mesh.ts's send(): append to the thread immediately, and
  /// since there's no transport, it always lands as 'queued' — no peer is
  /// ever actually connected on a solo Flutter device.
  void send(String threadId, String body, {String kind = 'msg'}) {
    final envelope = newEnvelope(
      id: '$deviceId-${_counter++}',
      from: deviceId,
      to: threadId,
      kind: kind,
      body: body,
      at: 0,
    );
    _seen.check(envelope.id); // never relay our own message back to ourselves

    final thread = threadById(threadId);
    final msg = mock.Msg(
      id: envelope.id,
      from: 'me',
      text: kind == 'msg' ? body : null,
      coin: kind == 'coin' ? double.tryParse(body) : null,
      at: _clock(),
      hops: null,
      state: 'queued',
    );

    if (thread != null) {
      thread.messages.add(msg);
      thread.preview = msg.text ?? '${msg.coin?.toStringAsFixed(2)} echocoin';
      thread.at = msg.at;
    }

    stats = stats.copyWith(sent: stats.sent + 1);
    notifyListeners();
  }

  String _clock() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}';
  }
}
