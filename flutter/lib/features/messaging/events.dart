// Calendar events as messages.
//
// An event sent over the mesh is just structured text — small, so it never
// needs chunking. Saving it to the phone's own calendar is a separate,
// deliberate act, because writing to someone's calendar is not something a
// received message should do on its own.
//
// Port intent of src/features/messaging/api/events.ts. The real
// save-to-calendar implementation needs a calendar plugin (e.g.
// device_calendar) that isn't wired up yet; this defines the contract
// [CalendarWriter] it must satisfy and a fake that records what would have
// been saved, so the "add to calendar" flow can be built and tested without
// one.
import 'dart:convert';

class MeshEvent {
  const MeshEvent({
    required this.title,
    required this.startsAt,
    this.endsAt,
    this.location,
  });

  final String title;

  /// Epoch ms. Sent as a number so both builds agree without parsing dates.
  final int startsAt;

  /// Defaults to an hour after the start when absent.
  final int? endsAt;
  final String? location;

  Map<String, dynamic> toJson() => {
    'title': title,
    'startsAt': startsAt,
    if (endsAt != null) 'endsAt': endsAt,
    if (location != null) 'location': location,
  };
}

const int hourMs = 60 * 60 * 1000;

String encodeEvent(MeshEvent e) => jsonEncode(e.toJson());

/// Never throws — a malformed event from another build must not break a thread.
MeshEvent? decodeEvent(String body) {
  try {
    final e = jsonDecode(body);
    if (e is! Map || e['title'] is! String || e['startsAt'] is! num) {
      return null;
    }
    return MeshEvent(
      title: e['title'] as String,
      startsAt: (e['startsAt'] as num).toInt(),
      endsAt: e['endsAt'] is num ? (e['endsAt'] as num).toInt() : null,
      location: e['location'] is String ? e['location'] as String : null,
    );
  } catch (_) {
    return null;
  }
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatWhen(MeshEvent e) {
  final d = DateTime.fromMillisecondsSinceEpoch(e.startsAt);
  final weekday = _weekdays[d.weekday - 1];
  final month = _months[d.month - 1];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$weekday, ${d.day} $month, $hh:$mm';
}

enum SaveFailureReason { denied, noCalendar, error }

class SaveOutcome {
  const SaveOutcome.ok() : ok = true, reason = null, message = null;

  const SaveOutcome.failure(this.reason, {this.message}) : ok = false;

  final bool ok;
  final SaveFailureReason? reason;
  final String? message;
}

/// Contract a native calendar plugin must satisfy.
abstract class CalendarWriter {
  /// Save to the device calendar. Asks for permission at the moment of use.
  /// Never throws; see [SaveOutcome].
  Future<SaveOutcome> save(MeshEvent event);
}

/// Headless fake: records what would have been saved instead of touching a
/// platform calendar, so tests can assert on it without a plugin channel.
class MockCalendarWriter implements CalendarWriter {
  MockCalendarWriter({this.nextOutcome = const SaveOutcome.ok()});

  /// What [save] returns the next time it is called. Defaults to success.
  SaveOutcome nextOutcome;

  final List<MeshEvent> saved = [];

  @override
  Future<SaveOutcome> save(MeshEvent event) async {
    if (nextOutcome.ok) saved.add(event);
    return nextOutcome;
  }
}
