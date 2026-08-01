/// Runs the frozen conformance vectors. Both projects must pass all 9.
/// Contract: ../../spec/wire.md
///
///   cd currency-flutter && dart test
///
/// test/vectors.json is a COPY of spec/vectors.json — copied, never linked,
/// so no build artefact of this project reaches outside it.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../lib/wire.dart';

Note _noteFrom(Map<String, dynamic> m) => Note(
      ver: m['ver'] as int,
      flags: m['flags'] as int,
      noteId: m['note_id'] as String,
      value: m['value'] as int,
      holder: m['holder'] as String,
      lamport: m['lamport'] as int,
    );

String _hex(Uint8List b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  final vectors = jsonDecode(
    File('test/vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final encodeCases = (vectors['encode'] as List).cast<Map<String, dynamic>>();
  final decodeCases = (vectors['decode'] as List).cast<Map<String, dynamic>>();

  test('encode vectors', () {
    for (final c in encodeCases) {
      final name = c['name'];
      final note = _noteFrom(c['note'] as Map<String, dynamic>);
      final raw = encode(note);

      expect(raw.length, kNoteLen, reason: '$name: length');
      expect(_hex(raw), c['expect_hex'], reason: '$name: hex');
      expect(toB64url(raw), c['expect_b64url'], reason: '$name: b64url');
      expect(decode(raw), note, reason: '$name: round-trip');
      expect(decode(fromB64url(c['expect_b64url'] as String)), note,
          reason: '$name: b64url round-trip');
    }
  });

  test('decode rejections', () {
    for (final c in decodeCases) {
      expect(
        () => decode(fromB64url(c['input_b64url'] as String)),
        throwsA(isA<WireError>()
            .having((e) => e.code, 'code', c['expect_error'])),
        reason: c['name'] as String,
      );
    }
  });

  test('base64url is 56 chars and unpadded', () {
    for (final c in encodeCases) {
      expect((c['expect_b64url'] as String).length, 56, reason: c['name']);
      expect((c['expect_b64url'] as String).contains('='), isFalse,
          reason: c['name']);
    }
  });

  test('bearer flag', () {
    final c = encodeCases.firstWhere((c) => c['name'] == 'bearer-holder-zero');
    final note = _noteFrom(c['note'] as Map<String, dynamic>);
    expect(note.isBearer, isTrue);
    expect(note.holder, '0' * 32);
  });

  test('dedupe key is noteId + lamport', () {
    final base = _noteFrom(encodeCases[0]['note'] as Map<String, dynamic>);
    final a = Note(
        ver: base.ver,
        flags: base.flags,
        noteId: base.noteId,
        value: base.value,
        holder: base.holder,
        lamport: 1);
    final b = Note(
        ver: base.ver,
        flags: base.flags,
        noteId: base.noteId,
        value: base.value,
        holder: base.holder,
        lamport: 2);
    expect(a.dedupeKey, isNot(b.dedupeKey));
  });

  test('relay envelope round-trips and decrements', () {
    final b64 = encodeCases[0]['expect_b64url'] as String;
    final env = wrapRelay(b64);
    expect(env, 'R|3|$b64');

    final parsed = parseRelay(env)!;
    expect(parsed.ttl, 3);
    expect(parsed.b64, b64);

    expect(parseRelay(b64), isNull,
        reason: 'direct transfer is not a relay envelope');

    final hop = wrapRelay(parsed.b64, parsed.ttl - 1);
    expect(parseRelay(hop)!.ttl, 2);
  });
}
