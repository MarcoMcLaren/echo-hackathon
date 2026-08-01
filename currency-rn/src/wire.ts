/**
 * Echo currency wire format v0 — React Native side.
 * Contract: ../../spec/wire.md   Conformance: ../../spec/vectors.json
 *
 * Dependency-free on purpose. React Native has no `Buffer` and no `atob`/`btoa`
 * in all runtimes, so base64url is implemented here rather than imported.
 */

export const VERSION = 0;
export const NOTE_LEN = 42;

const OFF_VER = 0;
const OFF_FLAGS = 1;
const OFF_NOTE_ID = 2;
const OFF_VALUE = 18;
const OFF_HOLDER = 22;
const OFF_LAMPORT = 38;

export const FLAG_BEARER = 0x01;
const FLAGS_RESERVED = 0xfe;

export const RELAY_TTL_START = 3;

export type Note = {
  ver: number;
  flags: number;
  note_id: string; // 32 hex chars
  value: number; // minor units
  holder: string; // 32 hex chars, all-zero = bearer
  lamport: number;
};

export type WireErrorCode =
  | 'unsupported_version'
  | 'bad_length'
  | 'bad_flags'
  | 'duplicate'
  | 'conflict'
  | 'not_holder';

export class WireError extends Error {
  // Plain field, not a TS parameter property — keeps this file runnable under
  // `node --experimental-strip-types` as well as RN's Babel transform.
  code: WireErrorCode;

  constructor(code: WireErrorCode) {
    super(code);
    this.name = 'WireError';
    this.code = code;
  }
}

// ------------------------------------------------------------------ hex

function hexToBytes(hex: string): Uint8Array {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.substr(i * 2, 2), 16);
  }
  return out;
}

function bytesToHex(b: Uint8Array): string {
  let s = '';
  for (let i = 0; i < b.length; i++) s += b[i].toString(16).padStart(2, '0');
  return s;
}

// ------------------------------------------------------------- base64url

const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

export function toB64url(bytes: Uint8Array): string {
  let out = '';
  for (let i = 0; i < bytes.length; i += 3) {
    const b0 = bytes[i];
    const b1 = bytes[i + 1];
    const b2 = bytes[i + 2];
    out += B64[b0 >> 2];
    out += B64[((b0 & 0x03) << 4) | ((b1 ?? 0) >> 4)];
    if (b1 === undefined) break;
    out += B64[((b1 & 0x0f) << 2) | ((b2 ?? 0) >> 6)];
    if (b2 === undefined) break;
    out += B64[b2 & 0x3f];
  }
  return out;
}

export function fromB64url(text: string): Uint8Array {
  const clean = text.replace(/=+$/, '');
  const n = clean.length;
  const bytes: number[] = [];
  let acc = 0;
  let bits = 0;
  for (let i = 0; i < n; i++) {
    const v = B64.indexOf(clean[i]);
    if (v < 0) throw new WireError('bad_length');
    acc = (acc << 6) | v;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      bytes.push((acc >> bits) & 0xff);
    }
  }
  return new Uint8Array(bytes);
}

// ------------------------------------------------------------ encode/decode

export function encode(note: Note): Uint8Array {
  const out = new Uint8Array(NOTE_LEN);
  out[OFF_VER] = note.ver;
  out[OFF_FLAGS] = note.flags;
  out.set(hexToBytes(note.note_id), OFF_NOTE_ID);
  new DataView(out.buffer).setUint32(OFF_VALUE, note.value, false); // big-endian
  out.set(hexToBytes(note.holder), OFF_HOLDER);
  new DataView(out.buffer).setUint32(OFF_LAMPORT, note.lamport, false);
  return out;
}

export function decode(raw: Uint8Array): Note {
  if (raw.length !== NOTE_LEN) throw new WireError('bad_length');
  const ver = raw[OFF_VER];
  if (ver !== VERSION) throw new WireError('unsupported_version');
  const flags = raw[OFF_FLAGS];
  if (flags & FLAGS_RESERVED) throw new WireError('bad_flags');
  const dv = new DataView(raw.buffer, raw.byteOffset, raw.byteLength);
  return {
    ver,
    flags,
    note_id: bytesToHex(raw.subarray(OFF_NOTE_ID, OFF_NOTE_ID + 16)),
    value: dv.getUint32(OFF_VALUE, false),
    holder: bytesToHex(raw.subarray(OFF_HOLDER, OFF_HOLDER + 16)),
    lamport: dv.getUint32(OFF_LAMPORT, false),
  };
}

// ------------------------------------------------------------------ helpers

export const isBearer = (n: Note) => (n.flags & FLAG_BEARER) !== 0;

export const dedupeKey = (n: Note) => `${n.note_id}:${n.lamport}`;

export function wrapRelay(b64: string, ttl: number = RELAY_TTL_START): string {
  return `R|${ttl}|${b64}`;
}

export function parseRelay(text: string): { ttl: number; b64: string } | null {
  if (!text.startsWith('R|')) return null;
  const first = text.indexOf('|');
  const second = text.indexOf('|', first + 1);
  if (second < 0) return null;
  return {
    ttl: parseInt(text.slice(first + 1, second), 10),
    b64: text.slice(second + 1),
  };
}
