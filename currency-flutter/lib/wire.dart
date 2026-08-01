/// Echo currency wire format v0 — Flutter side.
/// Contract: ../../spec/wire.md   Conformance: test/vectors.json
///
/// Written independently from the same prose spec as the RN implementation.
/// If this and the RN build disagree, spec/ref.py decides.
library;

import 'dart:convert';
import 'dart:typed_data';

const int kVersion = 0;
const int kNoteLen = 42;

const int _offVer = 0;
const int _offFlags = 1;
const int _offNoteId = 2;
const int _offValue = 18;
const int _offHolder = 22;
const int _offLamport = 38;

const int kFlagBearer = 0x01;
const int _flagsReserved = 0xFE;

const int kRelayTtlStart = 3;

class Note {
  final int ver;
  final int flags;
  final String noteId; // 32 hex chars
  final int value; // minor units
  final String holder; // 32 hex chars, all-zero = bearer
  final int lamport;

  const Note({
    required this.ver,
    required this.flags,
    required this.noteId,
    required this.value,
    required this.holder,
    required this.lamport,
  });

  bool get isBearer => (flags & kFlagBearer) != 0;

  /// What relay and double-spend checks key on.
  String get dedupeKey => '$noteId:$lamport';

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.ver == ver &&
      other.flags == flags &&
      other.noteId == noteId &&
      other.value == value &&
      other.holder == holder &&
      other.lamport == lamport;

  @override
  int get hashCode => Object.hash(ver, flags, noteId, value, holder, lamport);
}

/// Codes must match the RN side and spec/wire.md verbatim.
class WireError implements Exception {
  final String code;
  const WireError(this.code);
  @override
  String toString() => 'WireError($code)';
}

// ------------------------------------------------------------------ hex

Uint8List _hexToBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String _bytesToHex(Uint8List b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

// ------------------------------------------------------------- base64url

/// 42 bytes -> 56 chars, unpadded. Padding is stripped to match the RN side.
String toB64url(Uint8List bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List fromB64url(String text) {
  try {
    return Uint8List.fromList(base64Url.decode(base64.normalize(text)));
  } catch (_) {
    throw const WireError('bad_length');
  }
}

// ------------------------------------------------------------ encode/decode

Uint8List encode(Note note) {
  final out = Uint8List(kNoteLen);
  final view = ByteData.sublistView(out);
  out[_offVer] = note.ver;
  out[_offFlags] = note.flags;
  out.setRange(_offNoteId, _offNoteId + 16, _hexToBytes(note.noteId));
  view.setUint32(_offValue, note.value, Endian.big);
  out.setRange(_offHolder, _offHolder + 16, _hexToBytes(note.holder));
  view.setUint32(_offLamport, note.lamport, Endian.big);
  return out;
}

Note decode(Uint8List raw) {
  if (raw.length != kNoteLen) throw const WireError('bad_length');
  final ver = raw[_offVer];
  if (ver != kVersion) throw const WireError('unsupported_version');
  final flags = raw[_offFlags];
  if (flags & _flagsReserved != 0) throw const WireError('bad_flags');
  final view = ByteData.sublistView(raw);
  return Note(
    ver: ver,
    flags: flags,
    noteId: _bytesToHex(raw.sublist(_offNoteId, _offNoteId + 16)),
    value: view.getUint32(_offValue, Endian.big),
    holder: _bytesToHex(raw.sublist(_offHolder, _offHolder + 16)),
    lamport: view.getUint32(_offLamport, Endian.big),
  );
}

// ------------------------------------------------------------ relay envelope

String wrapRelay(String b64, [int ttl = kRelayTtlStart]) => 'R|$ttl|$b64';

/// Returns null when this is a direct transfer rather than a relay envelope.
({int ttl, String b64})? parseRelay(String text) {
  if (!text.startsWith('R|')) return null;
  final first = text.indexOf('|');
  final second = text.indexOf('|', first + 1);
  if (second < 0) return null;
  return (
    ttl: int.parse(text.substring(first + 1, second)),
    b64: text.substring(second + 1),
  );
}
