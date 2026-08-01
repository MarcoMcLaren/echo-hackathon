// Demo data. Mirrors the three-phone demo: you, Thabo (relay), Naledi (1 hop),
// Lerato (direct), Sipho (no route).
//
// Port of src/store/mock.ts.

/// Hop count to reach someone: 0 (direct), 1 or 2 hops, or no route at all.
typedef Hops = int?;

class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.initials,
    required this.hops,
    this.via,
    this.rssi,
  });

  final String id;
  final String name;
  final String initials;
  final Hops hops;
  final String? via;
  final int? rssi;
}

class Me {
  const Me({required this.id, required this.name, required this.initials});

  final String id;
  final String name;
  final String initials;
}

const me = Me(id: 'me', name: 'You', initials: 'RF');

const List<Contact> contacts = [
  Contact(
    id: 'lerato',
    name: 'Lerato Ndlovu',
    initials: 'LN',
    hops: 0,
    rssi: -48,
  ),
  Contact(
    id: 'thabo',
    name: 'Thabo Mokoena',
    initials: 'TM',
    hops: 0,
    rssi: -52,
  ),
  Contact(
    id: 'naledi',
    name: 'Naledi Khumalo',
    initials: 'NK',
    hops: 1,
    via: 'Thabo',
    rssi: -71,
  ),
  Contact(id: 'sipho', name: 'Sipho Dlamini', initials: 'SD', hops: null),
];

Contact? byId(String id) {
  for (final c in contacts) {
    if (c.id == id) return c;
  }
  return null;
}

enum MsgState { delivered, queued, sent }

class Msg {
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

  final String id;

  /// 'me' or a contact id.
  final String from;
  final String? text;
  final double? coin;
  final String at;
  final Hops hops;
  final String? via;
  final MsgState? state;

  /// Held locally during the cancel window — not on the air yet.
  final bool pending;

  /// Sent, then taken back. The row stays visible; money that vanishes
  /// silently is worse than money you can see was returned.
  final bool reverted;

  Msg withReverted(bool reverted) => Msg(
    id: id,
    from: from,
    text: text,
    coin: coin,
    at: at,
    hops: hops,
    via: via,
    state: state,
    pending: pending,
    reverted: reverted,
  );
}

class Thread {
  const Thread({
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

  final String id;
  final String title;
  final String initials;
  final bool group;
  final List<String>? members;
  final String preview;
  final String at;
  final Hops hops;
  final String? via;
  final List<Msg> messages;

  /// Arrived since you last opened the thread. Drives the summary offer.
  final int unread;
}

const List<Thread> threads = [
  Thread(
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
      Msg(
        id: 'g7',
        from: 'lerato',
        text: 'I have a spare grid',
        at: '09:45',
        hops: 0,
      ),
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
  Thread(
    id: 'thabo',
    title: 'Thabo Mokoena',
    initials: 'TM',
    preview: 'Sent you 12.50',
    at: '8m',
    hops: 0,
    messages: [
      Msg(
        id: 't1',
        from: 'thabo',
        text: 'Here, for the wood run',
        at: '09:11',
        hops: 0,
      ),
      Msg(id: 't2', from: 'thabo', coin: 12.5, at: '09:12', hops: 0),
      Msg(
        id: 't3',
        from: 'me',
        text: 'Dankie man',
        at: '09:13',
        hops: 0,
        state: MsgState.delivered,
      ),
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
      Msg(
        id: 'n4',
        from: 'me',
        coin: 20,
        at: '09:41',
        hops: 1,
        via: 'Thabo',
        state: MsgState.delivered,
      ),
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
      Msg(
        id: 's1',
        from: 'sipho',
        text: 'Heading into the valley, no signal there',
        at: 'Tue 16:02',
        hops: 0,
      ),
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

class Entry {
  const Entry({
    required this.id,
    required this.amount,
    required this.who,
    required this.hops,
    this.via,
    required this.note,
  });

  final String id;
  final double amount;
  final String who;
  final Hops hops;
  final String? via;
  final String note;
}

const double balance = 148.25;

const List<Entry> ledger = [
  Entry(
    id: 'l1',
    amount: -20,
    who: 'Naledi Khumalo',
    hops: 1,
    via: 'Thabo',
    note: '09:41',
  ),
  Entry(
    id: 'l2',
    amount: 12.5,
    who: 'Thabo Mokoena',
    hops: 0,
    note: 'PHONE TAP · 09:12',
  ),
  Entry(
    id: 'l3',
    amount: -45,
    who: 'Braai Crew pot',
    hops: 0,
    note: 'SPLIT 4 WAYS · YESTERDAY',
  ),
  Entry(
    id: 'l4',
    amount: 200,
    who: 'Opening balance',
    hops: 0,
    note: 'ISSUED AT SETUP · TUE 08:02',
  ),
];

class SummaryPoint {
  const SummaryPoint({required this.k, required this.text});

  final String k;
  final String text;
}

class Summary {
  const Summary({
    required this.model,
    required this.count,
    required this.took,
    required this.points,
  });

  final String model;
  final int count;
  final String took;
  final List<SummaryPoint> points;
}

const Summary summary = Summary(
  model: 'Gemma 3 · on this phone',
  count: 41,
  took: '1.4 s',
  points: [
    SummaryPoint(
      k: 'WHEN',
      text: 'Braai moved to Saturday 14:00 at Lerato’s place.',
    ),
    SummaryPoint(
      k: 'BRING',
      text: 'Thabo has wood. You claimed meat. Nobody has claimed drinks.',
    ),
    SummaryPoint(
      k: 'OPEN',
      text: 'Naledi asked twice if you’re coming. Still unanswered.',
    ),
  ],
);
