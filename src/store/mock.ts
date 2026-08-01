// Demo data. Mirrors the three-phone demo: you, Thabo (relay), Naledi (1 hop),
// Lerato (direct), Sipho (no route).
export type Hops = 0 | 1 | 2 | null; // null = no route
export type Contact = {
  id: string;
  name: string;
  initials: string;
  hops: Hops;
  via?: string;
  rssi?: number;
};

export const me = { id: 'me', name: 'You', initials: 'RF' };

export const contacts: Contact[] = [
  { id: 'lerato', name: 'Lerato Ndlovu', initials: 'LN', hops: 0, rssi: -48 },
  { id: 'thabo', name: 'Thabo Mokoena', initials: 'TM', hops: 0, rssi: -52 },
  { id: 'naledi', name: 'Naledi Khumalo', initials: 'NK', hops: 1, via: 'Thabo', rssi: -71 },
  { id: 'sipho', name: 'Sipho Dlamini', initials: 'SD', hops: null },
];

export const byId = (id: string) => contacts.find((c) => c.id === id);

export type Msg = {
  id: string;
  from: string; // 'me' or contact id
  text?: string;
  coin?: number;
  at: string;
  hops: Hops;
  via?: string;
  state?: 'delivered' | 'queued' | 'sent';
};

export type Thread = {
  id: string;
  title: string;
  initials: string;
  group?: boolean;
  members?: string[];
  preview: string;
  at: string;
  hops: Hops;
  via?: string;
  messages: Msg[];
};

export const threads: Thread[] = [
  {
    id: 'braai',
    title: 'Braai Crew',
    initials: 'BC',
    group: true,
    members: ['lerato', 'thabo', 'naledi', 'sipho'],
    preview: 'Naledi: someone bring tongs',
    at: '2m',
    hops: 0,
    messages: [
      { id: 'g1', from: 'lerato', text: 'Moving it to Saturday 14:00, my place', at: '09:12', hops: 0 },
      { id: 'g2', from: 'thabo', text: 'I’ve got the wood. Nobody has claimed meat.', at: '09:20', hops: 0 },
      { id: 'g3', from: 'me', text: 'Meat is on me. Sending Lerato my share now.', at: '09:35', hops: 0, state: 'sent' },
      { id: 'g4', from: 'naledi', text: 'Are you actually coming this time?', at: '09:41', hops: 1, via: 'Thabo' },
    ],
  },
  {
    id: 'thabo',
    title: 'Thabo Mokoena',
    initials: 'TM',
    preview: 'Sent you 12.50',
    at: '8m',
    hops: 0,
    messages: [
      { id: 't1', from: 'thabo', text: 'Here, for the wood run', at: '09:11', hops: 0 },
      { id: 't2', from: 'thabo', coin: 12.5, at: '09:12', hops: 0 },
      { id: 't3', from: 'me', text: 'Dankie man', at: '09:13', hops: 0, state: 'delivered' },
    ],
  },
  {
    id: 'naledi',
    title: 'Naledi Khumalo',
    initials: 'NK',
    preview: 'Did that come through?',
    at: '14m',
    hops: 1,
    via: 'Thabo',
    messages: [
      { id: 'n1', from: 'naledi', text: 'Are you still at the north gate?', at: '09:38', hops: 1, via: 'Thabo' },
      { id: 'n2', from: 'me', text: 'Ja, by the coffee stand. Can’t see you.', at: '09:39', hops: 1, via: 'Thabo', state: 'delivered' },
      { id: 'n3', from: 'naledi', text: 'Send me 20 for a ticket and I’ll come to you', at: '09:40', hops: 1, via: 'Thabo' },
      { id: 'n4', from: 'me', coin: 20, at: '09:41', hops: 1, via: 'Thabo', state: 'delivered' },
    ],
  },
  {
    id: 'sipho',
    title: 'Sipho Dlamini',
    initials: 'SD',
    preview: '1 message waiting to send',
    at: 'Tue',
    hops: null,
    messages: [
      { id: 's1', from: 'sipho', text: 'Heading into the valley, no signal there', at: 'Tue 16:02', hops: 0 },
      { id: 's2', from: 'me', text: 'Shout when you’re back in range', at: 'Tue 16:20', hops: null, state: 'queued' },
    ],
  },
];

export type Entry = {
  id: string;
  amount: number;
  who: string;
  hops: Hops;
  via?: string;
  note: string;
};

export const balance = 148.25;

export const ledger: Entry[] = [
  { id: 'l1', amount: -20, who: 'Naledi Khumalo', hops: 1, via: 'Thabo', note: '09:41' },
  { id: 'l2', amount: 12.5, who: 'Thabo Mokoena', hops: 0, note: 'PHONE TAP · 09:12' },
  { id: 'l3', amount: -45, who: 'Braai Crew pot', hops: 0, note: 'SPLIT 4 WAYS · YESTERDAY' },
  { id: 'l4', amount: 200, who: 'Opening balance', hops: 0, note: 'ISSUED AT SETUP · TUE 08:02' },
];

export const summary = {
  model: 'Gemma 3 · on this phone',
  count: 41,
  took: '1.4 s',
  points: [
    { k: 'WHEN', text: 'Braai moved to Saturday 14:00 at Lerato’s place.' },
    { k: 'BRING', text: 'Thabo has wood. You claimed meat. Nobody has claimed drinks.' },
    { k: 'OPEN', text: 'Naledi asked twice if you’re coming. Still unanswered.' },
  ],
};
