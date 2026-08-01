// Demo data — ported from src/store/mock.ts. Mirrors the three-phone demo:
// you, Thabo (relay), Naledi (1 hop), Lerato (direct), Sipho (no route).
//
// Hops: 0, 1, 2, or null — null means no route.

class Contact {
  final String id;
  final String name;
  final String initials;
  final int? hops;
  final String? via;
  final int? rssi;

  const Contact({
    required this.id,
    required this.name,
    required this.initials,
    required this.hops,
    this.via,
    this.rssi,
  });
}

const me = {'id': 'me', 'name': 'You', 'initials': 'RF'};

const contacts = <Contact>[
  Contact(id: 'lerato', name: 'Lerato Ndlovu', initials: 'LN', hops: 0, rssi: -48),
  Contact(id: 'thabo', name: 'Thabo Mokoena', initials: 'TM', hops: 0, rssi: -52),
  Contact(id: 'naledi', name: 'Naledi Khumalo', initials: 'NK', hops: 1, via: 'Thabo', rssi: -71),
  Contact(id: 'sipho', name: 'Sipho Dlamini', initials: 'SD', hops: null),
];

Contact? byId(String id) {
  for (final c in contacts) {
    if (c.id == id) return c;
  }
  return null;
}

class Msg {
  final String id;
  final String from; // 'me' or contact id
  final String? text;
  final double? coin;
  final String at;
  final int? hops;
  final String? via;
  final String? state; // 'delivered' | 'queued' | 'sent'
  /// Held locally during the cancel window — not on the air yet.
  final bool pending;
  /// Sent, then taken back. The row stays visible; money that vanishes
  /// silently is worse than money you can see was returned.
  final bool reverted;

  const Msg({
    required this.id,
    required this.from,
    this.text,
    this.coin,
    required this.at,
    required this.hops,
    this.via,
    this.state,
    this.pending = false,
    this.reverted = false,
  });

  Msg copyWith({bool? pending, bool? reverted}) => Msg(
        id: id,
        from: from,
        text: text,
        coin: coin,
        at: at,
        hops: hops,
        via: via,
        state: state,
        pending: pending ?? this.pending,
        reverted: reverted ?? this.reverted,
      );
}

class Thread {
  final String id;
  final String title;
  final String initials;
  final bool group;
  final List<String>? members;
  String preview;
  String at;
  int? hops;
  String? via;
  final List<Msg> messages;
  /// Arrived since you last opened the thread. Drives the summary offer.
  int unread;

  Thread({
    required this.id,
    required this.title,
    required this.initials,
    this.group = false,
    this.members,
    required this.preview,
    required this.at,
    required this.hops,
    this.via,
    required this.messages,
    this.unread = 0,
  });
}

/// Fresh seed data each call — screens mutate their own `Thread.messages`, so
/// this must never hand out the same mutable list twice.
List<Thread> seedThreads() => [
      Thread(
        id: 'braai',
        title: 'Braai Crew',
        initials: 'BC',
        group: true,
        members: const ['lerato', 'thabo', 'naledi', 'sipho'],
        preview: 'Naledi: someone bring tongs',
        at: '2m',
        hops: 0,
        // Enough real backlog that the on-device summary has something to
        // work with — a summary of four messages proves nothing.
        unread: 11,
        messages: [
          const Msg(id: 'g1', from: 'lerato', text: 'Moving it to Saturday 14:00, my place', at: '09:12', hops: 0),
          const Msg(id: 'g2', from: 'thabo', text: 'I’ve got the wood. Nobody has claimed meat.', at: '09:20', hops: 0),
          const Msg(id: 'g3', from: 'me', text: 'Meat is on me. Sending Lerato my share now.', at: '09:35', hops: 0, state: 'sent'),
          const Msg(id: 'g4', from: 'lerato', text: 'Gate code is 4417, the buzzer is broken', at: '09:38', hops: 0),
          const Msg(id: 'g5', from: 'naledi', text: 'Are you actually coming this time?', at: '09:41', hops: 1, via: 'Thabo'),
          const Msg(id: 'g6', from: 'thabo', text: 'Can someone bring a second grid? Mine warped.', at: '09:44', hops: 0),
          const Msg(id: 'g7', from: 'lerato', text: 'I have a spare grid', at: '09:45', hops: 0),
          const Msg(id: 'g8', from: 'naledi', text: 'Nobody has said anything about drinks', at: '09:47', hops: 1, via: 'Thabo'),
          const Msg(id: 'g9', from: 'thabo', text: 'Parking is tight, rather share a lift', at: '09:50', hops: 0),
          const Msg(id: 'g10', from: 'lerato', text: 'Starting the fire at 13:30 so we eat at 14:00 sharp', at: '09:52', hops: 0),
          const Msg(id: 'g11', from: 'naledi', text: 'Someone bring tongs, Lerato only has one pair', at: '09:55', hops: 1, via: 'Thabo'),
        ],
      ),
      Thread(
        id: 'thabo',
        title: 'Thabo Mokoena',
        initials: 'TM',
        preview: 'Sent you 12.50',
        at: '8m',
        hops: 0,
        messages: [
          const Msg(id: 't1', from: 'thabo', text: 'Here, for the wood run', at: '09:11', hops: 0),
          const Msg(id: 't2', from: 'thabo', coin: 12.5, at: '09:12', hops: 0),
          const Msg(id: 't3', from: 'me', text: 'Dankie man', at: '09:13', hops: 0, state: 'delivered'),
        ],
      ),
      Thread(
        id: 'naledi',
        title: 'Naledi Khumalo',
        initials: 'NK',
        preview: 'Did that come through?',
        at: '14m',
        hops: 1,
        via: 'Thabo',
        messages: [
          const Msg(id: 'n1', from: 'naledi', text: 'Are you still at the north gate?', at: '09:38', hops: 1, via: 'Thabo'),
          const Msg(id: 'n2', from: 'me', text: 'Ja, by the coffee stand. Can’t see you.', at: '09:39', hops: 1, via: 'Thabo', state: 'delivered'),
          const Msg(id: 'n3', from: 'naledi', text: 'Send me 20 for a ticket and I’ll come to you', at: '09:40', hops: 1, via: 'Thabo'),
          const Msg(id: 'n4', from: 'me', coin: 20, at: '09:41', hops: 1, via: 'Thabo', state: 'delivered'),
        ],
      ),
      Thread(
        id: 'sipho',
        title: 'Sipho Dlamini',
        initials: 'SD',
        preview: '1 message waiting to send',
        at: 'Tue',
        hops: null,
        messages: [
          const Msg(id: 's1', from: 'sipho', text: 'Heading into the valley, no signal there', at: 'Tue 16:02', hops: 0),
          const Msg(id: 's2', from: 'me', text: 'Shout when you’re back in range', at: 'Tue 16:20', hops: null, state: 'queued'),
        ],
      ),
    ];

/// Static demo threads, separate from whatever AppStore mutates at runtime —
/// mirrors RN's SendCoinScreen, which imports `threads` straight from
/// store/mock.ts rather than the live mesh store, for its contact-name
/// fallback lookup only.
final List<Thread> threads = seedThreads();

Thread? threadById(String id) {
  for (final t in threads) {
    if (t.id == id) return t;
  }
  return null;
}

class Entry {
  final String id;
  final double amount;
  final String who;
  final int? hops;
  final String? via;
  final String note;

  const Entry({required this.id, required this.amount, required this.who, required this.hops, this.via, required this.note});
}

const balance = 148.25;

const ledger = <Entry>[
  Entry(id: 'l1', amount: -20, who: 'Naledi Khumalo', hops: 1, via: 'Thabo', note: '09:41'),
  Entry(id: 'l2', amount: 12.5, who: 'Thabo Mokoena', hops: 0, note: 'PHONE TAP · 09:12'),
  Entry(id: 'l3', amount: -45, who: 'Braai Crew pot', hops: 0, note: 'SPLIT 4 WAYS · YESTERDAY'),
  Entry(id: 'l4', amount: 200, who: 'Opening balance', hops: 0, note: 'ISSUED AT SETUP · TUE 08:02'),
];
