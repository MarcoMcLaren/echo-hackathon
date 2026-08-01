import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/messaging/events.dart';

import '../support/fakes.dart';

void main() {
  group('encodeEvent / decodeEvent', () {
    test('round-trips a full event', () {
      const e = MeshEvent(
        title: 'Braai',
        startsAt: 1000,
        endsAt: 5000,
        location: "Lerato's place",
      );
      final decoded = decodeEvent(encodeEvent(e));
      expect(decoded, isNotNull);
      expect(decoded!.title, e.title);
      expect(decoded.startsAt, e.startsAt);
      expect(decoded.endsAt, e.endsAt);
      expect(decoded.location, e.location);
    });

    test('round-trips with endsAt/location left absent', () {
      const e = MeshEvent(title: 'Braai', startsAt: 1000);
      final decoded = decodeEvent(encodeEvent(e));
      expect(decoded!.endsAt, isNull);
      expect(decoded.location, isNull);
    });

    test('never throws — malformed JSON decodes to null', () {
      expect(decodeEvent('not json'), isNull);
    });

    test('returns null when required fields are missing', () {
      expect(decodeEvent('{"title":"Braai"}'), isNull);
    });

    test('returns null when a field has the wrong type', () {
      expect(decodeEvent('{"title":1,"startsAt":1000}'), isNull);
    });
  });

  group('formatWhen', () {
    test('formats weekday, day, month and 24h time', () {
      // 2024-03-02 (a Saturday) 14:00 local.
      final at = DateTime(2024, 3, 2, 14).millisecondsSinceEpoch;
      final formatted = formatWhen(MeshEvent(title: 'Braai', startsAt: at));
      expect(formatted, 'Sat, 2 Mar, 14:00');
    });
  });

  group('MockCalendarWriter', () {
    test('records what would have been saved on success', () async {
      final writer = MockCalendarWriter();
      const e = MeshEvent(title: 'Braai', startsAt: 1000);

      final outcome = await writer.save(e);

      expect(outcome.ok, isTrue);
      expect(writer.saved, [e]);
    });

    test('a scripted failure is returned and nothing is recorded', () async {
      final writer = MockCalendarWriter(
        nextOutcome: const SaveOutcome.failure(SaveFailureReason.denied),
      );

      final outcome = await writer.save(
        const MeshEvent(title: 'Braai', startsAt: 1000),
      );

      expect(outcome.ok, isFalse);
      expect(outcome.reason, SaveFailureReason.denied);
      expect(writer.saved, isEmpty);
    });
  });
}
