// Calendar events as messages.
//
// An event sent over the mesh is just structured text — small, so it never
// needs chunking. Saving it to the phone's own calendar is a separate,
// deliberate act, because writing to someone's calendar is not something a
// received message should do on its own.
//
// Port intent of src/features/messaging/api/events.ts. This defines the
// contract [CalendarWriter] a save-to-calendar implementation must satisfy
// and the real [DeviceCalendarWriter] backed by add_2_calendar.
import 'dart:convert';

import 'package:add_2_calendar/add_2_calendar.dart' as add2cal;

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

/// Hands the event to the device's own calendar app rather than writing to
/// it directly — no calendar permission needed, and the user gets a last
/// look before it's saved.
///
/// The only import site for package:add_2_calendar.
class DeviceCalendarWriter implements CalendarWriter {
  @override
  Future<SaveOutcome> save(MeshEvent event) async {
    try {
      final ends = event.endsAt ?? event.startsAt + hourMs;
      final added = await add2cal.Add2Calendar.addEvent2Cal(
        add2cal.Event(
          title: event.title,
          location: event.location,
          startDate: DateTime.fromMillisecondsSinceEpoch(event.startsAt),
          endDate: DateTime.fromMillisecondsSinceEpoch(ends),
        ),
      );
      return added
          ? const SaveOutcome.ok()
          : const SaveOutcome.failure(SaveFailureReason.error);
    } catch (e) {
      return SaveOutcome.failure(SaveFailureReason.error, message: '$e');
    }
  }
}
