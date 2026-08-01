// The data model. No seed data — everything in the app now comes from real
// mesh activity, so an empty screen means "nothing has happened yet" rather
// than "the demo set is showing".

/** Relays a message passed through. 0 is direct; null means no route at all. */
export type Hops = 0 | 1 | 2 | null;

export type Msg = {
  id: string;
  /** Sender's device id, or 'me'. */
  from: string;
  /** Sender's display name, carried with the message — a relayed sender is not
   *  a peer here and cannot be looked up. */
  fromName?: string;
  text?: string;
  coin?: number;
  /** A photo, as a data URI. Travels in chunks; see utils/relay. */
  image?: string;
  /** A calendar event someone shared. Saving it is a separate, explicit act. */
  event?: MeshEvent;
  at: string;
  hops: Hops;
  via?: string;
  state?: 'delivered' | 'queued' | 'sent';
  /** Held locally during the cancel window — not on the air yet. */
  pending?: boolean;
  /** Sent, then taken back. The row stays visible; money that vanishes
   *  silently is worse than money you can see was returned. */
  reverted?: boolean;
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
  /** Arrived since you last opened the thread. Drives the summary offer. */
  unread?: number;
};

/** One line in the wallet. Derived from coin messages, never stored twice. */
export type Entry = {
  id: string;
  amount: number;
  who: string;
  hops: Hops;
  via?: string;
  note: string;
  reverted?: boolean;
};

import type { MeshEvent } from '../features/messaging/api/events';
