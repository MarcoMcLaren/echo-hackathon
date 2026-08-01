// Test-only fixture data. Production code carries no seed data any more (see
// lib/store/mesh_store.dart) — this is the old three-phone demo cast (Thabo,
// Naledi, Lerato, Sipho, plus the Braai Crew group), kept here purely so
// tests have realistic paired conversations to assert against without each
// one hand-building a thread.
import 'package:echo/features/messaging/events.dart' show MeshEvent;
import 'package:echo/features/messaging/notifier.dart';
import 'package:echo/features/messaging/types.dart' show MeshTransport;
import 'package:echo/features/vault/contacts.dart';
import 'package:echo/store/mesh_store.dart';
import 'package:echo/store/types.dart';

final Map<String, Contact> demoContacts = {
  'lerato': const Contact(id: 'lerato', name: 'Lerato Ndlovu', addedAt: 0),
  'thabo': const Contact(id: 'thabo', name: 'Thabo Mokoena', addedAt: 0),
  'naledi': const Contact(id: 'naledi', name: 'Naledi Khumalo', addedAt: 0),
  'sipho': const Contact(id: 'sipho', name: 'Sipho Dlamini', addedAt: 0),
};

final List<Thread> demoThreads = [
  const Thread(
    id: 'braai',
    title: 'Braai Crew',
    initials: 'BC',
    group: true,
    members: ['lerato', 'thabo', 'naledi', 'sipho'],
    preview: 'Naledi: someone bring tongs',
    at: '2m',
    hops: 0,
    // Enough real backlog that the on-device summary has something to work
    // with — a summary of four messages proves nothing.
    unread: 11,
    messages: [
      Msg(
        id: 'g1',
        from: 'lerato',
        text: 'Moving it to Saturday 14:00, my place',
        at: '09:12',
        hops: 0,
      ),
      Msg(
        id: 'g2',
        from: 'thabo',
        text: 'I’ve got the wood. Nobody has claimed meat.',
        at: '09:20',
        hops: 0,
      ),
      Msg(
        id: 'g3',
        from: 'me',
        text: 'Meat is on me. Sending Lerato my share now.',
        at: '09:35',
        hops: 0,
        state: MsgState.sent,
      ),
      Msg(
        id: 'g4',
        from: 'lerato',
        text: 'Gate code is 4417, the buzzer is broken',
        at: '09:38',
        hops: 0,
      ),
      Msg(
        id: 'g5',
        from: 'naledi',
        text: 'Are you actually coming this time?',
        at: '09:41',
        hops: 1,
        via: 'Thabo',
      ),
      Msg(
        id: 'g6',
        from: 'thabo',
        text: 'Can someone bring a second grid? Mine warped.',
        at: '09:44',
        hops: 0,
      ),
      Msg(id: 'g7', from: 'lerato', text: 'I have a spare grid', at: '09:45', hops: 0),
      Msg(
        id: 'g8',
        from: 'naledi',
        text: 'Nobody has said anything about drinks',
        at: '09:47',
        hops: 1,
        via: 'Thabo',
      ),
      Msg(
        id: 'g9',
        from: 'thabo',
        text: 'Parking is tight, rather share a lift',
        at: '09:50',
        hops: 0,
      ),
      Msg(
        id: 'g10',
        from: 'lerato',
        text: 'Starting the fire at 13:30 so we eat at 14:00 sharp',
        at: '09:52',
        hops: 0,
      ),
      Msg(
        id: 'g11',
        from: 'naledi',
        text: 'Someone bring tongs, Lerato only has one pair',
        at: '09:55',
        hops: 1,
        via: 'Thabo',
      ),
    ],
  ),
  const Thread(
    id: 'thabo',
    title: 'Thabo Mokoena',
    initials: 'TM',
    preview: 'Sent you 12.50',
    at: '8m',
    hops: 0,
    messages: [
      Msg(id: 't1', from: 'thabo', text: 'Here, for the wood run', at: '09:11', hops: 0),
      Msg(id: 't2', from: 'thabo', coin: 12.5, at: '09:12', hops: 0),
      Msg(id: 't3', from: 'me', text: 'Dankie man', at: '09:13', hops: 0, state: MsgState.delivered),
    ],
  ),
  const Thread(
    id: 'naledi',
    title: 'Naledi Khumalo',
    initials: 'NK',
    preview: 'Did that come through?',
    at: '14m',
    hops: 1,
    via: 'Thabo',
    messages: [
      Msg(
        id: 'n1',
        from: 'naledi',
        text: 'Are you still at the north gate?',
        at: '09:38',
        hops: 1,
        via: 'Thabo',
      ),
      Msg(
        id: 'n2',
        from: 'me',
        text: 'Ja, by the coffee stand. Can’t see you.',
        at: '09:39',
        hops: 1,
        via: 'Thabo',
        state: MsgState.delivered,
      ),
      Msg(
        id: 'n3',
        from: 'naledi',
        text: 'Send me 20 for a ticket and I’ll come to you',
        at: '09:40',
        hops: 1,
        via: 'Thabo',
      ),
      Msg(id: 'n4', from: 'me', coin: 20, at: '09:41', hops: 1, via: 'Thabo', state: MsgState.delivered),
    ],
  ),
  const Thread(
    id: 'sipho',
    title: 'Sipho Dlamini',
    initials: 'SD',
    preview: '1 message waiting to send',
    at: 'Tue',
    hops: null,
    messages: [
      Msg(id: 's1', from: 'sipho', text: 'Heading into the valley, no signal there', at: 'Tue 16:02', hops: 0),
      Msg(
        id: 's2',
        from: 'me',
        text: 'Shout when you’re back in range',
        at: 'Tue 16:20',
        hops: null,
        state: MsgState.queued,
      ),
    ],
  ),
];

/// A fresh, unused calendar event for tests that need one.
const demoEvent = MeshEvent(title: 'Braai', startsAt: 1735660800000, location: "Lerato's place");

/// A [MeshStore] preloaded with [demoContacts] and [demoThreads] — the
/// pairing-model equivalent of the old mock-seeded store, for tests that care
/// about message/thread mechanics rather than the empty-by-default start
/// state.
MeshStore demoStore({
  MeshTransport? transport,
  MeshNotifier? notifier,
  String deviceId = 'me',
  String? display,
}) {
  final store = MeshStore(transport: transport, notifier: notifier, deviceId: deviceId, display: display);
  store.contacts = Map.of(demoContacts);
  store.threads = List.of(demoThreads);
  return store;
}
