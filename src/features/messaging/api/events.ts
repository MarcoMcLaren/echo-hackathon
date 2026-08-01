// Calendar events as messages.
//
// An event sent over the mesh is just structured text — small, so it never
// needs chunking. Saving it to the phone's own calendar is a separate,
// deliberate act, because writing to someone's calendar is not something a
// received message should do on its own.
// SDK 57 moved the flat calendar functions behind /legacy and deprecated the
// bare import. Using the explicit path keeps the same API without the warning.
import * as Calendar from 'expo-calendar/legacy';

export type MeshEvent = {
  title: string;
  /** Epoch ms. Sent as a number so both builds agree without parsing dates. */
  startsAt: number;
  /** Defaults to an hour after the start when absent. */
  endsAt?: number;
  location?: string;
};

const HOUR = 60 * 60 * 1000;

export const encodeEvent = (e: MeshEvent) => JSON.stringify(e);

/** Never throws — a malformed event from another build must not break a thread. */
export function decodeEvent(body: string): MeshEvent | null {
  try {
    const e = JSON.parse(body);
    if (typeof e?.title !== 'string' || typeof e?.startsAt !== 'number') return null;
    return e as MeshEvent;
  } catch {
    return null;
  }
}

export const formatWhen = (e: MeshEvent) => {
  const d = new Date(e.startsAt);
  return d.toLocaleString('en-ZA', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
};

/** The calendar Android will actually let us write to. */
async function writableCalendarId(): Promise<string | null> {
  const calendars = await Calendar.getCalendarsAsync(Calendar.EntityTypes.EVENT);
  const writable = calendars.find((c) => c.allowsModifications);
  return writable?.id ?? null;
}

export type SaveOutcome =
  | { ok: true }
  | { ok: false; reason: 'denied' | 'no-calendar' | 'error'; message?: string };

/** Save to the device calendar. Asks for permission at the moment of use. */
export async function saveToCalendar(e: MeshEvent): Promise<SaveOutcome> {
  try {
    const permission = await Calendar.requestCalendarPermissionsAsync();
    if (!permission.granted) return { ok: false, reason: 'denied' };

    const calendarId = await writableCalendarId();
    if (!calendarId) return { ok: false, reason: 'no-calendar' };

    await Calendar.createEventAsync(calendarId, {
      title: e.title,
      startDate: new Date(e.startsAt),
      endDate: new Date(e.endsAt ?? e.startsAt + HOUR),
      location: e.location,
      notes: 'Shared over Echo',
      // Android rejects an event without one. Intl gives the device's zone.
      timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    });
    return { ok: true };
  } catch (err) {
    return { ok: false, reason: 'error', message: err instanceof Error ? err.message : String(err) };
  }
}
